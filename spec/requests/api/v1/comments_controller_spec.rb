require 'rails_helper'

describe Api::V1::CommentsController, type: :request, json: true, auth: true do
  let(:user) { @user }
  describe 'GET #index' do
    let!(:comment_thread) do
      create(:item_comment_thread, num_comments: 3, add_followers: [user])
    end
    let(:users_thread) { user.users_threads.first }
    let(:last_two_comments) { comment_thread.comments.order(created_at: :desc).first(2) }
    let(:path) { "/api/v1/comment_threads/#{comment_thread.id}/comments?per_page=2" }

    context 'without access to the record' do
      it 'returns a 401' do
        get(path)
        expect(response.status).to eq(401)
      end
    end

    context 'with access to the record' do
      before do
        user.add_role(Role::VIEWER, comment_thread.record)
      end

      it 'returns a 200' do
        get(path)
        expect(response.status).to eq(200)
      end

      it 'gets the most recent comments' do
        get(path)
        # getting 2 per page
        expect(json['data'].count).to be 2
        retrieved_ids = json['data'].map { |comment| comment['id'].to_i }.sort
        expect(retrieved_ids).to eq last_two_comments.map(&:id).sort
      end

      context 'with replies' do
        let(:comment) { comment_thread.comments.last }
        let!(:replies) { create_list(:comment, 2, parent: comment) }

        it 'gets the latest replies in the comment' do
          get(path)
          json_comment = json['data'].select { |c| c['id'] == comment.id.to_s }.first
          latest_replies = json_comment['relationships']['latest_replies']['data']
          expect(latest_replies.map { |c| c['id'].to_i }).to match_array(replies.map(&:id))
        end
      end
    end
  end

  describe 'GET #replies' do
    let!(:comment) { create(:comment) }
    let!(:replies) { create_list(:comment, 3, parent: comment) }
    let(:path) { "/api/v1/comments/#{comment.id}/replies" }

    context 'without access to the record' do
      it 'returns a 401' do
        get(path)
        expect(response.status).to eq(401)
      end
    end

    context 'with access to the record' do
      before do
        user.add_role(Role::VIEWER, comment.comment_thread.record)
      end

      it 'returns a 200' do
        get(path)
        expect(response.status).to eq(200)
      end

      it 'gets the most recent replies' do
        get(path)
        expect(json['data'].count).to be 3
        expect(json['data'].first['attributes']).to match_json_schema('comment')
        retrieved_ids = json['data'].map { |comment| comment['id'].to_i }
        expect(retrieved_ids).to match_array replies.map(&:id)
      end

      context 'with pagination' do
        let(:path) { "/api/v1/comments/#{comment.id}/replies?page=2" }

        it 'gets the next page (which is empty)' do
          get(path)
          expect(json['data'].count).to be 0
        end
      end
    end
  end

  describe 'POST #create' do
    let!(:comment_thread) { create(:item_comment_thread) }
    let(:path) { "/api/v1/comment_threads/#{comment_thread.id}/comments" }
    let(:instance_double) do
      double('ActivityAndNotificationBuilder')
    end
    let(:params) {
      json_api_params(
        'comments',
        message: 'heyo',
      )
    }

    before do
      user.add_role(Role::EDITOR, comment_thread.record)
    end

    it 'returns a 200' do
      post(path, params: params)
      expect(response.status).to eq(200)
    end

    it 'matches JSON schema for comment' do
      post(path, params: params)
      expect(json['data']['attributes']).to match_json_schema('comment')
    end

    it 'creates a message in the thread' do
      post(path, params: params)
      expect(comment_thread.comments.count).to eq(1)
      expect(comment_thread.comments.first.message).to eq('heyo')
    end

    it 'creates an activity and notifications for the content' do
      Sidekiq::Testing.inline! do
        expect(ActivityAndNotificationBuilder).to receive(:call).with(
          actor: @user,
          target: comment_thread.record,
          action: :commented,
          subject_user_ids: [user.id],
          subject_group_ids: [],
          omit_user_ids: [],
          omit_group_ids: [],
          combine: true,
          content: 'heyo',
        )
        post(path, params: params)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:comment_thread) { create(:item_comment_thread) }
    let(:path) { "/api/v1/comments/#{comment.id}" }

    before do
      user.add_role(Role::EDITOR, comment_thread.record)
    end

    context 'when user is not comment author' do
      let!(:comment) { create(:comment, comment_thread: comment_thread) }

      it 'returns a 401' do
        delete(path)
        expect(response.status).to eq(401)
      end
    end

    context 'when user is comment author' do
      let!(:comment) { create(:comment, comment_thread: comment_thread, author: user) }

      it 'deletes the comment' do
        expect {
          delete(path)
        }.to change(Comment, :count).from(1).to(0)
        expect(response.status).to eq(204)
      end
    end
  end

  describe 'PATCH #update' do
    let!(:comment_thread) { create(:item_comment_thread) }
    let(:path) { "/api/v1/comments/#{comment.id}" }
    let(:params) {
      json_api_params(
        'comments',
        message: 'edited comment',
      )
    }

    context 'when user is not comment author' do
      let!(:comment) { create(:comment, comment_thread: comment_thread) }

      it 'returns a 401' do
        patch(path, params: params)
        expect(response.status).to eq(401)
      end
    end

    context 'when user is comment author' do
      let!(:comment) { create(:comment, comment_thread: comment_thread, author: user) }

      it 'returns a 200' do
        patch(path, params: params)
        expect(response.status).to eq(200)
      end

      it 'updates the content' do
        expect(comment.message).not_to eq('edited comment')
        patch(path, params: params)
        expect(comment.reload.message).to eq('edited comment')
      end
    end
  end
end
