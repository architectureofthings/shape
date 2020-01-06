# == Schema Information
#
# Table name: collection_cards
#
#  id                :bigint(8)        not null, primary key
#  archive_batch     :string
#  archived          :boolean          default(FALSE)
#  archived_at       :datetime
#  col               :integer
#  filter            :integer          default("transparent_gray")
#  height            :integer
#  hidden            :boolean          default(FALSE)
#  identifier        :string
#  image_contain     :boolean          default(FALSE)
#  is_cover          :boolean          default(FALSE)
#  order             :integer          not null
#  pinned            :boolean          default(FALSE)
#  row               :integer
#  section_type      :integer
#  show_replace      :boolean          default(TRUE)
#  type              :string
#  unarchived_at     :datetime
#  width             :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  collection_id     :bigint(8)
#  item_id           :bigint(8)
#  parent_id         :bigint(8)
#  templated_from_id :integer
#
# Indexes
#
#  index_collection_cards_on_archive_batch             (archive_batch)
#  index_collection_cards_on_collection_id             (collection_id)
#  index_collection_cards_on_identifier_and_parent_id  (identifier,parent_id)
#  index_collection_cards_on_item_id                   (item_id)
#  index_collection_cards_on_order_and_row_and_col     (order,row,col)
#  index_collection_cards_on_parent_id                 (parent_id)
#  index_collection_cards_on_templated_from_id         (templated_from_id)
#  index_collection_cards_on_type                      (type)
#

class CollectionCard
  class Placeholder < CollectionCard
  end
end