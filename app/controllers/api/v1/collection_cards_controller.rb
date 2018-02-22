class Api::V1::CollectionCardsController < Api::V1::BaseController
  deserializable_resource :collection_card, class: DeserializableCollectionCard, only: [:create, :update]
  load_and_authorize_resource :collection, only: [:index, :create]
  load_and_authorize_resource
  before_action :load_parent_collection, only: [:create]

  def index
    render jsonapi: @collection.collection_cards
  end

  def show
    render jsonapi: @collection_card
  end

  def create
    builder = CollectionCardBuilder.new(params: collection_card_params,
                                        collection: @collection,
                                        user: current_user)
    if builder.create
      render jsonapi: builder.collection_card, include: [record: [:filestack_file]]
    else
      render jsonapi_errors: builder.collection_card.errors, status: :bad_request
    end
  end

  def update
    @collection_card.attributes = collection_card_params
    if @collection_card.save
      render jsonapi: @collection_card
    else
      render jsonapi_errors: @collection_card.errors, status: :bad_request
    end
  end

  private

  def load_parent_collection
    @collection = Collection.find(collection_card_params[:parent_id])
  end

  def collection_card_params
    params.require(:collection_card).permit(
      :order,
      :width,
      :height,
      :reference,
      :parent_id,
      :collection_id,
      :item_id,
      collection_attributes: %i[id name],
      item_attributes: [
        :id,
        :type,
        :name,
        :content,
        :image,
        :archived,
        filestack_file_attributes: [
          :url,
          :handle,
          :filename,
          :size,
          :mimetype,
        ],
      ]
    )
  end
end
