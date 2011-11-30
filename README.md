# sinatra-trails

Is a very thin Rails inspired route naming DSL for using with Sinatra apps. 
It doesn't monkeypatch or overrides any Sinatra::Base methods 
It provides helpers for generating routes for resources and single resource, namespaces and named routes.

# Instalation

    $ [sudo] gem install sinatra-trails

# Usage

## Basic

Named routes are generated with map, not passing :to option sets the path to be the same as the name:

    require 'sinatra/trails'

    class MyApp < Sinatra::Base
      register Sinatra::Trails

      map :dashboard                 # => '/dashboard'
      map :home, :to => '/'          # => '/'
      map :post, :to => '/posts/:id' # => '/posts/:id'
    end

    MyApp.print_routes
    # prints
    #    dashboard => /dashboard
    #         home => /
    #         post => /posts/:id   

Routes can be define beforehand:

    map :dashboard
    
    # GET '/dashboard'
    get route_for(:dashboard) do
      ...  
    end

Or when defining the action:

    # GET '/dashboard'
    get map(:dashboard) do
      ...
    end 

All defined routes will be available in the views and action blocks:

    get map(:posts, :to => '/posts/:id') do
      ...
    end

    get map(:dashboard) do
      path_for(:dashboard) # => '/dashboard'
      url_for(:dashboard)  # => 'http://www.example.com/dashboard'
      path_for(:dashboard, :option => 'hi') # => '/dashboard?option=hi'
      # all required params must be meet, an object can be passed to meet :id but it must respond to #to_param
      path_for(:posts, 1) # => '/posts/1'
    end 


## Namespaces

Passing a symbol namespaces both the path and the route name:

    namespace :admin do
      map(:dashboard)
    end
    
    route_for(:admin_dashboard) # => '/admin/dashboard'
  
Passing a string only namespaces the path:

    namespace 'admin' do
      map(:dashboard)
    end

    route_for(:dashboard) # => '/admin/dashboard'

Passing nil to namespace only sets a context:

    namespace nil do
      map(:dashboard)
    end

    route_for(:dashboard) # => '/dashboard'


## Resources
  
Restful routes for plural resources can be generated as follows, inside the resource
definition block a route can be accessed by its name as a method call or using the path_for method:

    resources :users do
      # GET /users
      get users do
        ...
      end

      # POST /users
      post users do
        ...
      end
      
      # GET /users/new
      get new_user do
        ...
      end
      
      # GET /users/:id
      get user do
        ...
      end
      
      # GET /users/:id/edit
      get edit_user do
        ...
      end

      # PUT /users/:id
      put user do
        ...
      end

      # DELETE /users/:id
      delete user do
        ...
      end
      
      # generates new route with name :aprove_user
      # GET /users/:id/aprove
      get member(:aprove) do
        ...
      end

      # generates new route with name :aproved_users
      # GET /users/aproved
      get collection(:aproved) do
        ...
      end
    end

Route definition order for sinatra has precedence, in this case `get(new_user)` must be defined before `get(user)`

As with previous examples routes can be defined beforehand:

    resources :users
    # GET '/users'
    get path_for(:users) do
      ...
    end


## Nested Resources

Resources can be nested in a similar way as with Rails:
  
    resources :users do
      ...
      resources :comments do
        # GET /users/:user_id/comments
        get user_comments do
          ...
        end
        
        # GET /users/:user_id/comments/:id
        get user_comment do
          ...
        end
      end  
    end

    print_routes
    #              users => /users
    #           new_user => /users/new
    #               user => /users/:id
    #          edit_user => /users/:id/edit
    #      user_comments => /users/:user_id/comments
    #   new_user_comment => /users/:user_id/comments/new
    #       user_comment => /users/:user_id/comments/:id
    #  edit_user_comment => /users/:user_id/comments/:id/edit  
      
  
And for actions that don't need to load the parent resource the route generation can be shallow:

    resources :users, :shallow => true do
      resources :comments
    end
    
    print_routes
    #            users => /users
    #         new_user => /users/new
    #             user => /users/:id
    #        edit_user => /users/:id/edit
    #    user_comments => /users/:user_id/comments
    # new_user_comment => /users/:user_id/comments/new
    #          comment => /comments/:id
    #     edit_comment => /comments/:id/edit 

Some keys to the params hash are added when routes are defined using sinatra-trails:
    
    params[:resource]  # the name of the resource in REST actions
    params[:action]    # the name of the action in REST actions
    params[:namespace] # the name of the current namespace


## Singleton Resource

Same principles apply for singleton resource:
    
    resource :user
    print_routes
    #       user => /user
    #   new_user => /user/new
    #  edit_user => /user/edit


## Before and After Filters

Defining a filter within a context (namespace, resources, resource) without passing any path will execute that filter for
all actions defined in that context:

    namespace :admin do
      before do
        @admin = true
      end
      
      get map(:dashboard) do
        @admin # => true
      end
    end

    get map(:home, :to => '/') do
      @admin # => nil
    end


Within a context named routes, strings or regexps can be used as arguments for before and after filters:

    resources :users do
      before new_user, edit_user do
      end
    end

A symbol can be passed to the filter definition and it will be lazily evaluated against the routes within the context:

    namespace :admin do
      before :dashboard do
        ...
      end
      
      get map(:dashboard) do
        ...
      end
    end

## Accessing Routes from Outside the App

On registering Sinatra::Trails a dynamic module for the Sinatra app is created and it is assigned to the constant `Routes`
including that module in another class gives that class access to the app's paths, a single class can access paths for
several Sinatra apps:

    class MyApp < Sinatra::Base
      register Sinatra::Trails
      
      get map(:users) do
        ...
      end
      
      get map(:user, :to => '/users/:id') do
        ...
      end
    end

    class OtherApp < Sinatra::Base
      include MyApp::Routes
      
      get 'index' do
        redirect to path_for(:users)
      end
    end

    class User < Sequel::Model
      include MyApp::Routes

      def to_param() id end

      def route
        path_for(:user, self) # => '/users/1'
      end
    end
