require 'spec_helper'

describe 'trails' do
  include Rack::Test::Methods

  let(:app) do
    app = Class.new(Sinatra::Base)
    app.register Sinatra::Trails
    app.set :environment, :test
  end

  describe 'map' do
    describe 'basic' do
      before :all do
        app.map :home, :to => '/'
        app.map 'dashboard'
        app.map :edit_user, :to => '/users/:id/edit'
      end

      describe 'routes' do
        it { app.route_for(:home).should       == '/' }
        it { app.route_for(:dashboard).should  == '/dashboard' }
        it { app.route_for('dashboard').should == '/dashboard' }
        it { lambda{ app.route_for(:missing) }.should raise_error Sinatra::Trails::RouteNotDefined }
      end

      describe 'paths' do
        it { app.path_for(:home).should       == '/' }
        it { app.path_for(:home, :q => 'q', :a => 'a').should == '/?q=q&a=a' }

        describe 'with placeholders' do
          before { @mock_user = mock(:user, :to_param => 1)}
          it { app.path_for(:edit_user, 1).should     == '/users/1/edit' }
          it { app.path_for(:edit_user, @mock_user).should  == '/users/1/edit' }

          describe 'wrong arg count' do
            it 'should raise error when not passing :id' do
              lambda { app.path_for(:edit_user) }.should raise_error(ArgumentError)
            end

            it 'should raise error when too many params are passed' do
              lambda { app.path_for(:edit_user, 1, 2) }.should raise_error(ArgumentError)
            end
          end
        end
      end
    end

    describe 'with namespace' do
      before :all do
        app.namespace '/admin' do
          map :dashboard
          map :logout
        end
      end
      it { app.route_for(:dashboard).should == '/admin/dashboard' }
      it { app.route_for(:logout).should    == '/admin/logout' }
    end

    describe 'with named namespace' do
      before :all do
        app.namespace :admin do
          map :dashboard
        end
      end
      it { app.route_for(:admin_dashboard).should == '/admin/dashboard' }
    end

    describe 'with nested namespace' do
      before :all do
        app.namespace '/blog' do
          map :users
          namespace '/admin' do
            map :dashboard
            namespace '/auth' do
              map :logout
              map :login
            end
          end
        end
      end
      it { app.route_for(:users).should     == '/blog/users' }
      it { app.route_for(:dashboard).should == '/blog/admin/dashboard' }
      it { app.route_for(:logout).should    == '/blog/admin/auth/logout' }
      it { app.route_for(:login).should     == '/blog/admin/auth/login' }
    end

    describe 'with named nested namespace' do
      before :all do
        app.namespace :blog do
          map :users
          namespace :admin do
            map :dashboard
            namespace :auth do
              map :logout
              map :login
            end
          end
        end
      end
      it { app.route_for(:blog_users).should             == '/blog/users' }
      it { app.route_for(:blog_admin_dashboard).should   == '/blog/admin/dashboard' }
      it { app.route_for(:blog_admin_auth_logout).should == '/blog/admin/auth/logout' }
      it { app.route_for(:blog_admin_auth_login).should  == '/blog/admin/auth/login' }
    end
  end

  describe 'resources' do
    shared_examples_for 'generates routes for users' do
      it { app.route_for(:users).should      == '/users' }
      it { app.route_for(:new_user).should   == '/users/new' }
      it { app.route_for(:user).should       == '/users/:id' }
      it { app.route_for(:edit_user).should  == '/users/:id/edit' }
    end

    shared_examples_for 'generates routes for posts' do
      it { app.route_for(:posts).should      == '/posts' }
      it { app.route_for(:new_post).should   == '/posts/new' }
      it { app.route_for(:post).should       == '/posts/:id' }
      it { app.route_for(:edit_post).should  == '/posts/:id/edit' }
    end

    shared_examples_for 'generates routes for nested user posts collections' do
      it { app.route_for(:user_posts).should     == '/users/:user_id/posts' }
      it { app.route_for(:new_user_post).should  == '/users/:user_id/posts/new' }
    end

    shared_examples_for 'generates routes for nested user posts members' do
      it { app.route_for(:user_post).should      == '/users/:user_id/posts/:id' }
      it { app.route_for(:edit_user_post).should == '/users/:user_id/posts/:id/edit' }
    end

    shared_examples_for 'generates routes for nested user posts' do
      it_should_behave_like 'generates routes for nested user posts collections'
      it_should_behave_like 'generates routes for nested user posts members'
    end

    shared_examples_for 'generates routes for shallow user posts' do
      it_should_behave_like 'generates routes for nested user posts collections'
      it { app.route_for(:post).should      == '/posts/:id' }
      it { app.route_for(:edit_post).should == '/posts/:id/edit' }
    end

    shared_examples_for 'generates routes for nested post comments collections' do
      it { app.route_for(:post_comments).should     == '/posts/:post_id/comments' }
      it { app.route_for(:new_post_comment).should  == '/posts/:post_id/comments/new' }
    end

    shared_examples_for 'generates routes for shallow post comments' do
      it_should_behave_like 'generates routes for nested post comments collections'
      it { app.route_for(:comment).should      == '/comments/:id' }
      it { app.route_for(:edit_comment).should == '/comments/:id/edit' }
    end

    describe 'basic' do
      before :all do
        app.resources :users
        app.resources :posts
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for posts'
    end

    describe 'as namespace' do
      before :all do
        app.resources :users do
          map(:confirm)
        end
      end
      it_should_behave_like 'generates routes for users'
      it { app.route_for(:users_confirm).should  == '/users/confirm' }
    end

    describe 'nested with block' do
      before :all do
        app.resources :users do
          resources :posts
        end
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for nested user posts'
    end

    describe 'with namespace' do
      before :all do
        app.namespace :admin do
          resources :users
        end
      end
      it { app.route_for(:admin_users).should          == '/admin/users' }
      it { app.route_for(:new_admin_user).should       == '/admin/users/new' }
      it { app.route_for(:admin_user).should           == '/admin/users/:id' }
      it { app.route_for(:edit_admin_user).should      == '/admin/users/:id/edit' }
    end

    describe 'nested with block and namespace' do
      before :all do
        app.resources :users do
          namespace :admin do
            resources :posts
          end
        end
      end
      it_should_behave_like 'generates routes for users'
      it { app.route_for(:user_admin_posts).should     == '/users/:user_id/admin/posts' }
      it { app.route_for(:new_user_admin_post).should  == '/users/:user_id/admin/posts/new' }
      it { app.route_for(:user_admin_post).should      == '/users/:user_id/admin/posts/:id' }
      it { app.route_for(:edit_user_admin_post).should == '/users/:user_id/admin/posts/:id/edit' }
    end

    describe 'deep nested' do
      before :all do
        app.resources :users do
          resources :posts do
            resources :comments
          end
        end
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for nested user posts'
      describe 'exageration' do
        it { app.route_for(:user_post_comments).should     == '/users/:user_id/posts/:post_id/comments' }
        it { app.route_for(:new_user_post_comment).should  == '/users/:user_id/posts/:post_id/comments/new' }
        it { app.route_for(:user_post_comment).should      == '/users/:user_id/posts/:post_id/comments/:id' }
        it { app.route_for(:edit_user_post_comment).should == '/users/:user_id/posts/:post_id/comments/:id/edit' }
      end
    end

    describe 'shallow deep nested' do
      before :all do
        app.resources :users, :shallow => true do
          resources :posts do
            resources :comments
          end
        end
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for shallow user posts'
      it_should_behave_like 'generates routes for shallow post comments'
    end

    describe 'nested shallow' do
      before :all do
        app.resources :users, :shallow => true do
          resources :posts
        end
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for shallow user posts'
    end
  end

  describe 'single resource' do
    describe 'basic' do
      before :all do
        app.resource :user do
          resource :profile
        end
      end
      it { app.route_for(:user).should               == '/user' }
      it { app.route_for(:new_user).should           == '/user/new' }
      it { app.route_for(:edit_user).should          == '/user/edit' }
      it { app.route_for(:user_profile).should       == '/user/profile' }
      it { app.route_for(:new_user_profile).should   == '/user/profile/new' }
      it { app.route_for(:edit_user_profile).should  == '/user/profile/edit' }
    end

    describe 'as namespace' do
      before :all do
        app.resource :user do
          map(:confirm)
        end
      end
      it { app.route_for(:user_confirm).should  == '/user/confirm' }
    end
  end


  describe 'finding route for scope' do
    before :all do
      @scope = Sinatra::Trails::Scope.new(app, :admin)
      @scope.generate_routes!{ map(:index) }
    end

    it { @scope.route_for(:admin_index).should_not be_nil }
    it { @scope.route_for(:index).should_not be_nil }
    it "should find resources index without full name"
  end

  describe 'finding route for resources' do
    before :all do
      @scope = Sinatra::Trails::Resources.new(app, :users, [], {})
      @scope.generate_routes!
    end
    it { @scope.route_for(:users).should_not be_nil }
    it { @scope.route_for(:new_user).should_not be_nil }
    it { @scope.route_for(:edit_user).should_not be_nil }
    it { @scope.route_for(:user).should_not be_nil }
  end

  describe 'finding route for resources' do
    before :all do
      @scope = Sinatra::Trails::Resources.new(app, :users, [], {})
      @scope.generate_routes! do
        resources :posts
      end
    end
    it { @scope.route_for(:user_posts).should_not be_nil }
    it { @scope.route_for(:new_user_post).should_not be_nil }
    it { @scope.route_for(:edit_user_post).should_not be_nil }
    it { @scope.route_for(:user_post).should_not be_nil }
  end

  describe 'sinatra integration' do
    describe 'delegation to sinatra and helpers' do
      before :all do
        app.map(:home) { get(home){ path_for(:home) } }
        app.instance_eval { get(map(:about)){ url_for(:about) } }
      end

      it "should get path for route" do
        get '/home'
        last_response.body.should == '/home'
      end

      it "should get url for route" do
        get '/about'
        last_response.body.should == 'http://example.org/about'
      end
    end

    describe 'before without args' do
      before :all do
        app.instance_eval do
          namespace(:admin) do 
            before { @admin = true }
            get map(:index, :to => '/') do
              @admin.to_s
            end
          end

          namespace(:not_admin) do
            get map(:index, :to => '/') do
              @admin.to_s
            end
          end
        end
      end

      it 'should set before filter within scope' do
        get '/admin'
        last_response.body.should == 'true'
      end

      it 'should not set before filter outside scope' do
        get '/not_admin'
        last_response.body.should == ''
      end
    end

    describe 'before passing routes' do
      before :all do
        app.instance_eval do
          namespace(:admin) do 
            get map(:index, :to => '/') do
              @auth.to_s
            end

            get map(:sign_in, :to => '/sign_in') do
              @auth.to_s
            end

            get map(:sign_up, :to => '/sign_up') do
              @auth.to_s
            end

            before(admin_sign_in, admin_sign_up) { @auth = true }
          end
        end
      end

      it 'should set before filter for passed routes' do
        get '/admin/sign_in'
        last_response.body.should == 'true'
        get '/admin/sign_up'
        last_response.body.should == 'true'
      end

      it 'should not set before filter for not passed routes' do
        get '/admin'
        last_response.body.should == ''
      end
    end

    describe 'before filter lazy match passing symbols' do
      before :all do
        app.instance_eval do
          namespace(:admin) do 
            before(:admin_sign_in, :admin_sign_up) { @auth = true }

            get map(:index, :to => '/') do
              @auth.to_s
            end

            get map(:sign_in, :to => '/sign_in') do
              @auth.to_s
            end

            get map(:sign_up, :to => '/sign_up') do
              @auth.to_s
            end
          end
        end
      end

      it 'should set before filter for passed routes' do
        get '/admin/sign_in'
        last_response.body.should == 'true'
        get '/admin/sign_up'
        last_response.body.should == 'true'
      end

      it 'should not set before filter for not passed routes' do
        get '/admin'
        last_response.body.should == ''
      end
    end

    describe 'before filter costructing correct params' do
      before :all do
        app.instance_eval do
          resources :users do
            before(user) do
              @user = params[:id]
            end

            get user do
              @user
            end
          end
        end
      end

      it 'should set before filter for passed routes' do
        get '/users/1'
        last_response.body.should == '1'
      end
    end

    describe 'having access to resource name' do
      before :all do
        app.resources :users do
          get(users){ params[:resource].to_s }
          resources :posts do
            get(user_posts){ params[:resource].to_s }
          end
        end
      end

      it 'should access resource name for users' do
        get '/users'
        last_response.body.should == 'user'
      end

      it 'should access resource name for nested posts' do
        get '/users/1/posts'
        last_response.body.should == 'post'
      end
    end

    describe 'having access to namespace and action' do
      before :all do
        app.namespace(:admin) do
          get(map(:index, :to => '/')){ params[:namespace].to_s }
          get(map(:sign_in)){ params[:action].to_s }
        end
      end

      it 'should access namespace' do
        get '/admin'
        last_response.body.should == 'admin'
      end

      it 'should access action' do
        get '/admin/sign_in'
        last_response.body.should == 'sign_in'
      end
    end

    describe 'finding the right route for resources' do
      it 'should find the right route' do
        app.resources(:users) do
          users.to_route.should     == '/users'
          new_user.to_route.should  == '/users/new'
          user.to_route.should      == '/users/:id'
          edit_user.to_route.should == '/users/:id/edit'
        end
      end
    end

    describe 'having access to action for resources' do
      before :all do
        app.resources(:users) do
          get(users){ params[:action].to_s }
          get(new_user){ params[:action].to_s }
          get(user){ params[:action].to_s }
          get(edit_user){ params[:action].to_s }
        end
      end

      it 'should set index as action' do
        get '/users'
        last_response.body.should == 'index'
      end

      it 'should set index as show' do
        get '/users/1'
        last_response.body.should == 'show'
      end

      it 'should set index as new' do
        get '/users/new'
        last_response.body.should == 'new'
      end

      it 'should set index as edit' do
        get '/users/1/edit'
        last_response.body.should == 'edit'
      end
    end
  end

  describe 'accessing routes from outside the app by module inclusion' do
    let(:other_app) do
      app = Class.new(Sinatra::Base)
      app.register Sinatra::Trails
      app.set :environment, :test
    end

    let(:klass) { Class.new }

    before :all do
      app.map :heaven
      other_app.map :hell
      klass.send :include, app::Routes
      klass.send :include, other_app::Routes
      @obj = klass.new
    end
     
    it { @obj.path_for(:heaven).should == '/heaven' }
    it { @obj.path_for(:hell).should   == '/hell' }
    it { lambda{ @obj.path_for(:purgatory) }.should raise_error Sinatra::Trails::RouteNotDefined }
  end
end
