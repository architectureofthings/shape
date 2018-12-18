class Api::V1::BaseController < ApplicationController
  before_action :check_api_authentication!
  before_action :check_cancel_sync

  respond_to :json

  # See all configuration options for the jsonapi in the jsonapi-rb-rails gem

  # jsonapi-rb has issues inferring STI classes,
  # so we must explicitly tell it what serializer to use
  # See: https://github.com/jsonapi-rb/jsonapi-rails/issues/68
  def jsonapi_class
    super.merge(
      'Item::VideoItem': SerializableItem,
      'Item::TextItem': SerializableItem,
      'Item::FileItem': SerializableItem,
      'Item::LinkItem': SerializableItem,
      'Item::QuestionItem': SerializableItem,
      'Item::ChartItem': SerializableItem,
      'Item::DataItem': SerializableDataItem,
      'Collection::UserCollection': SerializableCollection,
      'Collection::SharedWithMeCollection': SerializableCollection,
      'Collection::Global': SerializableCollection,
      'Collection::TestCollection': SerializableCollection,
      'Collection::TestDesign': SerializableCollection,
      'Collection::TestOpenResponses': SerializableCollection,
      'Collection::SubmissionBox': SerializableCollection,
      'Collection::SubmissionsCollection': SerializableSubmissionsCollection,
      'Collection::UserProfile': SerializableCollection,
      'CollectionCard::Primary': SerializableCollectionCard,
      'CollectionCard::Link': SerializableCollectionCard,
    )
  end

  # Add items to this hash to make them available
  # as @instance_vars in serializable resources
  def jsonapi_expose
    {
      current_user: current_user,
      current_ability: current_ability,
    }
  end

  def json_api_params
    params[:_jsonapi] || {}
  end

  def jsonapi_pagination(collection)
    # check for pagination being enabled
    return unless (current_page = collection.try(:current_page))
    # NOTE: we are not following JSONAPI format, instead
    # just returning the page number rather than absolute URL
    {
      first: 1,
      last: collection.total_pages,
      prev: collection.first_page? ? nil : current_page - 1,
      next: collection.last_page? ? nil : current_page + 1,
    }
  end

  def render_api_errors(errors)
    render jsonapi_errors: errors, status: :bad_request
  end

  rescue_from CanCan::AccessDenied do |exception|
    render json: { errors: [exception.message] }, status: :unauthorized
  end

  private

  def render_collection(include: nil)
    # include collection_cards for UI to receive any updates
    include ||= Collection.default_relationships_for_api
    render jsonapi: @collection,
           include: include,
           expose: {
             current_record: @collection,
             card_order: params[:card_order],
           }
  end

  def check_api_authentication!
    head(401) unless user_signed_in? && !current_user.archived?
  end

  def current_organization
    @current_organization ||= current_user.try(:current_organization)
  end

  def check_cancel_sync
    return unless json_api_params[:data]
    @cancel_sync = json_api_params[:data].delete :cancel_sync
  end
end
