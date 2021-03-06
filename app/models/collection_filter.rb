# == Schema Information
#
# Table name: collection_filters
#
#  id            :bigint(8)        not null, primary key
#  filter_type   :integer
#  text          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  collection_id :bigint(8)
#
# Indexes
#
#  index_collection_filters_on_collection_id  (collection_id)
#

class CollectionFilter < ApplicationRecord
  belongs_to :collection, touch: true
  has_many :user_collection_filters,
           dependent: :destroy

  scope :tagged_with_user_handle, ->(handle) { user_tag.where(arel_table[:text].lower.eq(handle&.downcase)) }

  validates :text,
            presence: true,
            uniqueness: {
              scope: %i[collection_id filter_type],
              message: 'should not have duplicate filters in a collection',
            }

  enum filter_type: {
    tag: 0,
    search: 1,
    user_tag: 2,
  }

  amoeba do
    enable
    recognize []
    propagate
  end

  def duplicate!(assign_collection: collection)
    cf = amoeba_dup
    cf.collection = assign_collection
    cf.save
    cf
  end

  def reassign_within!(from_collection_id:, to_collection_id:)
    text.sub!(
      "within:#{from_collection_id}",
      "within:#{to_collection_id}",
    )
    save
  end

  def within_collection_id
    return if !search? || text.blank?

    Search::Filters::WithinCollection.new(text).within_collection_id
  end
end
