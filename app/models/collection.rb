class Collection < ApplicationRecord
  include Breadcrumbable
  include Resourceable
  include Archivable
  include RealtimeEditorsViewers
  include HasActivities
  include Templateable
  include Testable
  include Externalizable

  resourceable roles: [Role::EDITOR, Role::CONTENT_EDITOR, Role::VIEWER],
               edit_role: Role::EDITOR,
               content_edit_role: Role::CONTENT_EDITOR,
               view_role: Role::VIEWER

  archivable as: :parent_collection_card,
             with: %i[collection_cards cards_linked_to_this_collection]
  after_archive :remove_comment_followers!
  acts_as_taggable

  store_accessor :cached_attributes,
                 :cached_cover,
                 :cached_tag_list,
                 :cached_owned_tag_list,
                 :cached_card_count,
                 :submission_attrs,
                 :getting_started_shell,
                 :awaiting_first_user_content,
                 :cached_inheritance

  # callbacks
  after_touch :touch_related_cards, unless: :destroyed?
  after_commit :touch_related_cards, if: :saved_change_to_updated_at?, unless: :destroyed?

  after_commit :reindex_sync, on: :create
  after_commit :update_comment_thread_in_firestore, unless: :destroyed?
  after_save :pin_all_primary_cards, if: :now_master_template?

  # all cards including archived (i.e. undo default :collection_cards scope)
  has_many :all_collection_cards,
           class_name: 'CollectionCard',
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :destroy

  # all active cards including links
  # i.e. this is what is displayed in the frontend for collection.collection_cards
  has_many :collection_cards,
           -> { active.ordered },
           class_name: 'CollectionCard',
           foreign_key: :parent_id,
           inverse_of: :parent

  # cards where the item/collection "lives" in this collection
  has_many :primary_collection_cards,
           -> { active.ordered },
           class_name: 'CollectionCard::Primary',
           foreign_key: :parent_id,
           inverse_of: :parent

  # cards where the item/collection is linked into this collection
  has_many :link_collection_cards,
           -> { active.ordered },
           class_name: 'CollectionCard::Link',
           foreign_key: :parent_id,
           inverse_of: :parent

  # cards that live outside this collection, linking to this collection
  has_many :cards_linked_to_this_collection,
           class_name: 'CollectionCard::Link',
           inverse_of: :collection,
           dependent: :destroy

  # the card that represents this collection in its parent, and determines its breadcrumb
  has_one :parent_collection_card,
          class_name: 'CollectionCard::Primary',
          inverse_of: :collection,
          dependent: :destroy

  has_many :collection_cover_cards,
           -> { active.is_cover.ordered },
           class_name: 'CollectionCard::Primary',
           foreign_key: :parent_id,
           inverse_of: :parent

  has_many :items, through: :primary_collection_cards
  has_many :collections, through: :primary_collection_cards
  has_many :items_and_linked_items,
           through: :collection_cards,
           source: :item
  has_many :collections_and_linked_collections,
           through: :collection_cards,
           source: :collection
  has_many :collection_cover_items,
           through: :collection_cover_cards,
           source: :item

  has_one :comment_thread, as: :record, dependent: :destroy

  delegate :parent, :pinned, :pinned?, :pinned_and_locked?,
           to: :parent_collection_card, allow_nil: true

  belongs_to :organization
  belongs_to :cloned_from, class_name: 'Collection', optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :question_item, class_name: 'Item::QuestionItem', optional: true

  validates :name, presence: true
  before_validation :inherit_parent_organization_id, on: :create

  scope :root, -> { where('jsonb_array_length(breadcrumb) = 1') }
  scope :not_custom_type, -> { where(type: nil) }
  scope :user_collection, -> { where(type: 'Collection::UserCollection') }
  scope :application_collection, -> { where(type: 'Collection::ApplicationCollection') }
  scope :shared_with_me, -> { where(type: 'Collection::SharedWithMeCollection') }
  scope :searchable, -> { where.not(type: unsearchable_types).or(where(type: nil)) }
  scope :data_collectable, -> { where.not(type: uncollectable_types).or(where(type: nil)) }
  scope :master_template, -> { where(master_template: true) }

  accepts_nested_attributes_for :collection_cards

  enum processing_status: {
    processing_breadcrumb: 1,
    duplicating: 2,
  }

  enum cover_type: {
    cover_type_default: 0,
    cover_type_items: 1,
  }

  # Searchkick Config
  # Use queue to bulk reindex every 5m (with Sidekiq Scheduled Job/ActiveJob)
  searchkick callbacks: :queue

  # active == don't index archived collections
  # where(type: nil) == don't index User/SharedWithMe collections
  scope :search_import, -> do
    active.searchable.includes(
      [
        {
          items: %i[
            tags
            taggings
          ],
        },
        :tags,
        :taggings,
      ],
    )
  end

  def self.unsearchable_types
    [
      'Collection::UserCollection',
      'Collection::SharedWithMeCollection',
    ]
  end

  def self.uncollectable_types
    Collection.unsearchable_types +
      [
        'Collection::GlobalCollection',
      ]
  end

  # By default all string fields are searchable
  def search_data
    parent_ids = breadcrumb
    activity_dates = activities.map do |activity|
      activity.updated_at.to_date
    end.uniq
    {
      name: name,
      tags: all_tag_names,
      item_tags: items.map(&:tags).flatten.map(&:name),
      content: search_content,
      organization_id: organization_id,
      user_ids: search_user_ids,
      group_ids: search_group_ids,
      parent_ids: parent_ids,
      activity_dates: activity_dates.empty? ? nil : activity_dates,
    }
  end

  def all_tag_names
    # We include item tags because you currently can't search for items
    (all_tags_list + items.map(&:tag_list)).uniq
  end

  def search_content
    # TODO: indexing private sub-content differently?
    # Current functionality for getting a collection's searchable "text content":
    # - go through all items in the collection
    # - for TextItems, grab the first 200 characters of their content
    # - for other items (e.g. media), grab the name
    # - join it all together into one blob of text, remove non-normal characters
    items.map do |item|
      if item.is_a? Item::TextItem
        item.plain_content.truncate(200, separator: /\s/, omission: '')
      else
        item.name
      end
    end.join(' ').gsub(/[^\p{Alnum}\s]/, ' ')
  end
  # <-- End Searchkick

  # default relationships to include when rendering Collections in the API
  def self.default_relationships_for_api
    [
      :created_by,
      :organization,
      :parent_collection_card,
      :parent,
      :submissions_collection,
      :submission_template,
      :collection_to_test,
      :live_test_collection,
      :collection_cover_items,
      roles: %i[pending_users users groups resource],
    ]
  end

  # similar to above but for AR .includes(...)
  # requires `collection/item` instead of `record`
  def self.default_relationships_for_query
    [
      :created_by,
      :organization,
      parent_collection_card: %i[parent],
      roles: %i[users groups resource],
    ]
  end

  amoeba do
    enable
    # propagate to STI models
    propagate
    nullify :breadcrumb
    nullify :created_by_id
    nullify :organization_id
    set archived: false
    # don't recognize any relations, easiest way to turn them all off
    recognize []
  end

  def duplicate!(
    for_user: nil,
    copy_parent_card: false,
    parent: self.parent,
    building_template_instance: false,
    system_collection: false,
    synchronous: false
  )

    # check if we are cloning a template inside a template instance;
    # - this means we should likewise turn the template dup into its own instance
    if master_template? && building_template_instance
      builder = CollectionTemplateBuilder.new(
        parent: parent,
        template: self,
        placement: parent_collection_card.order,
        created_by: for_user,
        # in this case the card has already been created
        parent_card: parent_collection_card,
      )
      return builder.call
    end
    # Clones collection and all embedded items/collections
    c = amoeba_dup
    # clear out cached submission_attrs
    c.cached_attributes.delete 'submission_attrs'
    c.cloned_from = self
    c.created_by = for_user
    c.tag_list = tag_list
    # copy roles from parent (i.e. where it's being placed)
    c.roles_anchor_collection_id = parent.roles_anchor.id

    # copy organization_id from the collection this is being moved into
    # NOTE: parent is only nil in Colab import -- perhaps we should clean up any Colab import specific code?
    c.organization_id = parent.try(:organization_id) || organization_id

    if system_collection && self.parent.try(:parent).try(:getting_started?)
      c.getting_started_shell = true
    end

    # save the dupe collection first so that we can reference it later
    # return if it didn't work for whatever reason
    return c unless c.save
    c.parent_collection_card.save if c.parent_collection_card.present?

    if copy_parent_card && parent_collection_card.present?
      c.parent_collection_card = parent_collection_card.duplicate!(
        for_user: for_user,
        shallow: true,
        parent: parent,
      )
      c.parent_collection_card.collection = c
    end

    # Method from Externalizable
    duplicate_external_records(c)

    c.enable_org_view_access_if_allowed(parent)

    if collection_cards.any? && !c.getting_started_shell
      worker_opts = [
        collection_cards.map(&:id),
        c.id,
        for_user.try(:id),
        system_collection,
        synchronous,
      ]
      if synchronous
        CollectionCardDuplicationWorker.new.perform(*worker_opts)
      else
        CollectionCardDuplicationWorker.perform_async(*worker_opts)
      end
    end

    # pick up newly created relationships
    c.reload
  end

  def copy_all_cards_into!(
    target_collection,
    placement: 'beginning',
    synchronous: false,
    system_collection: false
  )
    cards = placement != 'end' ? collection_cards.reverse : collection_cards
    duplicates = []
    cards.each do |card|
      # ensures single copy, if existing copies already exist it will skip those
      existing_records = target_collection.collection_cards.map(&:record)
      next if existing_records.select { |r| r.cloned_from == card.record }.present?
      duplicates << card.duplicate!(
        parent: target_collection,
        placement: placement,
        synchronous: synchronous,
        # can allow copies to continue even if the user can't view the original content
        system_collection: system_collection,
      )
    end
    # return the set of created duplicates
    CollectionCard.where(id: duplicates.pluck(:id))
  end

  # NOTE: this refers to the first level of children
  # i.e. things directly in this collection
  def children
    (items + collections)
  end

  def children_and_linked_children
    (items_and_linked_items + collections_and_linked_collections)
  end

  def searchable?
    true
  end

  def should_index?
    active?
  end

  def read_only?
    false
  end

  def breadcrumb_title
    name
  end

  def submissions_collection
    nil
  end

  def submission_template
    nil
  end

  def collection_to_test
    nil
  end

  def resourceable_class
    # Use top-level class since this is an STI model
    Collection
  end

  def recalculate_child_breadcrumbs_async
    BreadcrumbRecalculationWorker.perform_async(id)
  end

  # Cards are explicitly passed in when moving them from another collection to this one
  def recalculate_child_breadcrumbs(cards = collection_cards)
    cards.each do |card|
      next if card.link?
      if card.item.present?
        # have to reload in order to pick up new parent relationship
        card.item.reload.recalculate_breadcrumb!
      elsif card.collection_id.present?
        # this method will run the async worker if there are >50 children
        card.collection.recalculate_breadcrumb_tree!
      end
    end
  end

  def collection_cards_by_page(page: 1, per_page: CollectionCard::DEFAULT_PER_PAGE)
    all_collection_cards.page(page).per(per_page)
  end

  # If a board, it handles pagination differently
  # rows and cols params are arrays of [min, max]
  def collection_cards_by_row_and_col(rows:, cols:)
    table = CollectionCard.arel_table
    all_collection_cards.where(
      table[:row].gteq(rows[0])
      .and(
        table[:row].lteq(rows[1]),
      )
      .and(
        table[:col].gteq(cols[0]),
      )
      .and(
        table[:col].lteq(cols[1]),
      ),
    )
  end

  def collection_cards_viewable_by(
    user,
    scope: all_collection_cards,
    card_order: nil,
    hidden: false
  )
    order = { order: :asc }
    collection_order = nil
    if card_order
      if card_order == 'total' || card_order.include?('question_')
        collection_order = "collections.cached_test_scores->'#{card_order}'"
        order = "#{collection_order} DESC NULLS LAST"
      else
        # e.g. updated_at
        order = { card_order => :desc }
      end
    end

    cards = scope
            .active
            .includes(collection: [:collection_cover_items], item: [:filestack_file])
            .order(order)

    # `hidden` means include both hidden and unhidden cards
    cards = cards.visible unless hidden

    unless user.has_cached_role?(Role::SUPER_ADMIN)
      group_ids = user.current_org_group_ids
      resource_identifier_sql = %(
        CASE WHEN COALESCE(
          items.roles_anchor_collection_id,
          collections.roles_anchor_collection_id
        ) IS NOT NULL
        THEN
          CONCAT('Collection_', COALESCE(
            items.roles_anchor_collection_id,
            collections.roles_anchor_collection_id
          ))
        ELSE
          CONCAT(
            (CASE WHEN collection_cards.item_id IS NOT NULL THEN 'Item' ELSE 'Collection' END),
            '_',
            COALESCE(collection_cards.item_id, collection_cards.collection_id)
          )
        END
      )
      join_sql = %(
        LEFT JOIN items ON items.id = collection_cards.item_id
        LEFT JOIN collections ON collections.id = collection_cards.collection_id
        JOIN roles ON (
          roles.resource_identifier = #{resource_identifier_sql}
        )
        LEFT JOIN users_roles ON
        users_roles.role_id = roles.id and
        users_roles.user_id = #{user.id}
        LEFT JOIN groups_roles ON
        groups_roles.role_id = roles.id and
        groups_roles.group_id IN (#{group_ids.present? ? group_ids.join(',') : 'NULL'})
      )

      fields = ['collection_cards.*']
      fields << collection_order if collection_order.present?

      cards = cards
              .joins(join_sql)
              .select(*fields)
              .where('coalesce(users_roles.id, groups_roles.id) IS NOT NULL')
              .distinct
    end

    # precache roles because these will be referred to in the serializers (e.g. can_edit?)
    user.precache_roles_for(
      [Role::VIEWER, Role::CONTENT_EDITOR, Role::EDITOR],
      cards.map(&:record).compact,
    )

    cards
  end

  # convenience method if card order ever gets out of sync
  def reorder_cards!
    all_collection_cards.active.visible.order(pinned: :desc, order: :asc).each_with_index do |card, i|
      card.update_column(:order, i) unless card.order == i
    end
  end

  def reorder_cards_by_collection_name!
    all_collection_cards.active.visible.includes(:collection).order('collections.name ASC').each_with_index do |card, i|
      card.update_column(:order, i) unless card.order == i
    end
  end

  def unarchive_cards!(cards, card_attrs_snapshot)
    cards.each(&:unarchive!)
    CollectionUpdater.call(self, card_attrs_snapshot)
    reorder_cards!
    # if snapshot includes card attrs then CollectionUpdater will trigger the same thing
    return unless master_template? && card_attrs_snapshot[:collection_cards_attributes].blank?
    queue_update_template_instances
  end

  def enable_org_view_access_if_allowed(parent)
    # If parent is user collection, allow primary group to see it
    # As long as it isn't the 'Getting Started' collection
    return false unless parent.is_a?(Collection::UserCollection) &&
                        (cloned_from.blank? || !cloned_from.getting_started?)
    # collections created in My Collection always get unanchored
    unanchor_and_inherit_roles_from_anchor!
    organization.primary_group.add_role(Role::VIEWER, self).try(:persisted?)
  end

  def reindex_sync
    Searchkick.callbacks(true) do
      reindex
    end
  end

  def touch_related_cards
    try(:parent_collection_card).try(:touch)
    cards_linked_to_this_collection.update_all(updated_at: updated_at)
  end

  def owned_tag_list
    all_tags_list - tag_list
  end

  def cache_tag_list
    self.cached_tag_list = tag_list
  end

  def cache_owned_tag_list
    self.cached_owned_tag_list = owned_tag_list
  end

  # these all get called from CollectionUpdater
  def update_cached_tag_lists
    cache_tag_list if tag_list != cached_tag_list
    cache_owned_tag_list if owned_tag_list != cached_owned_tag_list
  end

  def display_cover?
    # overridden in some STI classes
    true
  end

  def cache_cover
    self.cached_cover = DefaultCollectionCover.call(self)
  end

  def cache_cover!
    cache_cover
    save
  end

  def cache_card_count!
    # not using the store_accessor directly here because of:
    # https://github.com/rails/rails/pull/32563
    self.cached_attributes ||= {}
    self.cached_attributes['cached_card_count'] = collection_cards.count
    # update without callbacks/timestamps
    update_column :cached_attributes, cached_attributes
  end

  def update_cover_text!(text_item)
    cached_cover['text'] = DefaultCollectionCover.cover_text(self, text_item)
    save
  end

  def org_templates?
    false
  end

  def profiles?
    false
  end

  def getting_started?
    false
  end

  def destroyable?
    # currently the only destroyable type is an incomplete SubmissionBox
    false
  end

  def cache_key(card_order = 'order')
    test_details = ''
    if test_collection?
      # make sure these details factor into caching
      test_details = "launchable=#{launchable?}&can_reopen=#{can_reopen?}"
    end

    "#{jsonapi_cache_key}" \
      "/#{ActiveRecord::Migrator.current_version}" \
      "/#{ENV['HEROKU_RELEASE_VERSION']}" \
      "/order_#{card_order}" \
      "/cards_#{collection_cards.maximum(:updated_at).to_i}" \
      "/#{test_details}" \
      "/#{getting_started_shell}" \
      "/#{organization.updated_at}" \
      "/roles_#{anchored_roles.maximum(:updated_at).to_i}"
  end

  def remove_comment_followers!
    return unless comment_thread.present?
    RemoveCommentThreadFollowers.perform_async(comment_thread.id)
  end

  def jsonapi_type_name
    'collections'
  end

  def default_card_order
    if self.class.in? [Collection::SharedWithMeCollection, Collection::SubmissionsCollection]
      # special behavior where it defaults to newest first
      return 'updated_at'
    end
    'order'
  end

  def update_processing_status(status = nil)
    update(
      processing_status: status,
    )

    processing_done if processing_status.nil?
  end

  def mark_children_processing_status(status = nil)
    # also mark self
    update_processing_status(status)
    collections = Collection.in_collection(self)
    collections.update_all(
      processing_status: status,
      updated_at: Time.now,
    )

    # Broadcast that this collection is no longer being edited
    collections.each(&:processing_done) if processing_status.nil?
  end

  def clear_collection_cover
    cover = primary_collection_cards.where(is_cover: true).first
    return if cover.nil?
    cover.update(is_cover: false)
    touch
  end

  def reset_permissions!
    all_collections = Collection.in_collection(self)
    all_items = Item.in_collection(self)
    [all_collections, all_items].each do |records|
      records.update_all(roles_anchor_collection_id: roles_anchor.id)
      records.find_each do |record|
        if record.roles.present?
          record.roles.destroy_all
        else
          record.touch
        end
      end
    end
  end

  def submit_submission!
    return unless submission?
    # have to unset this before we can call MergeToChild
    submission_attrs['hidden'] = false
    result = save
    Roles::MergeToChild.call(
      parent: parent_submission_box,
      child: self,
    )
    result
  end

  # =================================
  # Various boolean queries/checks
  # - many are related to test collections and submission_boxes
  # - could perhaps be moved into a helper module?
  # =================================
  def test_collection?
    is_a?(Collection::TestCollection) || is_a?(Collection::TestDesign)
  end

  def global_collection?
    type == 'Collection::Global'
  end

  def inside_a_master_template?
    return true if master_template?
    parents.where(master_template: true).any?
  end

  def inside_a_template_instance?
    return true if templated?
    parents.where.not(template_id: nil).any?
  end

  def parent_submission_box
    parents.find_by(type: 'Collection::SubmissionBox')
  end

  def parent_submission
    parents.find_by("cached_attributes->'submission_attrs'->>'submission' = 'true'")
  end

  def parent_submission_box_template
    @parent_submission_box_template ||= begin
      return nil unless inside_a_submission_box?
      template_id = parent_submission_box&.submission_template_id
      return nil unless template_id.present?
      parents.find_by(id: template_id)
    end
  end

  def submission_box_template?
    return false unless master_template? && inside_a_submission_box?
    id == parent_submission_box&.submission_template_id
  end

  def inside_a_submission_box_template?
    parent_submission_box_template.present?
  end

  def inside_a_submission_box?
    return true if is_a?(Collection::SubmissionBox)
    parents.where(type: 'Collection::SubmissionBox').any?
  end

  def submission_box_template_test?
    return false unless is_a?(Collection::TestCollection)
    master_template? && inside_a_submission_box_template?
  end

  def inside_hidden_submission_box?
    parent_submission_box&.hide_submissions == true
  end

  def submission?
    submission_attrs.present? && submission_attrs['submission']
  end

  def inside_a_submission?
    parents.where("cached_attributes->'submission_attrs'->>'submission' = 'true'").any?
  end

  def submission_test?
    return unless inside_a_submission?
    parent_submission.submission_attrs['launchable_test_id'] == id
  end

  # check for template instances anywhere in the entire collection tree
  def any_template_instance_children?
    Collection.in_collection(id).where.not(template_id: nil).any?
  end

  # =================================
  # <--- end boolean checks

  private

  def organization_blank?
    organization.blank?
  end

  def parent_collection_card_blank?
    parent_collection_card.blank?
  end

  def parent_collection
    # this first case should return e.g. when using CollectionCardBuilder
    return parent if parent_collection_card.present?
    # if the collection is in process of being built, parent_collection_card will always be nil
    # (currently mostly useful for specs, when we are creating models directly)
    if (primary = collection_cards.first)
      return primary.parent
    end
    nil
  end

  def inherit_parent_organization_id
    return true if organization.present?
    return true unless parent_collection.present?
    self.organization_id = parent_collection.organization_id
  end

  def update_comment_thread_in_firestore
    return unless comment_thread.present?
    return unless saved_change_to_name? || saved_change_to_cached_attributes?
    comment_thread.store_in_firestore
  end

  def pin_all_primary_cards
    primary_collection_cards.update_all(pinned: true)
  end

  def now_master_template?
    saved_change_to_master_template? && master_template?
  end
end
