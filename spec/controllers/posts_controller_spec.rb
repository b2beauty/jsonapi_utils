require 'spec_helper'

describe PostsController, type: :controller do
  include_context 'JSON API headers'

  before(:all) { FactoryGirl.create_list(:post, 3) }

  before(:each) do
    JSONAPI.configuration.json_key_format = :underscored_key
  end

  let(:fields)        { (PostResource.fields - %i(id author category)).map(&:to_s) }
  let(:relationships) { %w(author category) }
  let(:first_post)    { Post.first }
  let(:user_id)       { first_post.user_id }
  let(:category_id)   { first_post.category_id }

  let(:attributes) do
    { title: 'Lorem ipsum', body: 'Lorem ipsum dolor sit amet.', content_type: 'article' }
  end

  let(:author_params) do
    { data: { type: 'users', id: user_id } }
  end

  let(:category_params) do
    { data: { type: 'categories', id: category_id } }
  end

  let(:post_params) do
    {
      data: {
        type: 'posts',
        attributes: attributes,
        relationships: { author: author_params, category: category_params }
      }
    }
  end

  describe '#index' do
    context 'with ActiveRecord::Relation' do
      it 'renders a collection of users' do
        get :index, user_id: user_id

        expect(response).to have_http_status :ok

        expect(response).to have_primary_data('posts')
        expect(response).to have_data_attributes(fields)
        expect(response).to have_relationships(relationships)
        expect(response).to have_meta_record_count(100)
      end
    end

    context 'with Hash' do
      it 'renders a collection of users' do
        get :index_with_hash

        expect(response).to have_http_status :ok

        expect(response).to have_primary_data('posts')
        expect(response).to have_data_attributes(fields)
        expect(response).to have_relationships(relationships)
      end

      it 'sorts Hashes by asc/desc order' do
        get :index_with_hash, sort: 'title,-body'

        expect(response).to have_http_status :ok

        sorted_data = data.sort do |a, b|
          comp = a['attributes']['title'] <=> b['attributes']['title']
          comp == 0 ? b['attributes']['body'] <=> a['attributes']['body'] : comp
        end

        expect(data).to eq(sorted_data)
      end

      context 'when using custom global paginator' do
        before(:all) do
          JSONAPI.configuration.default_paginator = :custom_offset
        end

        it 'returns paginated results' do
          get :index_with_hash, page: { offset: 0, limit: 2 }

          expect(response).to have_http_status :ok
          expect(data.size).to eq(2)
          expect(response).to have_meta_record_count(4)

          expect(json['links']['first']).to be_present
          expect(json['links']['next']).to be_present
          expect(json['links']['last']).to be_present
        end

        context 'at the middle' do
          it 'returns paginated results' do
            get :index_with_hash, page: { offset: 1, limit: 1 }

            expect(response).to have_http_status :ok
            expect(data.size).to eq(1)
            expect(response).to have_meta_record_count(4)

            expect(json['links']['first']).to be_present
            expect(json['links']['prev']).to be_present
            expect(json['links']['next']).to be_present
            expect(json['links']['last']).to be_present
          end
        end

        context 'at the last page' do
          it 'returns the paginated results' do
            get :index_with_hash, page: { offset: 3, limit: 1 }

            expect(response).to have_http_status :ok
            expect(data.size).to eq(1)
            expect(response).to have_meta_record_count(4)

            expect(json['links']['first']).to be_present
            expect(json['links']['prev']).to be_present
            expect(json['links']['next']).not_to be_present
            expect(json['links']['last']).to be_present
          end
        end

        context 'without "limit"' do
          it 'returns the amount of results based on "JSONAPI.configuration.default_page_size"' do
            get :index_with_hash, page: { offset: 1 }
            expect(response).to have_http_status :ok
            expect(data.size).to be <= JSONAPI.configuration.default_page_size
            expect(response).to have_meta_record_count(4)
          end
        end
      end
    end
  end

  describe '#show' do
    context 'with ActiveRecord' do
      it 'renders a single post' do
        get :show, user_id: user_id, id: first_post.id

        expect(response).to have_http_status :ok

        expect(response).to have_primary_data('posts')
        expect(response).to have_data_attributes(fields)
        expect(response).to have_relationships(relationships)
        expect(data['attributes']['title']).to eq("Title for Post #{first_post.id}")
      end
    end

    context 'with Hash' do
      it 'renders a single post' do
        get :show_with_hash, id: 1

        expect(response).to have_http_status :ok

        expect(response).to have_primary_data('posts')
        expect(response).to have_data_attributes(fields)
        expect(response).to have_relationships(relationships)
        expect(data['attributes']['title']).to eq('Lorem ipsum')
      end
    end

    context 'when resource was not found' do
      context 'with conventional id' do
        it 'renders a 404 response' do
          get :show, user_id: user_id, id: 999

          expect(response).to have_http_status :not_found

          expect(error['title']).to eq('Record not found')
          expect(error['detail']).to include('999')
          expect(error['code']).to eq('404')
        end
      end

      context 'with uuid' do
        let(:uuid) { SecureRandom.uuid }

        it 'renders a 404 response' do
          get :show, user_id: user_id, id: uuid

          expect(response).to have_http_status :not_found

          expect(error['title']).to eq('Record not found')
          expect(error['detail']).to include(uuid)
          expect(error['code']).to eq('404')
        end
      end

      context 'with slug' do
        let(:slug) { 'some-awesome-slug' }

        it 'renders a 404 response' do
          get :show, user_id: user_id, id: slug

          expect(response).to have_http_status :not_found

          expect(error['title']).to eq('Record not found')
          expect(error['detail']).to include(slug)
          expect(error['code']).to eq('404')
        end
      end
    end
  end

  describe '#create' do
    it 'creates a new post' do
      expect { post :create, post_params }.to change(Post, :count).by(1)

      expect(response).to have_http_status :created

      expect(response).to have_primary_data('posts')
      expect(response).to have_data_attributes(fields)
      expect(data['attributes']['title']).to eq(post_params[:data][:attributes][:title])
    end

    context 'when validation fails on an attribute' do
      it 'renders a 422 response' do
        post_params[:data][:attributes][:title] = nil

        expect { post :create, post_params }.to change(Post, :count).by(0)
        expect(response).to have_http_status :unprocessable_entity

        expect(errors[0]['id']).to eq('title')
        expect(errors[0]['title']).to eq('Title can\'t be blank')
        expect(errors[0]['code']).to eq('100')
        expect(errors[0]['source']['pointer']).to eq('/data/attributes/title')
      end
    end

    context 'when validation fails on a relationship' do
      it 'renders a 422 response' do
        post_params[:data][:relationships][:author] = nil

        expect { post :create, post_params }.to change(Post, :count).by(0)
        expect(response).to have_http_status :unprocessable_entity

        expect(errors[0]['id']).to eq('author')
        expect(errors[0]['title']).to eq('Author can\'t be blank')
        expect(errors[0]['code']).to eq('100')
        expect(errors[0]['source']['pointer']).to eq('/data/relationships/author')
      end
    end

    context 'when validation fails on a foreign key' do
      it 'renders a 422 response' do
        post_params[:data][:relationships][:category] = nil

        expect { post :create, post_params }.to change(Post, :count).by(0)
        expect(response).to have_http_status :unprocessable_entity

        expect(errors[0]['id']).to eq('category')
        expect(errors[0]['title']).to eq('Category can\'t be blank')
        expect(errors[0]['code']).to eq('100')
        expect(errors[0]['source']['pointer']).to eq('/data/relationships/category')
      end
    end

    context 'when validation fails on a private attribute' do
      it 'renders a 422 response' do
        post_params[:data][:attributes][:title] = 'Fail Hidden'

        expect { post :create, post_params }.to change(Post, :count).by(0)
        expect(response).to have_http_status :unprocessable_entity

        expect(errors[0]['id']).to eq('hidden')
        expect(errors[0]['title']).to eq('Hidden error was tripped')
        expect(errors[0]['code']).to eq('100')
        expect(errors[0]['source']).to be_nil
      end
    end

    context 'when validation fails with a formatted attribute key' do
      let!(:key_format_was) { JSONAPI.configuration.json_key_format }
      before { JSONAPI.configure { |config| config.json_key_format = :dasherized_key } }
      after { JSONAPI.configure { |config| config.json_key_format = key_format_was } }

      let(:attributes) do
        { title: 'Lorem ipsum', body: 'Lorem ipsum dolor sit amet.' }
      end

      it 'renders a 422 response' do
        expect { post :create, post_params }.to change(Post, :count).by(0)
        expect(response).to have_http_status :unprocessable_entity

        expect(errors[0]['id']).to eq('content-type')
        expect(errors[0]['title']).to eq('Content type can\'t be blank')
        expect(errors[0]['code']).to eq('100')
        expect(errors[0]['source']['pointer']).to eq('/data/attributes/content-type')
      end
    end
  end

  describe '#update' do
    context 'when validation fails on base' do
      let(:update_params) do
        post_params.tap do |params|
          params[:data][:id] = first_post.id
          params[:id] = first_post.id
        end
      end

      it 'renders a 422 response' do
        expect { patch :update, update_params }.to change(Post, :count).by(0)
        expect(response).to have_http_status :unprocessable_entity

        expect(errors[0]['id']).to eq('base')
        expect(errors[0]['title']).to eq('This is an error on the base')
        expect(errors[0]['code']).to eq('100')
        expect(errors[0]['source']['pointer']).to eq('/data')
      end
    end
  end
end
