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

      def initialize route, name, *namespaces
        @namespaces = namespaces.map { |name| String === name ? name.sub(/\//, '') : name }.compact
        @components = Array === route ? route.compact : route.to_s.scan(/[^\/]+/)
        @components = @namespaces + @components
        @name       = @namespaces.select { |n| Symbol === n }.push(*name).compact.join('_').to_sym
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
      attr_reader :namespaces, :ancestors

      def initialize namespaces, ancestors = []
        @namespaces, @ancestors, @routes = namespaces.compact, ancestors, []
      end

      def match routes
        @routes += routes.map { |name, route| Route.new(route, name, *namespaces) }
      end

      def namespace *names, &block
        @routes += Scope.new(namespaces + names, [*@singular_name, *ancestors]).generate_routes!(&block)
      end

      def resources *args, &block
        hash    = Hash === args.last ? args.pop : {}
        shallow = hash.delete(:shallow)
        
        mash = Proc.new do |hash, acc|
          hash.map do |key, val|
            Enumerable === val ? [*acc, key, *mash.call(val, key).flatten] : [key, val]
          end
        end

        resources = args.map { |e| [e] }
        mash.call(hash).each do |element|
          resources.push(*element.map { |e| element[0..element.index(e)] })
        end

        resources.each do |ancestors|
          name      = ancestors.pop
          ancestors = [*@ancestors, *@singular_name, *ancestors]
          puts ancestors.inspect
          # puts self.class
          @routes  += Resources.new(name, shallow, ancestors, namespaces).generate_routes!(&block).tap { |rs| puts rs.inspect }
        end
      end

      def generate_routes! &block
        instance_eval &block
        @routes
      end

      def routes_hash &block
        generate_routes! &block
        Hash[*@routes.map{ |route| [route.name, route]}.flatten]
      end
    end

    class Resources < Scope
      attr_reader :plural_name, :singular_name, :name_prefix, :route_scope

      def initialize name, shallow, ancestors, namespaces
        super namespaces.map{ |n| n.to_s }, ancestors
        @plural_name   = name.to_s
        @shallow       = shallow
        @singular_name = @plural_name.singularize
        @ancestors     = @ancestors[-1..-1] || [] if @shallow
        @name_prefix   = namespaces + @ancestors.map{ |a| a.to_s.singularize }
        @route_scope   = @namespaces + @ancestors.map{ |a| [a.to_s.pluralize, ":#{a.to_s.singularize}_id"] }.flatten.push(plural_name)
      end

      def collection action = nil
        name = [action, *name_prefix]
        name.push action == :new ? singular_name : plural_name 
        @routes << Route.new(action, name, *route_scope)
      end

      def member action = nil
        if @shallow
          name      = [action, singular_name]
          namespace = plural_name
        else
          name      = [action, *name_prefix, singular_name]
          namespace = route_scope
        end 
        @routes << Route.new([':id', action], name, *namespace)
      end

      def generate_routes! &block
        collection and collection(:new)
        member and member(:edit)
        instance_eval &block if block_given?
        @routes
      end
    end

    class RouteNotDefined < Exception
    end
    
    def namespace name, &block
      @named_routes.merge! Scope.new([name]).routes_hash(&block)
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
