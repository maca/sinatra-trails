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
      end

      it { @app.route_for(:root).should       == '/' }
      it { @app.route_for(:dashboard).should  == '/dashboard' }
      it { @app.route_for('dashboard').should == '/dashboard' }
      it { lambda{ @app.route_for(:missing) }.should raise_error Sinatra::Trails::RouteNotDefined }
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
          match :posts => '/posts'
          namespace '/admin' do
            match :dashboard => '/dashboard'
            namespace '/auth' do
              match :logout => '/logout'
              match :login  => '/login'
            end
          end
        end
      end
      it { @app.route_for(:posts).should     == '/blog/posts' }
      it { @app.route_for(:dashboard).should == '/blog/admin/dashboard' }
      it { @app.route_for(:logout).should    == '/blog/admin/auth/logout' }
      it { @app.route_for(:login).should     == '/blog/admin/auth/login' }
    end

    describe 'with named nested namespace' do
      before do
        @app.namespace :blog do
          match :posts => '/posts'
          namespace :admin do
            match :dashboard => '/dashboard'
            namespace :auth do
              match :logout => '/logout'
              match :login  => '/login'
            end
          end
        end
      end
      it { @app.route_for(:blog_posts).should             == '/blog/posts' }
      it { @app.route_for(:blog_admin_dashboard).should   == '/blog/admin/dashboard' }
      it { @app.route_for(:blog_admin_auth_logout).should == '/blog/admin/auth/logout' }
      it { @app.route_for(:blog_admin_auth_login).should  == '/blog/admin/auth/login' }
    end
  end

  
  describe 'resources' do
    shared_examples_for 'generates routes for post resources' do
      it { @app.route_for(:posts).should      == '/posts' }
      it { @app.route_for(:new_post).should   == '/posts/new' }
      it { @app.route_for(:post).should       == '/posts/:id' }
      it { @app.route_for(:edit_post).should  == '/posts/:id/edit' }
    end

    describe 'basic' do
      before do
        @app = app
        @app.resources :posts
      end
      it_should_behave_like 'generates routes for post resources'
    end

    describe 'nested' do
      before do
        @app = app
        @app.resources :posts do
          resources :comments
        end
      end

      it_should_behave_like 'generates routes for post resources'
      it { @app.route_for(:post_comments).should     == '/posts/:post_id/comments' }
      it { @app.route_for(:new_post_comment).should  == '/posts/:post_id/comments/new' }
      it { @app.route_for(:post_comment).should      == '/posts/:post_id/comments/:id' }
      it { @app.route_for(:edit_post_comment).should == '/posts/:post_id/comments/:id/edit' }
      it { lambda{ @app.route_for(:comment) }.should raise_error Sinatra::Trails::RouteNotDefined }
      it { lambda{ @app.route_for(:edit_comment) }.should raise_error Sinatra::Trails::RouteNotDefined }
    end

    describe 'shallow nested resources' do
      before do
        @app = app
        @app.resources :posts, :shallow => true do
          resources :comments
        end
      end

      it_should_behave_like 'generates routes for post resources'
      it { @app.route_for(:post_comments).should     == '/posts/:post_id/comments' }
      it { @app.route_for(:new_post_comment).should  == '/posts/:post_id/comments/new' }
      it { @app.route_for(:comment).should           == '/comments/:id' }
      it { @app.route_for(:edit_comment).should      == '/comments/:id/edit' }
      it { lambda{ @app.route_for(:post_comment) }.should raise_error Sinatra::Trails::RouteNotDefined }
      it { lambda{ @app.route_for(:edit_post_comment) }.should raise_error Sinatra::Trails::RouteNotDefined }
      it { lambda{ @app.route_for(:new_comment) }.should raise_error Sinatra::Trails::RouteNotDefined }
      it { lambda{ @app.route_for(:comments) }.should raise_error Sinatra::Trails::RouteNotDefined }
    end
  end

  # describe 'singular resource', :focused => true do
  #   before :all do
  #     @app = app
  #     @app.resource :post
  #   end

  #   describe 'route generation' do
  #     it { @app.route_for(:post).should       == '/post' }
  #     it { @app.route_for(:new_post).should   == '/post/new' }
  #     it { @app.route_for(:edit_post).should  == '/post/edit' }
  #   end
  # end


  # describe 'shallow nested resources' do
  #   before :all do
  #     @app = app
  #     @app.resources :posts, :shallow => true do
  #       resources :comments
  #     end
  #   end

  #   describe 'route generation' do
  #     it_should_behave_like 'generates routes for post resources'
  #     it { @app.route_for(:post_comments).should     == '/posts/:post_id/comments' }
  #     it { @app.route_for(:new_post_comment).should  == '/posts/:post_id/comments/new' }
  #     it { @app.route_for(:comment).should           == '/comments/:id' }
  #     it { @app.route_for(:edit_comment).should      == '/comments/:id/edit' }
  #   end
  # end

  # describe 'resources with custom path names' do
  #   before :all do
  #     @app = app
  #     @app.resources :posts, :path_names => {:new => 'nuevo', :edit => 'editar'}
  #   end

  #   describe 'route generation' do
  #     it { @app.route_for(:posts).should      == '/posts' }
  #     it { @app.route_for(:new_post).should   == '/posts/nuevo' }
  #     it { @app.route_for(:post).should       == '/posts/:id' }
  #     it { @app.route_for(:edit_post).should  == '/posts/:id/editar' }
  #   end
  # end

  # describe 'resources with custom prefix' do
  #   before :all do
  #     @app = app
  #     @app.resources :posts, :prefix => 'user'
  #   end

  #   describe 'route generation' do
  #     it { @app.route_for(:posts).should      == '/user/posts' }
  #     it { @app.route_for(:new_post).should   == '/user/posts/new' }
  #     it { @app.route_for(:post).should       == '/user/posts/:id' }
  #     it { @app.route_for(:edit_post).should  == '/user/posts/:id/edit' }
  #   end
  # end

  # describe 'resources with custom path' do
  #   before :all do
  #     @app = app
  #     @app.resources :posts, :path => 'entries'
  #   end

  #   describe 'route generation' do
  #     it { @app.route_for(:posts).should      == '/entries' }
  #     it { @app.route_for(:new_post).should   == '/entries/new' }
  #     it { @app.route_for(:post).should       == '/entries/:id' }
  #     it { @app.route_for(:edit_post).should  == '/entries/:id/edit' }
  #   end
  # end

  # describe 'resources with custom actions' do
  #   before :all do
  #     @app = app
  #     @app.resources :posts do
  #       member :publish, :unpublish
  #       collection :published, :unpublished
  #     end
  #   end

  #   describe 'route generation' do
  #     it_should_behave_like 'generates routes for post resources'
  #     it { @app.route_for(:published_posts).should   == '/posts/published' }
  #     it { @app.route_for(:unpublished_posts).should == '/posts/unpublished' }
  #     it { @app.route_for(:publish_post).should      == '/posts/:id/publish' }
  #     it { @app.route_for(:unpublish_post).should    == '/posts/:id/unpublish' }
  #   end
  # end

  # describe 'resources with custom actions and custom path for custom actions' do
  #   before :all do
  #     @app = app
  #     @app.resources :posts do
  #       member :publish, :path => 'publicar'
  #       collection :published, :path => 'publicados'
  #     end
  #   end

  #   describe 'route generation' do
  #     it_should_behave_like 'generates routes for post resources'
  #     it { @app.route_for(:publish_post).should      == '/posts/:id/publicar' }
  #     it { @app.route_for(:published_posts).should   == '/posts/publicados' }
  #   end
  # end
end
