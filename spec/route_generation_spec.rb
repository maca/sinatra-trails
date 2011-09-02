require 'spec_helper'

describe 'trails' do
  def app
    app = Class.new(Sinatra::Base)
    app.register Sinatra::Trails
    app.set :environment, :test
  end

  before do
    @app = app
  end

  describe 'match' do
    describe 'basic' do
      before do
        @app.match :root => '/'
        @app.match :dashboard => '/dashboard'
        @app.match :edit_user => '/users/:id/edit'
      end

      describe 'routes' do
        it { @app.route_for(:root).should       == '/' }
        it { @app.route_for(:dashboard).should  == '/dashboard' }
        it { @app.route_for('dashboard').should == '/dashboard' }
        it { lambda{ @app.route_for(:missing) }.should raise_error Sinatra::Trails::RouteNotDefined }
      end

      describe 'paths' do
        it { @app.path_for(:root).should       == '/' }
        it { @app.path_for(:root, :q => 'q', :a => 'a').should == '/?q=q&a=a' }

        describe 'with placeholders' do
          before { @mock_user = mock(:user, :to_param => 1)}
          it { @app.path_for(:edit_user, 1).should     == '/users/1/edit' }
          it { @app.path_for(:edit_user, @mock_user).should  == '/users/1/edit' }

          describe 'wrong arg count' do
            it 'should raise error when not passing :id' do
              lambda { @app.path_for(:edit_user) }.should raise_error(ArgumentError)
            end

            it 'should raise error when too many params are passed' do
              lambda { @app.path_for(:edit_user, 1, 2) }.should raise_error(ArgumentError)
            end
          end
        end
      end
    end

    describe 'multiple' do
      before do
        @app.match :dashboard => '/dashboard', :logout => '/sign-out'
      end
      it { @app.route_for(:dashboard).should == '/dashboard' }
      it { @app.route_for(:logout).should    == '/sign-out' }
    end

    describe 'with namespace' do
      before do
        @app.namespace '/admin' do
          match :dashboard => '/dashboard'
          match :logout => '/logout'
        end
      end
      it { @app.route_for(:dashboard).should == '/admin/dashboard' }
      it { @app.route_for(:logout).should    == '/admin/logout' }
    end

    describe 'with named namespace' do
      before do
        @app.namespace :admin do
          match :dashboard => '/dashboard'
        end
      end
      it { @app.route_for(:admin_dashboard).should == '/admin/dashboard' }
    end

    describe 'with nested namespace' do
      before do
        @app.namespace '/blog' do
          match :users => '/users'
          namespace '/admin' do
            match :dashboard => '/dashboard'
            namespace '/auth' do
              match :logout => '/logout'
              match :login  => '/login'
            end
          end
        end
      end
      it { @app.route_for(:users).should     == '/blog/users' }
      it { @app.route_for(:dashboard).should == '/blog/admin/dashboard' }
      it { @app.route_for(:logout).should    == '/blog/admin/auth/logout' }
      it { @app.route_for(:login).should     == '/blog/admin/auth/login' }
    end

    describe 'with named nested namespace' do
      before do
        @app.namespace :blog do
          match :users => '/users'
          namespace :admin do
            match :dashboard => '/dashboard'
            namespace :auth do
              match :logout => '/logout'
              match :login  => '/login'
            end
          end
        end
      end
      it { @app.route_for(:blog_users).should             == '/blog/users' }
      it { @app.route_for(:blog_admin_dashboard).should   == '/blog/admin/dashboard' }
      it { @app.route_for(:blog_admin_auth_logout).should == '/blog/admin/auth/logout' }
      it { @app.route_for(:blog_admin_auth_login).should  == '/blog/admin/auth/login' }
    end
  end

  describe 'resources' do
    shared_examples_for 'generates routes for users' do
      it { @app.route_for(:users).should      == '/users' }
      it { @app.route_for(:new_user).should   == '/users/new' }
      it { @app.route_for(:user).should       == '/users/:id' }
      it { @app.route_for(:edit_user).should  == '/users/:id/edit' }
    end

    shared_examples_for 'generates routes for posts' do
      it { @app.route_for(:posts).should      == '/posts' }
      it { @app.route_for(:new_post).should   == '/posts/new' }
      it { @app.route_for(:post).should       == '/posts/:id' }
      it { @app.route_for(:edit_post).should  == '/posts/:id/edit' }
    end

    shared_examples_for 'generates routes for nested user posts collections' do
      it { @app.route_for(:user_posts).should     == '/users/:user_id/posts' }
      it { @app.route_for(:new_user_post).should  == '/users/:user_id/posts/new' }
    end

    shared_examples_for 'generates routes for nested user posts members' do
      it { @app.route_for(:user_post).should      == '/users/:user_id/posts/:id' }
      it { @app.route_for(:edit_user_post).should == '/users/:user_id/posts/:id/edit' }
    end

    shared_examples_for 'generates routes for nested user posts' do
      it_should_behave_like 'generates routes for nested user posts collections'
      it_should_behave_like 'generates routes for nested user posts members'
    end

    shared_examples_for 'generates routes for shallow user posts' do
      it_should_behave_like 'generates routes for nested user posts collections'
      it { @app.route_for(:post).should      == '/posts/:id' }
      it { @app.route_for(:edit_post).should == '/posts/:id/edit' }
    end

    shared_examples_for 'generates routes for nested post comments collections' do
      it { @app.route_for(:post_comments).should     == '/posts/:post_id/comments' }
      it { @app.route_for(:new_post_comment).should  == '/posts/:post_id/comments/new' }
    end

    shared_examples_for 'generates routes for shallow post comments' do
      it_should_behave_like 'generates routes for nested post comments collections'
      it { @app.route_for(:comment).should      == '/comments/:id' }
      it { @app.route_for(:edit_comment).should == '/comments/:id/edit' }
    end

    describe 'basic' do
      before do
        @app = app
        @app.resources :users, :posts do
          match :flag => '/flag'
        end
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for posts'
      it { @app.route_for(:flag).should == '/flag' }
    end

    describe 'nested with block' do
      before do
        @app = app
        @app.resources :users do
          resources :posts
        end
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for nested user posts'
    end

    describe 'with namespace' do
      before do
        @app = app
        @app.namespace :admin do
          resources :users
        end
      end
      it { @app.route_for(:admin_users).should          == '/admin/users' }
      it { @app.route_for(:new_admin_user).should       == '/admin/users/new' }
      it { @app.route_for(:admin_user).should           == '/admin/users/:id' }
      it { @app.route_for(:edit_admin_user).should      == '/admin/users/:id/edit' }
    end

    describe 'nested with block and namespace' do
      before do
        @app = app
        @app.resources :users do
          namespace :admin do
            resources :posts
          end
        end
      end
      it_should_behave_like 'generates routes for users'
      it { @app.route_for(:user_admin_posts).should     == '/users/:user_id/admin/posts' }
      it { @app.route_for(:new_user_admin_post).should  == '/users/:user_id/admin/posts/new' }
      it { @app.route_for(:user_admin_post).should      == '/users/:user_id/admin/posts/:id' }
      it { @app.route_for(:edit_user_admin_post).should == '/users/:user_id/admin/posts/:id/edit' }
    end

    describe 'deep nested' do
      before do
        @app = app
        @app.resources :users do
          resources :posts do
            resources :comments
          end
        end
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for nested user posts'
      describe 'exageration' do
        it { @app.route_for(:user_post_comments).should     == '/users/:user_id/posts/:post_id/comments' }
        it { @app.route_for(:new_user_post_comment).should  == '/users/:user_id/posts/:post_id/comments/new' }
        it { @app.route_for(:user_post_comment).should      == '/users/:user_id/posts/:post_id/comments/:id' }
        it { @app.route_for(:edit_user_post_comment).should == '/users/:user_id/posts/:post_id/comments/:id/edit' }
      end
    end

    describe 'shallow deep nested' do
      before do
        @app = app
        @app.resources :users, :shallow => true do
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
      before do
        @app = app
        @app.resources :users, :shallow => true do
          resources :posts
        end
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for shallow user posts'
    end

    describe 'hash nested' do
      before do
        @app = app
        @app.resources :users => :posts
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for nested user posts'
    end

    describe 'hash nested with block' do
      before do
        @app = app
        @app.resources :users => :posts do
          match :flag => 'flag'
        end
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for nested user posts'
      it { @app.route_for(:flag).should == '/flag' }
    end

    describe 'nested shallow with hash' do
      before do
        @app = app
        @app.resources :users => :posts, :shallow => true
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for shallow user posts'
    end

    describe 'deep nested with hash' do
      before do
        @app = app
        @app.resources :users => {:posts => :comments}
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for nested user posts'
      describe 'exageration' do
        it { @app.route_for(:user_post_comments).should     == '/users/:user_id/posts/:post_id/comments' }
        it { @app.route_for(:new_user_post_comment).should  == '/users/:user_id/posts/:post_id/comments/new' }
        it { @app.route_for(:user_post_comment).should      == '/users/:user_id/posts/:post_id/comments/:id' }
        it { @app.route_for(:edit_user_post_comment).should == '/users/:user_id/posts/:post_id/comments/:id/edit' }
      end
    end
    
    describe 'deep nested shallow with hash' do
      before do
        @app = app
        @app.resources :users => {:posts => :comments}, :shallow => true
      end
      it_should_behave_like 'generates routes for users'
      it_should_behave_like 'generates routes for shallow user posts'
      it { @app.route_for(:post_comments).should     == '/posts/:post_id/comments' }
      it { @app.route_for(:new_post_comment).should  == '/posts/:post_id/comments/new' }
      it { @app.route_for(:comment).should           == '/comments/:id' }
      it { @app.route_for(:edit_comment).should      == '/comments/:id/edit' }
    end
  end
end
