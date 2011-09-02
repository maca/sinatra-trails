require "sinatra/base"
require "active_support/inflector"
require "active_support/inflections"
require "active_support/core_ext/string/inflections"

$:.unshift File.dirname( __FILE__) 
require "trails/version"

module Sinatra
  module Trails
    class Route
      attr_reader :name

      def initialize route, name, ancestors
        @components  = Array === route ? route.compact : route.to_s.scan(/[^\/]+/)
        @name        = ancestors.map { |ancestor| ancestor.name }.push(*name).compact.join('_').to_sym
        @components.unshift *ancestors.map { |ancestor| ancestor.path }.compact
        @components.flatten!
      end

      def to_route
        "/#{@components.join('/')}"
      end

      def to_path *args
        query      = args.pop if Hash === args.last
        components = @components.dup
        components.each_with_index do |component, index|
          next unless /^:/ === component
          val = args.pop or raise ArgumentError.new("Please provide `#{component}`")
          components[index] =
          case val
          when Numeric, String, Symbol then val
          else val.to_param end
        end
        raise ArgumentError.new("Too many params where passed") unless args.empty?
        "/#{components.join('/')}#{'?' + Rack::Utils.build_nested_query(query) if query}"
      end
    end

    class Scope
      attr_reader :name, :path, :ancestors

      def initialize path, ancestors = []
        @ancestors, @routes = ancestors, []
        @path = path.to_s.sub(/^\//, '') if path
        @name = path if Symbol === path
      end

      def match routes
        @routes += routes.map { |route_name, route| Route.new(route, route_name, [*ancestors, self]) }
      end

      def namespace path, &block
        @routes += Scope.new(path, [*ancestors, self]).generate_routes!(&block)
      end

      def resources *resources, &block
        opts = {}
        hash = Hash === resources.last ? resources.pop : {}
        hash.delete_if { |key, val| opts[key] = val if !(Symbol === val || Hash === val)}
        shallow = opts[:shallow]

        mash = Proc.new do |hash, acc|
          hash.map { |key, val| Enumerable === val ? [*acc, key, *mash.call(val, key).flatten] : [key, val] } 
        end

        make_resource = lambda do |name|
          Resources.new(name, [*ancestors, self], shallow.nil? ? @shallow : shallow)
        end

        hash = mash.call(hash).map do |array|
          array.reverse.inject(Proc.new{}) do |proc, name|
            Proc.new{ resources(name, opts, &proc) }
          end.call
        end

        if resources.size == 1 && hash.empty?
          @routes += make_resource.call(resources.first).generate_routes!(&block)
        else
          resources.each { |name| @routes += make_resource.call(name).generate_routes! }
          instance_eval(&block) if block_given?
        end
      end

      def generate_routes! &block
        instance_eval &block if block_given?
        @routes
      end

      def routes_hash &block
        generate_routes! &block
        Hash[*@routes.map{ |route| [route.name, route]}.flatten]
      end
    end

    class Action
      attr_reader :path, :name
      def initialize name, path = nil
        @path, @name = path, name
      end
    end

    class Resources < Scope
      attr_reader :plural_name, :name_prefix, :route_scope

      def initialize name, ancestors, shallow
        super name, ancestors
        @shallow     = shallow
        @plural_name = @path
        @name        = @path.singularize
      end

      def path
        [plural_name, ":#{name}_id"]
      end

      def collection action = nil
        ancestors = [Action.new(action), *self.ancestors]
        ancestors[0, ancestors.size - 1] = ancestors[0..-2].reject{ |ancestor| self.class === ancestor } if @shallow
        @routes << Route.new([plural_name, action], [action == :new ? name : plural_name], ancestors)
      end

      def member action = nil
        ancestors = [Action.new(action), *self.ancestors]
        ancestors.reject!{ |ancestor| self.class === ancestor } if @shallow
        @routes << Route.new([plural_name, ':id', action], [name], ancestors)
      end

      def generate_routes! &block
        collection and collection(:new)
        member and member(:edit)
        super
      end
    end

    class RouteNotDefined < Exception
    end
    
    def namespace name, &block
      @named_routes.merge! Scope.new(name).routes_hash(&block)
    end

    def match routes
      namespace(nil) { match routes }
    end

    def resources *args, &block
      namespace(nil) { resources *args, &block }
    end

    def route_for name
      @named_routes[name].to_route
    end

    def path_for name, *args
      @named_routes[name].to_path(*args)
    end

    def trails
      trails       = @named_routes.map { |name, route| [name, route.to_route]}
      name_padding = trails.sort_by{ |e| e.first.size }.last.first.size + 3
      trails.each do |name, route|
        puts sprintf("%#{name_padding}s => %s", name, route) 
      end
    end

    class << self
      def routes_hash
        Hash.new do |hash, key| 
          if String === key
            hash[key.to_sym]
          else
            raise RouteNotDefined.new("The route `#{key}` is not defined") 
          end
        end
      end

      def registered app
        app.helpers Trails::Helpers
        app.instance_variable_set :@named_routes, routes_hash
      end
    end

    module Helpers
    end
  end

  register Trails
end
