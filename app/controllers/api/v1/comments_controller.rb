class Api::V1::CommentsController < Api::V1::BaseController
  deserializable_resource :comment, class: DeserializableComment, only: %i[create update resolve]
  load_and_authorize_resource :comment_thread, only: %i[index create]
  load_and_authorize_resource :comment, only: %i[destroy update]
  def index
    paginated_comments = @comment_thread
                         .comments
                         .includes(:author)
                         .page(@page)
                         .per(per_page)
    render jsonapi: paginated_comments, include: [
      :author,
      :subject,
      latest_replies: :author,
    ]
  end

  before_action :load_and_authorize_comment, only: %i[replies resolve]
  def replies
    paginated_replies = @comment.replies_by_page(page: @page).includes(:author)
    render jsonapi: paginated_replies, include: %i[
      author
      parent
    ]
  end

  def create
    parent_id = comment_params[:parent_id] || nil
    parent = Comment.find parent_id unless parent_id.nil?
    @comment = CommentCreator.call(
      comment_thread: @comment_thread,
      message: comment_params[:message],
      draftjs_data: comment_params[:draftjs_data],
      subject_id: comment_params[:subject_id],
      subject_type: comment_params[:subject_type],
      author: current_user,
      parent: parent,
    )
    if @comment
      render jsonapi: @comment
    else
      render jsonapi: @comment.errors
    end
  end

  def destroy
    if @comment.destroy
      head :no_content
    else
      render_api_errors @comment.errors
    end
  end

  def update
    success = CommentUpdater.call(
      comment: @comment,
      message: comment_params[:message],
      draftjs_data: comment_params[:draftjs_data],
    )

    if success
      render jsonapi: @comment
    else
      render_api_errors @comment.errors
    end
  end

  def resolve
    success = CommentResolver.call(
      comment: @comment,
      user: current_user,
      status: comment_params[:status],
    )

    if success
      render jsonapi: @comment, include: :subject
    else
      render_api_errors @comment.errors
    end
  end

  private

  def load_and_authorize_comment
    @comment = Comment.find params[:id]
    authorize! :read, @comment
  end

  def per_page
    # use passed in param, default to COMMENTS_PER_PAGE, max out at 100
    [(params[:per_page] || Comment::COMMENTS_PER_PAGE).to_i, 100].min
  end

  def comment_attributes
    %i[
      message
      parent_id
      status
      subject_id
      subject_type
    ].concat([draftjs_data: {}])
  end

  def comment_params
    params.require(:comment).permit(
      comment_attributes,
    )
  end
end
