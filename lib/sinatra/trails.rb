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

    class Scope
      def initialize *namespaces, &block
        @namespaces, @block, @routes, @scopes = namespaces.flatten, block, [], []
      end

      def match routes
        @routes += routes.map { |name, route| Route.new(route, name, *@namespaces) }
      end

      def namespace name, &block
        @routes += Scope.new(*@namespaces.push(name), &block).generate_routes!
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
