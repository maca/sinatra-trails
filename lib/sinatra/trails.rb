require "sinatra/base"
require "active_support/inflector"
require "active_support/inflections"

$:.unshift File.dirname( __FILE__) 
require "trails/version"

module Sinatra
  module Trails
    class Route
      attr_reader :name

      def initialize route, name, *namespaces
        @namespaces = namespaces.map { |name| String === name ? name.sub(/\//, '') : name }.compact
        @components = route.sub(/^\//, '').split('/')
        @components = @namespaces + @components
        @name       = @namespaces.select { |n| Symbol === n }.push(name).join('_').to_sym
      end

      def to_route
        "/#{@components.join('/')}"
      end
    end

    module Matching
      def match routes
        @routes += routes.map { |name, route| Route.new(route, name, *@namespaces) }
      end

      def namespace *names, &block
        @routes += Scope.new(*(@namespaces + names), &block).generate_routes!
      end
    end

    class Resources
      include Matching
      attr_accessor :plural_name, :singular_name

      def initialize name, opts = {}
        @name, @namespaces, @routes, @block = name, [], []
        @plural_name   = @name.to_s
        @singular_name = ActiveSupport::Inflector.singularize @plural_name
        @parent        = opts.delete(:parent)
      end

      def generate_nested
        plural_name   = "#{@parent.singular_name}_#{@plural_name}"
        singular_name = "#{@parent.singular_name}_#{@singular_name}"
        namespace @parent.plural_name, ":#{@parent.singular_name}_id", @plural_name do
          match plural_name => '/', "new_#{singular_name}" => '/new' 
          match singular_name => '/:id', "edit_#{singular_name}" => '/:id/edit'
        end
      end

      def generate_base
        plural_name, singular_name = @plural_name, @singular_name
        namespace plural_name do
          match plural_name => '/', "new_#{singular_name}" => '/new'
          match singular_name => '/:id', "edit_#{singular_name}" => '/:id/edit'
        end
      end

      def generate_routes! &block
        if @parent
          generate_nested
        else
          generate_base
        end
        instance_eval(&block) if block_given?
        @routes
      end

      def resources name, opts = {}, &block
        @routes += Resources.new(name, opts.merge(:parent => self)).generate_routes!(&block)#.tap { |routes| puts routes.inspect }
      end
    end

    class Scope
      include Matching

      def initialize *namespaces, &block
        @namespaces, @block, @routes = namespaces.flatten, block, []
      end

      def resources name, opts = {}, &block
        @routes += Resources.new(name, opts).generate_routes!(&block)# .tap { |routes| puts routes.inspect }
      end

      def generate_routes!
        instance_eval &@block
        @routes
      end

      def routes_hash
        generate_routes!
        Hash[*@routes.map{ |route| [route.name, route]}.flatten]
      end
    end

    class RouteNotDefined < Exception
    end
    
    def match routes
      namespace(nil) { match routes }
    end

    def resources plural_name, &block
      namespace(nil) { resources plural_name, &block }
    end

    def namespace name, &block
      @named_routes.merge! Scope.new(name, &block).routes_hash
    end

    def route_for name
      @named_routes[name].to_route
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
