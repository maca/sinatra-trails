require "sinatra/base"
require "active_support/inflector"
require "active_support/inflections"
require "active_support/core_ext/string/inflections"
require 'ostruct'

libdir = File.dirname( __FILE__)
$:.unshift(libdir) unless $:.include?(libdir)
require "trails/version"

module Sinatra
  module Trails
    class RouteNotDefined < Exception; end

    class Route
      attr_reader :name, :full_name, :scope, :keys, :to_route, :to_regexp
      Match = Struct.new(:captures)

      def initialize route, name, ancestors, scope
        @name        = name.to_s
        @full_name   = ancestors.map { |ancestor| Scope === ancestor ? ancestor.name : ancestor }.push(name).select{ |name| Symbol === name }.join('_')
        @components  = Array === route ? route.compact : route.to_s.scan(/[^\/]+/)
        @components.unshift *ancestors.map { |ancestor| ancestor.path if Scope === ancestor }.compact
        @scope       = scope
        @captures    = []
        @to_route    = "/#{@components.join('/')}"
        namespace    = ancestors.reverse.find { |ancestor| ancestor.class == Scope && ancestor.name }

        @to_regexp, @keys = Sinatra::Base.send(:compile, to_route)
        add_param 'resource', scope.name if [Resource, Resources].include?(scope.class)
        add_param 'namespace', namespace.name if namespace
        add_param 'action', name
        scope.routes << self
      end

      def match str
        if match_data = to_regexp.match(str)
          Match.new(match_data.captures + @captures)
        end
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

      private
      def add_param key, capture
        unless keys.include? key
          @keys << key
          @captures << capture
        end
      end
    end

    class ScopeMatcher
      def initialize scope, matchers
        @scope = scope
        @names, @matchers = matchers.partition { |el| Symbol === el }
      end
      
      def match str
        if @matchers.empty? && @names.empty?
          Regexp.union(@scope.routes).match str
        else
          Regexp.union(*@matchers, *@names.map{ |name| @scope[name] }).match str
        end
      end
    end

    class Scope
      attr_reader :name, :path, :ancestors, :routes

      def initialize app, path, ancestors = []
        @ancestors, @routes = ancestors, []
        @path = path.to_s.sub(/^\//, '') if path
        @name = path if Symbol === path
        @sinatra_app = app
      end

      def map name, opts = {}, &block
        path = opts.delete(:to) || name
        route = Route.new(path, name, [*ancestors, self], self)
        instance_eval &block if block_given?
        route
      end

      def namespace path, &block
        @routes += Scope.new(@sinatra_app, path, [*ancestors, self]).generate_routes!(&block)
      end

      def resource *names, &block
        restful_routes Resource, names, &block
      end

      def resources *names, &block
        restful_routes Resources, names, &block
      end

      def before *args, &block
        opts = Hash === args.last ? args.pop : {}
        @sinatra_app.before ScopeMatcher.new(self, args), opts, &block
      end

      def generate_routes! &block
        instance_eval &block if block_given?
        @routes
      end

      def routes_hash &block
        Hash[*generate_routes!(&block).map{ |route| [route.full_name, route]}.flatten]
      end

      def route_for name
        name = name.to_s
        @routes.find{ |route| route.full_name == name || route.scope == self && route.name == name }
      end
      alias :[] :route_for

      private
      def method_missing name, *args, &block
        return @sinatra_app.send(name, *args, &block) if @sinatra_app.respond_to?(name)
        if route = route_for(name)
          return route unless block_given?
          @routes = @routes | route.scope.generate_routes!(&block)
        else
          super
        end
      end

      def restful_routes builder, names, &block
        opts = {}
        hash = Hash === names.last ? names.pop : {}
        hash.delete_if { |key, val| opts[key] = val if !(Symbol === val || Hash === val || Array === val) }

        nested = []
        mash = Proc.new do |hash, acc|
          hash.map do |key, val| 
            case val
            when Hash
              [*acc, key, *mash.call(val, key).flatten]
            when Array
              nested += val.map{ |r| [*acc, key, r] } and next
            else
              [key, val]
            end
          end 
        end

        hash = (mash.call(hash) + nested).compact.map do |array|
          array.reverse.inject(Proc.new{}) do |proc, name|
            Proc.new{ send(builder == Resource ? :resource : :resources, name, opts, &proc) }
          end.call
        end

        make = lambda do |name|
          builder.new(@sinatra_app, name, [*ancestors, self], (@opts || {}).merge(opts))
        end

        if names.size == 1 && hash.empty?
          @routes += make.call(names.first).generate_routes!(&block)
        else
          names.each { |name| @routes += make.call(name).generate_routes! }
          instance_eval &block if block_given?
        end
      end
    end
  
    class Resource < Scope
      def initialize app, name, ancestors, opts
        super app, name, ancestors
        @opts = opts
      end

      def member action
        ancestors = [*self.ancestors, name]
        path      = [name]
          
        unless action == :show
          ancestors.unshift action
          path.push action
        end

        Route.new(path, action.to_s, ancestors, self)
      end

      def generate_routes! &block
        member(:show) and member(:new) and member(:edit)
        super
      end
    end

    class Resources < Scope
      attr_reader :plural_name, :name_prefix, :route_scope, :opts

      def initialize app, name, ancestors, opts
        super app, name, ancestors
        @opts        = opts
        @name        = name.to_s.singularize.to_sym
        @plural_name = name.to_sym
      end

      def path
        [plural_name, ":#{name}_id"]
      end

      def collection action
        ancestors  = [*self.ancestors, action == :new ? name : plural_name]
        path       = [plural_name]

        unless action == :index
          ancestors.unshift action
          path.push action
        end

        ancestors[0, ancestors.size - 2] = ancestors[0..-3].reject{ |ancestor| self.class === ancestor } if opts[:shallow]
        Route.new(path, action.to_s, ancestors, self)
      end

      def member action
        ancestors = [*self.ancestors, name]
        path      = [plural_name, ':id']

        unless action == :show
          ancestors.unshift action
          path.push action
        end

        ancestors.reject!{ |ancestor| self.class === ancestor } if opts[:shallow]
        Route.new(path, action.to_s, ancestors, self)
      end

      def generate_routes! &block
        collection(:index) and collection(:new)
        member(:show) and member(:edit)
        super
      end
    end

    def namespace name, &block
      @named_routes.merge! Scope.new(self, name).routes_hash(&block)
    end

    def map name, opts = {}, &block
      namespace(nil) { map name, opts, &block }
      route_for name
    end

    def resource *args, &block
      namespace(nil) { resource *args, &block }
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
          if Symbol === key
            hash[key.to_s]
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
      def path_for *args
        self.class.path_for *args
      end

      def url_for *args
        url path_for(*args)
      end
    end
  end

  register Trails
end
