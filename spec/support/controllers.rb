require 'support/exceptions'

class BaseController < ActionController::Base
  include JSONAPI::Utils
  protect_from_forgery with: :null_session
  rescue_from ActiveRecord::RecordNotFound, with: :jsonapi_render_not_found
end

class PostsController < BaseController
  before_action :load_user, except: %i(create index_with_hash show_with_hash update)

  # GET /users/:user_id/posts
  def index
    jsonapi_render json: @user.posts, options: { count: 100 }
  end

  # GET /index_with_hash
  def index_with_hash
    @posts = { data: [
      { id: 1, title: 'Lorem Ipsum', body: 'Body 4' },
      { id: 2, title: 'Dolor Sit', body: 'Body 2' },
      { id: 3, title: 'Dolor Sit', body: 'Body 3' },
      { id: 4, title: 'Dolor Sit', body: 'Body 1' }
    ]}
    # Example of response rendering from Hash + options:
    jsonapi_render json: @posts, options: { model: Post }
  end

  # GET /users/:user_id/posts/:id
  def show
    jsonapi_render json: @user.posts.find(params[:id])
  end

  # GET /show_with_hash/:id
  def show_with_hash
    # Example of response rendering from Hash + options: (2)
    jsonapi_render json: { data: { id: params[:id], title: 'Lorem ipsum' } },
                   options: { model: Post, resource: ::V2::PostResource }
  end

  # POST /posts
  def create
    post = Post.new(post_params)
    post.hidden = 1
    if post.save
      jsonapi_render json: post, status: :created
    else
      jsonapi_render_errors json: post, status: :unprocessable_entity
    end
  end

  # PATCH /posts/:id
  def update
    post = Post.find(params[:id])
    # Example of response rendering with error on base
    post.errors.add(:base, 'This is an error on the base')
    jsonapi_render_errors json: post, status: :unprocessable_entity
  end

  private

  def post_params
    resource_params.merge(user_id: relationship_params[:author], category_id: relationship_params[:category])
  end

  def load_user
    @user = User.find(params[:user_id])
  end
end

class UsersController < BaseController
  # GET /users
  def index
    users = User.all

    # Simulate a custom filter:
    if full_name = params[:filter] && params[:filter][:full_name]
      first_name, *last_name = full_name.split
      users = users.where(first_name: first_name, last_name: last_name.join(' '))
    end

    jsonapi_render json: users
  end

  # GET /users/:id
  def show
    user = User.find(params[:id])
    jsonapi_render json: user
  end

  # POST /users
  def create
    user = User.new(resource_params)
    if user.save
      jsonapi_render json: user, status: :created
    else
      # Example of error rendering for Array of Hashes:
      errors = [
        { id: 'first_name', title: 'First name can\'t be blank', code: '100' },
        { id: 'last_name',  title: 'Last name can\'t be blank',  code: '100' }
      ]

      jsonapi_render_errors json: errors, status: :unprocessable_entity
    end
  end

  # PATCH /users/:id
  def update
    user = User.find(params[:id])
    if user.update(resource_params)
      update_relationships(user)
      jsonapi_render json: user
    else
      # Example of error rendering for exceptions or any object
      # that implements the "errors" method.
      jsonapi_render_errors ::Exceptions::MyCustomError.new(user)
    end
  end

  private

  def update_relationships(user)
    if relationship_params[:posts].present?
      user.post_ids = relationship_params[:posts]
    end
  end
end
