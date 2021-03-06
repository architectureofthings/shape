require 'rails_helper'

describe Collection, type: :model do
  context 'validations' do
    it { should validate_presence_of(:organization).with_message('must exist') }
    it { should validate_presence_of(:name) }
    it 'does not validate presence of :name if not base_collection_type' do
      expect(Collection::UserCollection.new).not_to validate_presence_of(:name)
    end
  end

  context 'associations' do
    it { should have_many :collection_cards }
    it { should have_many :primary_collection_cards }
    it { should have_many :link_collection_cards }
    it { should have_many :cards_linked_to_this_collection }
    it { should have_many :items }
    it { should have_many :collections }
    it { should have_one :parent_collection_card }
    it { should belong_to :cloned_from }
    it { should belong_to :organization }
    it { should belong_to :template }
    it { should belong_to :joinable_group }
    # these come from Testable concern
    it { should have_many :test_collections }
    it { should have_one :live_test_collection }
    # from Commentable
    it { should have_many :comment_threads }

    describe '#collection_cards' do
      let!(:collection) { create(:collection, num_cards: 3) }
      let(:collection_cards) { collection.collection_cards }

      it 'should find collection cards in order of order: :asc' do
        expect(collection_cards.sort_by(&:order)).to match_array(collection_cards)
      end

      it 'should only find active collection cards' do
        expect do
          collection_cards.first.archive!
        end.to change(collection.collection_cards, :count).by(-1)
      end

      describe '#touch_related_cards' do
        let!(:collection) { create(:collection) }
        let!(:card_linked_to_this_collection) { create(:collection_card_link, collection: collection) }

        it 'should update linked cards if updated_at changed' do
          expect do
            collection.update(updated_at: Time.now) && card_linked_to_this_collection.reload
          end.to change(card_linked_to_this_collection, :updated_at)
        end
        it 'should update linked cards after update' do
          expect do
            collection.update(name: 'Bobo') && card_linked_to_this_collection.reload
          end.to change(card_linked_to_this_collection, :updated_at)
        end
      end
    end

    describe '.build_ideas_collection' do
      it 'returns unpersisted collection with one ideas card' do
        collection = Collection.build_ideas_collection
        cards = collection.primary_collection_cards
        expect(collection.new_record?).to be true
        expect(collection.name).to eq('Ideas')
        expect(cards.size).to eq(1)
        expect(cards.first.item.question_type).to eq('question_idea')
      end
    end

    describe '#collection_cover_cards' do
      let!(:collection) { create(:collection, num_cards: 3) }
      let(:collection_cards) { collection.collection_cards }

      it 'should return [] if no cards are covers' do
        expect(collection_cards.all? { |card| !card.is_cover? }).to be true
        expect(collection.collection_cover_cards).to be_empty
      end

      it 'returns no collection_cover_items' do
        expect(collection.collection_cover_items).to be_empty
      end

      context 'with one card marked as cover' do
        let(:cover_card) { collection_cards.first }
        before { cover_card.update(is_cover: true) }

        it 'is returned' do
          expect(collection.collection_cover_cards).to eq([cover_card])
        end

        it 'collection_cover_items returns card item' do
          expect(collection.collection_cover_items).to eq([cover_card.item])
        end
      end
    end

    describe '#destroy' do
      let(:user) { create(:user) }
      let!(:collection) { create(:collection, num_cards: 3, add_editors: [user]) }
      let(:items) { collection.items }
      let(:collection_cards) { collection.collection_cards }

      it 'should destroy all related cards and items' do
        expect(collection.roles.count).to eq 1
        expect(items.count).to eq 3
        expect(collection_cards.count).to eq 3
        collection.destroy
        expect(collection.roles.count).to eq 0
        expect(items.count).to eq 0
        expect(collection_cards.count).to eq 0
      end
    end
  end

  describe 'callbacks' do
    describe '#pin_all_primary_cards' do
      let!(:collection) { create(:collection, num_cards: 3) }

      it 'pins cards if master_template = true' do
        expect(collection.primary_collection_cards.any?(&:pinned?)).to be false
        collection.update(master_template: true)
        expect(collection.reload.primary_collection_cards.all?(&:pinned?)).to be true
      end
    end

    describe '#add_joinable_guest_group' do
      let(:organization) { create(:organization) }
      let!(:collection) { create(:collection, organization: organization) }
      let(:guest_group) { collection.organization.guest_group }

      it 'sets the org guest group as the joinable_group when anyone_can_join is set to true' do
        expect(collection.can_view?(guest_group)).to be false
        collection.update(anyone_can_join: true)
        guest_group.reset_cached_roles!
        # adds group as viewer
        expect(collection.can_view?(guest_group)).to be true
        # sets the joinable group
        expect(collection.joinable_group_id).to eq guest_group.id
      end
    end

    describe '#submission_template_test_collections' do
      let(:organization) { create(:organization) }
      let!(:submission_box) { create(:submission_box) }
      let!(:template) { create(:collection, master_template: true, parent_collection: submission_box) }
      let!(:test_collection) { create(:test_collection, parent_collection: template) }

      before do
        submission_box.update(submission_template_id: template.id)
        submission_box.reload
      end

      it 'should submission template test collections with test_audiences' do
        expect(template.submission_template_test_collections).to include(test_collection)
      end
    end

    describe '#rename_challenge_groups' do
      let(:admin_group) { create(:group, name: 'Collection Admins') }
      let(:reviewer_group) { create(:group, name: 'Collection Reviewers') }
      let(:participant_group) { create(:group, name: 'Collection Participants') }
      let!(:collection) {
        create(:collection,
               name: 'Collection',
               collection_type: 'challenge',
               challenge_admin_group_id: admin_group.id,
               challenge_reviewer_group_id: reviewer_group.id,
               challenge_participant_group_id: participant_group.id)
      }

      it 'should create a challenge admin group, participant group, and reviewer group' do
        expect(collection.challenge_admin_group.name).to eq 'Collection Admins'
        expect(collection.challenge_reviewer_group.name).to eq 'Collection Reviewers'
        expect(collection.challenge_participant_group.name).to eq 'Collection Participants'
        collection.update(name: 'Challenge')
        expect(collection.challenge_admin_group.name).to eq 'Challenge Admins'
        expect(collection.challenge_reviewer_group.name).to eq 'Challenge Reviewers'
        expect(collection.challenge_participant_group.name).to eq 'Challenge Participants'
      end
    end
  end

  describe '#inherit_parent_organization_id' do
    let!(:parent_collection) { create(:user_collection) }
    let!(:collection_card) { create(:collection_card, parent: parent_collection) }
    let!(:collection) { create(:collection, name: 'New Collection', organization: nil, parent_collection_card: collection_card) }

    it 'inherits organization id from parent collection' do
      expect(collection.organization_id).to eq(parent_collection.organization_id)
    end
  end

  describe '#enable_org_view_access_if_allowed' do
    let!(:organization) { create(:organization) }
    let(:parent_collection) { create(:collection, organization: organization) }
    let(:collection) { create(:collection, organization: organization, parent_collection: parent_collection) }

    context 'if parent is user collection' do
      let(:parent_collection) do
        create(:user_collection, organization: organization)
      end

      it 'does give view access' do
        expect(collection.enable_org_view_access_if_allowed).to be true
        expect(organization.primary_group.has_role?(Role::VIEWER, collection)).to be true
      end

      context 'if cloned from Getting Started collection' do
        let!(:getting_started_template_collection) do
          create(:getting_started_template_collection,
                 organization: organization)
        end
        before do
          organization.reload
          collection.update_attributes(
            cloned_from: getting_started_template_collection,
          )
        end

        it 'does not give view access' do
          expect(organization.getting_started_collection).to eq(getting_started_template_collection)
          expect(collection.enable_org_view_access_if_allowed).to be false
          expect(organization.primary_group.has_role?(Role::VIEWER, collection)).to be false
        end
      end
    end

    context 'if cloned from a parent of a Getting Started collection' do
      let!(:getting_started_template_collection) do
        create(:getting_started_template_collection,
               organization: organization)
      end
      let(:cloned) { create(:collection, organization: organization, parent_collection: getting_started_template_collection) }

      before do
        organization.reload
        collection.update_attributes(
          cloned_from: cloned,
        )
      end

      it 'does not give view access' do
        expect(organization.getting_started_collection).to eq(getting_started_template_collection)
        expect(collection.enable_org_view_access_if_allowed).to be false
        expect(organization.primary_group.has_role?(Role::VIEWER, collection)).to be false
      end
    end

    context 'if parent is not user collection' do
      let(:parent_collection) { create(:collection, organization: organization) }

      it 'does not give view access to its organization\'s primary group' do
        expect(collection.enable_org_view_access_if_allowed).to be false
        expect(organization.primary_group.has_role?(Role::VIEWER, collection)).to be false
      end
    end

    describe '#reindex_sync' do
      let(:collection) { create(:collection) }

      before do
        allow(Searchkick).to receive(:callbacks).and_call_original
      end

      it 'should get called on create' do
        expect(Searchkick).to receive(:callbacks).with(true)
        collection.save
      end

      it 'should get called after archive' do
        # once on create, second for archive
        expect(Searchkick).to receive(:callbacks).with(true).twice
        collection.archive!
      end
    end
  end

  describe '#duplicate!' do
    let!(:user) { create(:user) }
    let!(:parent_collection_user) { create(:user) }
    let!(:collection_user) { create(:user) }
    let(:organization) { create(:organization) }
    let!(:parent_collection) { create(:collection, organization: organization) }
    let!(:collection) do
      create(:collection, num_cards: 3, tag_list: %w[Prototype Other], organization: organization)
    end
    let!(:parent_collection_card) do
      create(:collection_card_collection, parent: parent_collection, collection: collection)
    end
    let(:copy_parent_card) { false }
    let(:parent) { collection.parent }
    let(:batch_id) { "duplicate-#{SecureRandom.hex(10)}" }
    let(:card) { nil }
    let(:building_template_instance) { false }
    let(:duplicate) do
      dupe = collection.duplicate!(
        for_user: user,
        copy_parent_card: copy_parent_card,
        parent: parent,
        batch_id: batch_id,
        card: card,
        building_template_instance: building_template_instance,
      )
      # Necessary because AR-relationship is cached
      user.roles.reload
      user.reset_cached_roles!
      dupe
    end

    it 'does not duplicate if no flag passed' do
      expect(duplicate.parent_collection_card).to be_nil
    end

    context 'with archived collection' do
      let!(:collection) { create(:collection, num_cards: 3, archived: true, tag_list: %w[Prototype Other]) }

      it 'creates a duplicate that is not archived' do
        expect(collection.archived?).to be true
        expect(duplicate.archived?).to be false
      end
    end

    context 'enabling org view access' do
      let(:copy_parent_card) { true }

      it 'should not share with the org by default' do
        expect(organization.primary_group.has_role?(Role::VIEWER, duplicate)).to be false
      end

      context 'duplicating into a user_collection' do
        let!(:parent_collection) { create(:user_collection, organization: organization) }

        it 'should share with the org' do
          expect(organization.primary_group.has_role?(Role::VIEWER, duplicate)).to be true
        end
      end
    end

    context 'with shared_with_organization' do
      before do
        collection.update(shared_with_organization: true)
      end

      it 'nullifies shared_with_organization' do
        expect(collection.shared_with_organization?).to be true
        expect(duplicate.shared_with_organization?).to be false
      end
    end

    context 'without user' do
      let(:duplicate_without_user) do
        dupe = collection.duplicate!(
          copy_parent_card: true,
          parent: parent,
          batch_id: batch_id,
        )
        user.roles.reload
        user.reset_cached_roles!
        dupe
      end

      it 'clones the collection' do
        expect { duplicate_without_user }.to change(Collection, :count).by(1)
      end

      it 'clones all the collection cards' do
        expect(CollectionCardDuplicationWorker).to receive(:perform_async).with(
          batch_id,
          collection.collection_cards.map(&:id),
          instance_of(Integer),
          nil, # <-- nil user_id
          false,
          false,
          false,
        )
        duplicate_without_user
      end

      it 'clones all roles from parent collection - but not user' do
        expect(duplicate_without_user.editors[:users].map(&:email)).to match(
          parent.editors[:users].map(&:email),
        )
        expect(duplicate_without_user.can_edit?(user)).to be false
      end
    end

    context 'with copy_parent_card true' do
      let!(:copy_parent_card) { true }

      it 'creates duplicate with parent_collection as its parent' do
        expect(duplicate.id).not_to eq(collection.id)
        expect(duplicate.parent).to eq parent_collection
      end

      it 'creates duplicate with organization_id matching parent' do
        expect(duplicate.organization_id).to eq parent_collection.organization_id
      end
    end

    context 'with editor role' do
      before do
        user.add_role(Role::EDITOR, parent)
        user.add_role(Role::EDITOR, collection)
        parent_collection_user.add_role(Role::EDITOR, parent)
        collection_user.add_role(Role::EDITOR, collection)
        collection.items.each do |item|
          user.add_role(Role::EDITOR, item)
        end
        collection.reload
      end

      it 'clones the collection' do
        expect { duplicate }.to change(Collection, :count).by(1)
        expect(collection.id).not_to eq(duplicate.id)
      end

      it 'references the current collection as cloned_from' do
        expect(duplicate.cloned_from).to eq(collection)
      end

      it 'clones all the collection cards' do
        expect(CollectionCardDuplicationWorker).to receive(:perform_async).with(
          batch_id,
          collection.collection_cards.map(&:id),
          instance_of(Integer),
          user.id,
          false,
          false,
          false,
        )
        collection.duplicate!(
          for_user: user,
          batch_id: batch_id,
        )
      end

      it 'clones all roles from parent collection' do
        expect(duplicate.editors[:users].map(&:email)).to match(parent.editors[:users].map(&:email))
        expect(duplicate.can_edit?(user)).to be true
      end

      it 'clones all roles on items' do
        expect(duplicate.items.all? { |item| item.can_edit?(user) }).to be true
      end

      it 'clones tag list' do
        expect(duplicate.tag_list).to match_array collection.tag_list
      end
    end

    context 'with system_collection and synchronous settings' do
      let(:instance_double) do
        double('CollectionCardDuplicationWorker')
      end

      before do
        allow(CollectionCardDuplicationWorker).to receive(:new).and_return(instance_double)
        allow(instance_double).to receive(:perform).and_return true
      end

      it 'should call synchronously' do
        expect(CollectionCardDuplicationWorker).to receive(:new)
        expect(instance_double).to receive(:perform).with(
          batch_id,
          anything,
          anything,
          anything,
          true,
          true,
          false,
        )
        collection.duplicate!(
          batch_id: batch_id,
          for_user: user,
          system_collection: true,
          synchronous: true,
        )
      end
    end

    context 'with building_template_instance' do
      let(:building_template_instance) { true }
      before do
        collection.update(master_template: true)
      end

      it 'should set the template to itself, and set master_template = false' do
        expect(duplicate.template).to eq collection
        expect(duplicate.master_template?).to be false
      end

      it 'should pass building_template_instance to the worker' do
        expect(CollectionCardDuplicationWorker).to receive(:perform_async).with(
          batch_id,
          collection.collection_cards.map(&:id),
          instance_of(Integer),
          user.id,
          false,
          false,
          true, # <-- building_template_instance
        )
        duplicate
      end
    end

    context 'with a challenge' do
      let(:collection) { create(:collection, :challenge) }

      it 'sets up the duplicate challenge properly' do
        allow(CollectionChallengeSetup).to receive(:call)
        # should preserve type
        expect(duplicate.collection_type_challenge?).to be true
        expect(CollectionChallengeSetup).to have_received(:call).with(
          collection: duplicate, user: user,
        )
      end
    end

    context 'with a subcollection inside the system-generated getting started collection' do
      let(:parent_collection) { create(:global_collection, organization: organization) }
      let!(:subcollection) { create(:collection, num_cards: 2, parent_collection: collection, organization: organization) }
      let(:duplicate) do
        collection.duplicate!(
          for_user: user,
          copy_parent_card: copy_parent_card,
          parent: parent,
          system_collection: true,
          synchronous: true,
        )
      end
      let(:shell_collection) { duplicate.collections.first }

      before do
        organization.update(getting_started_collection: parent_collection)
        duplicate
      end

      it 'should mark the duplicate child collection as a getting_started_shell' do
        expect(shell_collection.getting_started_shell).to be true
      end

      it 'should not create any collection cards in the child collection' do
        expect(shell_collection.cloned_from).to eq subcollection
        expect(shell_collection.cloned_from.collection_cards.count).to eq 2
        expect(shell_collection.collection_cards.count).to eq 0
      end
    end

    context 'with external records' do
      let!(:external_records) do
        [
          create(:external_record, externalizable: collection, external_id: '100'),
          create(:external_record, externalizable: collection, external_id: '101'),
        ]
      end

      it 'duplicates external records' do
        expect(collection.external_records.reload.size).to eq(2)
        expect do
          duplicate
        end.to change(ExternalRecord, :count).by(2)

        expect(duplicate.external_records.pluck(:external_id)).to match_array(
          %w[100 101],
        )
      end
    end

    context 'with submission_attrs' do
      let!(:collection) { create(:collection, :submission) }

      it 'clears out submission_attrs' do
        expect(collection.submission?).to be true
        expect(duplicate.submission?).to be false
      end
    end

    context 'with passed in card' do
      let(:card) { create(:collection_card) }

      it 'sets the specified card as the parent' do
        expect(duplicate.parent_collection_card).to eq card
      end
    end

    context 'with collection filters' do
      let!(:collection_filter) { create(:collection_filter, collection: collection) }

      it 'copies all filters' do
        expect do
          duplicate
        end.to change(CollectionFilter, :count).by(1)
        expect(duplicate.collection_filters.first.text).to eq(collection_filter.text)
      end
    end
  end

  describe '#copy_all_cards_into!' do
    let(:source_collection) { create(:collection, num_cards: 3) }
    let(:target_collection) { create(:collection) }
    let(:first_record) { source_collection.collection_cards.first.record }

    it 'copies all cards from source to target, at the beginning' do
      expect {
        source_collection.copy_all_cards_into!(
          target_collection,
          synchronous: true,
        )
        target_collection.reload
      }.to change(target_collection.collection_cards, :count).by(3)
      expect(target_collection.collection_cards.first.record.cloned_from).to eq first_record
    end

    context 'with links' do
      let(:fake_parent) { create(:collection) }
      let(:target_collection) { create(:collection, num_cards: 2) }
      let(:source_collection) { create(:collection, num_cards: 3, record_type: :link_text, card_relation: :link) }
      before do
        # all these cards' linked records need corresponding parent_collection_cards for duplication
        source_collection.link_collection_cards.each do |cc|
          create(:collection_card, item: cc.record, parent: fake_parent)
        end
      end

      it 'preserves links as links and does not convert them into primary cards' do
        source_collection.copy_all_cards_into!(target_collection, synchronous: true)
        target_collection.reload
        expect(target_collection.collection_cards.count).to eq 5
        expect(target_collection.link_collection_cards.count).to eq 3
        expect(target_collection.link_collection_cards.first.record).to eq first_record
      end
    end
  end

  describe '#all_tag_names' do
    let!(:collection) { create(:collection, num_cards: 3) }
    let(:cards) { collection.collection_cards }

    it 'should be empty by default' do
      expect(collection.all_tag_names).to match_array []
    end

    it 'should gather collection tags' do
      collection.update(tag_list: ['this', 'interstellar space dust'])
      expect(collection.reload.all_tag_names).to match_array ['this', 'interstellar space dust']
    end

    it 'should gather collection + item tags' do
      collection.update(tag_list: %w[this that])
      cards.first.item.update(tag_list: %w[other stuff])
      cards[1].item.update(tag_list: %w[more things])
      expect(collection.reload.all_tag_names).to match_array %w[this that other stuff more things]
    end
  end

  describe '#collection_cards_by_page' do
    let!(:collection) { create(:collection, num_cards: 3, record_type: :collection) }

    it 'returns cards on page' do
      expect(collection.collection_cards_by_page(page: 2, per_page: 1)).to eq(
        [collection.collection_cards[1]],
      )
    end
  end

  describe '#collection_cards_by_row_and_col' do
    let!(:collection) { create(:collection, num_cards: 4, record_type: :collection) }
    let(:collection_cards) { collection.collection_cards }
    let!(:matching_cards) do
      collection_cards[0].update(row: 3, col: 5)
      collection_cards[1].update(row: 6, col: 5)
      [
        collection_cards[0],
        collection_cards[1],
      ]
    end
    let!(:non_matching_cards) do
      collection_cards[2].update(row: 2, col: 5)
      collection_cards[3].update(row: 11, col: 5)
    end

    it 'returns cards matching row and col' do
      expect(
        collection.collection_cards_by_row_and_col(
          rows: [3, 10],
          cols: [4, 6],
        ),
      ).to match_array(matching_cards)
    end
  end

  describe '#search_data' do
    let(:parent_collection) { nil }
    let(:collection) { create(:collection, parent_collection: parent_collection) }
    let(:users) { create_list(:user, 2) }
    let(:groups) { create_list(:group, 2) }

    before do
      users[0].add_role(Role::EDITOR, collection)
      users[1].add_role(Role::VIEWER, collection)
      groups[0].add_role(Role::EDITOR, collection)
      groups[1].add_role(Role::VIEWER, collection)
    end

    it 'includes all user_ids' do
      expect(collection.search_data[:user_ids]).to match_array(users.map(&:id))
    end

    it 'includes all group_ids' do
      expect(collection.search_data[:group_ids]).to match_array(groups.map(&:id))
    end

    it 'sets activity date to nil when no activity' do
      expect(collection.search_data[:activity_dates]).to be nil
    end

    it 'includes activity dates, without duplicates' do
      organization = create(:organization)
      user = create(:user)
      activity1 = collection.activities.create(actor: user, organization: organization)
      collection.activities.create(actor: user, organization: organization)
      activity3 = collection.activities.create(actor: user, organization: organization, updated_at: 1.week.from_now)
      expected_activity_dates = [activity1.updated_at.to_date, activity3.updated_at.to_date]
      expect(collection.search_data[:activity_dates]).to match_array(expected_activity_dates)
    end

    context 'with parent collection' do
      let!(:parent_collection) { create(:collection) }

      it 'includes parent collections' do
        expect(collection.search_data[:parent_ids]).to eq([parent_collection.id])
      end
    end
  end

  describe '#unarchive_cards!' do
    let(:collection) { create(:collection, num_cards: 3) }
    let(:cards) { collection.all_collection_cards }
    let(:first_card) { cards.first }
    let(:snapshot) do
      {
        collection_cards_attributes: [
          { id: first_card.id, row: 3, col: 1, width: 2, height: 1 },
        ],
      }
    end

    before do
      collection.archive!
      expect(cards.first.archived?).to be true
    end

    it 'unarchives all cards' do
      expect do
        collection.unarchive_cards!(cards, snapshot)
      end.to change(collection.collection_cards, :count).by(3)
      expect(first_card.reload.active?).to be true
    end

    it 'applies snapshot to revert the state' do
      expect(first_card.width).to eq 1 # default
      collection.unarchive_cards!(cards, snapshot)
      first_card.reload
      # pick up new attrs
      expect(first_card.width).to eq 2
      expect(first_card.row).to eq 3
      expect(first_card.col).to eq 1
    end

    context 'with a board collection and collision' do
      let(:collection) { create(:board_collection, num_cards: 3) }
      let(:cards) { collection.all_collection_cards.first(3) }
      let(:overlap_card) { create(:collection_card_text, parent: collection, row: 1, col: 1) }
      let(:snapshot) do
        {
          collection_cards_attributes: [
            { id: first_card.id, row: 1, col: 1 },
          ],
        }
      end

      before do
        first_card.update(row: 1, col: 1)
      end

      it 'calls the BoardPlacement service to place cards with collision detection' do
        allow(CollectionGrid::BoardPlacement).to receive(:call).and_call_original
        top_left_card = CollectionGrid::Calculator.top_left_card(cards)
        expect(CollectionGrid::BoardPlacement).to receive(:call).with(
          moving_cards: cards,
          to_collection: collection,
          row: top_left_card.row,
          col: top_left_card.col,
        )
        # create overlap card
        overlap_card
        collection.unarchive_cards!(cards, snapshot)
        # pick up new attrs
        first_card.reload
        expect(first_card.active?).to be true
        # should have bumped it out of the way by 1
        expect(first_card.col).to eq 2
      end
    end

    context 'with a board collection and no snapshot' do
      let(:collection) { create(:board_collection, num_cards: 3) }
      let(:cards) { collection.all_collection_cards.first(3) }
      let(:snapshot) { nil }

      before do
        cards.last.update(row: nil, col: nil)
      end

      it 'calls the BoardPlacement service to place cards with collision detection' do
        allow(CollectionGrid::BoardPlacement).to receive(:call).and_call_original
        expect(CollectionGrid::BoardPlacement).to receive(:call).with(
          moving_cards: cards,
          to_collection: collection,
          row: 0,
          col: 0,
        )
        collection.unarchive_cards!(cards, snapshot)
        # pick up new attrs
        first_card.reload
        expect(first_card.active?).to be true
        expect(first_card.row).to eq 0
        expect(collection.reload.collection_cards.pluck(:row, :col)).to eq([
          [0, 0],
          [0, 1],
          [0, 2],
        ])
      end
    end

    context 'with a master template and existing instances' do
      let!(:instance) { create(:collection, template: collection) }
      before do
        collection.update(master_template: true)
      end

      it 'calls queue_update_template_instances' do
        expect(UpdateTemplateInstancesWorker).to receive(:perform_async)
        collection.unarchive_cards!(cards, snapshot)
      end
    end

    context 'with a master_template' do
      let(:collection) { create(:collection, master_template: true, num_cards: 3) }

      context 'with a template instance' do
        let!(:instance) { create(:collection, template: collection) }

        it 'should call the UpdateTemplateInstancesWorker' do
          expect(UpdateTemplateInstancesWorker).to receive(:perform_async).with(
            collection.id,
            cards.pluck(:id),
            :unarchive,
          )
          collection.unarchive_cards!(cards, snapshot)
        end
      end

      context 'without a template instance' do
        it 'should not call the UpdateTemplateInstancesWorker' do
          expect(UpdateTemplateInstancesWorker).not_to receive(:perform_async)
          collection.unarchive_cards!(cards, snapshot)
        end
      end
    end
  end

  describe '#reset_permissions!' do
    let(:user) { create(:user) }
    let(:collection) { create(:collection, num_cards: 1, add_editors: [user]) }
    let!(:subcollection) { create(:collection, parent_collection: collection, add_viewers: [user]) }

    it 'resets all sub-items and collections to be anchored to the parent' do
      expect(subcollection.roles).not_to be_empty
      collection.reset_permissions!
      # update_all doesn't automatically reload the models so we need to
      collection.items.first.reload
      subcollection.reload
      expect(collection.items.first.roles_anchor_collection_id).to eq collection.id
      expect(collection.items.first.can_edit?(user)).to be true
      expect(subcollection.roles).to be_empty
      expect(subcollection.roles_anchor_collection_id).to eq collection.id
      expect(subcollection.can_edit?(user)).to be true
    end
  end

  describe '#submit_submission' do
    let(:submission_box) { create(:submission_box) }
    before { submission_box.setup_submissions_collection! }
    let(:submission) { create(:collection, :submission, parent_collection: submission_box.submissions_collection) }
    before do
      submission.submission_attrs['hidden'] = true
      submission.save
    end

    it 'should unset the hidden attribute and merge roles from the SubmissionBox' do
      expect(Roles::MergeToChild).to receive(:call).with(
        parent: submission_box,
        child: submission,
      )
      submission.submit_submission!
      expect(submission.submission_attrs['hidden']).to be false
    end
  end

  context 'challenge with submission' do
    let(:user) { create(:user) }
    let!(:parent_challenge) do
      create(
        :collection,
        num_cards: 1,
        record_type: :collection,
        add_viewers: [user],
        collection_type: :challenge,
      )
    end
    let(:submission_box) { create(:submission_box, :with_submissions_collection, parent_collection: parent_challenge) }
    let(:submission_template) { create(:collection, master_template: true, parent_collection: submission_box) }
    # Take a shortcut - just create test collection to be used directly in submission
    let!(:test_collection) do
      create(:test_collection, :completed, parent_collection: submission_template)
    end
    let!(:submission) { create(:collection, :submission, parent_collection: submission_box.submissions_collection) }
    let(:reviewer) { create(:user, handle: 'test_user') }
    before do
      submission.update(submission_attrs: { submission: true, launchable_test_id: test_collection.id })
    end

    describe '#submission_reviewer_status' do
      context 'if not a submission' do
        before do
          submission.update(submission_attrs: {})
        end

        it 'returns nil' do
          expect(submission.submission?).to be false
          expect(submission.submission_reviewer_status(reviewer)).to be_nil
        end
      end

      context 'if user is not assigned as a reviewer' do
        it 'returns unstarted' do
          expect(submission.submission_reviewer_status(reviewer)).to eq(:unstarted)
        end
      end

      context 'if user is assigned as a reviewer' do
        before do
          submission.update(user_tag_list: [reviewer.handle])
          submission.add_challenge_reviewer_filter_to_submission_box(reviewer)
        end

        it 'returns :unstarted if no survey responses' do
          expect(submission.submission_reviewer_status(reviewer)).to eq(:unstarted)
        end

        context 'with an incomplete survey response' do
          let!(:survey_response) { create(:survey_response, test_collection: test_collection, user: reviewer) }

          it 'returns :in_progress' do
            expect(submission.submission_reviewer_status(reviewer)).to eq(:in_progress)
          end
        end

        context 'with a complete survey response' do
          let!(:survey_response) { create(:survey_response, :fully_answered, test_collection: test_collection, user: reviewer) }

          it 'returns :completed' do
            expect(submission.submission_reviewer_status(reviewer)).to eq(:completed)
          end
        end
      end
    end

    describe '#add_challenge_reviewer_filter_to_submission_box' do
      it 'adds collection filter with user handle' do
        expect do
          submission.add_challenge_reviewer_filter_to_submission_box(reviewer)
        end.to change(CollectionFilter.user_tag, :count).by(1)
      end

      it 'creates user collection filter for user so they are selected' do
        expect do
          submission.add_challenge_reviewer_filter_to_submission_box(reviewer)
        end.to change(UserCollectionFilter, :count).by(1)
        collection_filter = submission_box.submissions_collection.collection_filters.last
        expect(
          collection_filter.user_collection_filters.find_by(user_id: reviewer.id),
        ).not_to be_nil
      end
    end

    describe '#remove_challenge_reviewer_filter_from_submission_box' do
      before do
        submission.add_challenge_reviewer_filter_to_submission_box(reviewer)
      end

      it 'destroys collection filter with user handle' do
        collection_filter_id = submission_box.submissions_collection.collection_filters.last.id
        expect do
          submission.remove_challenge_reviewer_filter_from_submission_box(reviewer)
        end.to change(CollectionFilter.user_tag, :count).by(-1)
        expect(CollectionFilter.exists?(collection_filter_id)).to be false
      end
    end

    describe '#challenge_test_audience_for_user' do
      let!(:master_test) do
        create(:test_collection, :with_reviewers_audience, parent_collection: submission_template, master_template: true)
      end
      let!(:test_collection) do
        create(:test_collection, :completed, parent_collection: submission_template, template_id: master_test.id)
      end
      let(:reviewer_group) { create(:group, name: 'Collection Reviewers') }
      before do
        parent_challenge.update(challenge_reviewer_group: reviewer_group)
        reviewer.add_role(Role::MEMBER, parent_challenge.challenge_reviewer_group)
      end

      it 'should lookup reviewer audience' do
        test_audience = test_collection.test_audiences
                                       .joins(:audience)
                                       .find_by(audiences: { name: 'Reviewers' })

        expect(submission.challenge_test_audience_for_user(reviewer)).to eq(test_audience)
        # these should be equivalent
        expect(test_collection.challenge_test_audience_for_user(reviewer)).to eq(test_audience)
      end
    end
  end

  describe 'child of a master template' do
    let(:parent) { create(:collection, master_template: true) }
    let(:child) { create(:collection, parent_collection: parent) }

    it 'should have a child_of_a_master_template = true' do
      expect(child.child_of_a_master_template?).to be true
    end
  end

  describe 'subtemplate instance' do
    let(:parent) { create(:collection, master_template: true) }
    let(:child) { create(:collection, master_template: true, parent_collection: parent) }
    let(:instance_of_parent) { create(:collection, template_id: parent.id) }
    let(:instance_of_child) { create(:collection, template_id: child.id) }

    it 'direct template instance should not be a subtemplate instance' do
      expect(instance_of_parent.templated?).to be true
      expect(parent.subtemplate?).to be false
      expect(instance_of_parent.subtemplate_instance?).to be false
    end

    it 'template instance of child should be a subtemplate instance' do
      expect(instance_of_child.templated?).to be true
      expect(child.subtemplate?).to be true
      expect(instance_of_child.subtemplate_instance?).to be true
    end
  end

  # describe '#card_order_at' do
  #   let!(:collection) { create(:collection, num_cards: 3) }
  #
  #   it 'should convert "beginning/end" into the correct order' do
  #     expect(collection.card_order_at('beginning')).to eq 0
  #     expect(collection.card_order_at('end')).to eq 3
  #   end
  #
  #   it 'should return the order if it\'s an integer' do
  #     expect(collection.card_order_at(2)).to eq 2
  #   end
  # end

  describe '#unreviewed_by?' do
    let(:user) { create(:user) }
    let(:submission) { create(:collection, :submission) }
    let(:in_a_reviewer_group_with_audience) { true }

    describe 'when reviewer has a completed response' do
      let(:test_collection) { create(:test_collection, :completed) }
      let(:survey_response) { create(:survey_response, :fully_answered, test_collection: test_collection, user: user) }

      before do
        submission.update(submission_attrs: { submission: true, launchable_test_id: test_collection.id })
      end

      it 'should be false' do
        survey_response.reload
        expect(submission.unreviewed_by?(user, in_a_reviewer_group_with_audience)).to eq(false)
      end
    end

    describe 'when user is a reviewer without an audience' do
      let!(:in_a_reviewer_group_with_audience) { false }

      it 'should be false' do
        expect(submission.unreviewed_by?(user, in_a_reviewer_group_with_audience)).to eq(false)
      end
    end

    describe 'when user is a reviewer with an audience' do
      let!(:user) { create(:user) }
      let(:parent_challenge) { create(:collection, collection_type: 'challenge') }
      let!(:submission) { create(:collection, :submission, parent_collection: parent_challenge) }

      describe 'when user is a member of the participant group' do
        let(:participant_group) { create(:group, add_members: [user]) }

        before do
          parent_challenge.update(challenge_participant_group: participant_group)
        end

        it 'should be true when user belongs to a non-reviewer, ie: participant group' do
          expect(submission.unreviewed_by?(user, in_a_reviewer_group_with_audience)).to eq(true)
        end
      end

      describe 'when user is a member of the reviewer group' do
        let(:reviewer_group) { create(:group, add_members: [user]) }

        before do
          parent_challenge.update(challenge_reviewer_group: reviewer_group)
        end

        it 'should be false when the user is untagged' do
          expect(submission.unreviewed_by?(user, in_a_reviewer_group_with_audience)).to eq(false)
        end

        it 'should be true when the user is tagged' do
          submission.update(user_tag_list: [user.handle])
          submission.reload
          expect(submission.unreviewed_by?(user, in_a_reviewer_group_with_audience)).to eq(true)
        end
      end
    end
  end

  # Caching methods
  context 'caching and stored attributes' do
    describe '#cache_key' do
      let(:user) { create(:user) }
      let(:collection) { create(:collection, num_cards: 2) }
      let(:first_card) { collection.collection_cards.first }

      it 'updates based on the collection updated_at timestamp' do
        expect do
          collection.update(updated_at: 10.seconds.from_now)
        end.to change(collection, :cache_key)
      end

      it 'updates when roles are updated' do
        expect do
          # this should "touch" the role updated_at
          user.add_role(Role::EDITOR, collection)
        end.to change(collection, :cache_key)
      end

      it 'updates when cards are updated' do
        expect do
          first_card.update(updated_at: 10.seconds.from_now)
        end.to change(collection, :cache_key)
      end

      it 'updates based on user_id' do
        logged_out_key = collection.cache_key('order', nil)
        logged_in_key = collection.cache_key('order', user.id)
        expect(logged_out_key).not_to eq logged_in_key
      end
    end

    describe '#cache_tag_list' do
      let(:tag_list) { %w[testing prototyping] }
      let(:collection) { create(:collection, tag_list: tag_list) }

      it 'caches tag_list onto cached_attributes' do
        expect(collection.cached_tag_list).to be nil
        collection.cache_tag_list
        expect(collection.cached_tag_list).to match_array(tag_list)
      end
    end

    describe '#cache_cover' do
      let(:collection) { create(:collection, num_cards: 3) }
      let!(:image_card) { create(:collection_card_image, parent: collection) }

      it 'caches cover onto cached_attributes' do
        expect(collection.cached_cover).to be nil
        collection.cache_cover
        expect(collection.cached_cover['text']).not_to be nil
        expect(collection.cached_cover['image_url']).not_to be nil
      end
    end

    describe '#update_cover_text!' do
      let(:collection) { create(:collection, num_cards: 3) }
      let(:item) { collection.collection_cards.first.item }

      before do
        collection.cache_cover!
      end

      it 'updates cached cover text to match item updates' do
        item.data_content = { ops: [{ insert: 'Howdy doody.' }] }
        collection.update_cover_text!(item)
        expect(collection.cached_cover['text']).to eq 'Howdy doody.'
      end
    end

    describe '#cache_card_count!' do
      let(:collection) { create(:collection, num_cards: 3) }

      it 'should calculate and not clobber other cached attrs' do
        expect(collection.cached_cover).to be nil
        collection.cache_cover!
        collection.cache_card_count!
        expect(collection.cached_card_count).to eq 3
        expect(collection.cached_cover).not_to be nil
        # create a different model reference
        c1 = Collection.find(collection.id)
        c1.update(submission_attrs: { submission: true })
        # it won't be stored here until we reload at the end
        expect(collection.submission?).to be false
        collection.cache_card_count!
        expect(collection.reload.submission?).to be true
      end
    end
    # <- end Caching methods
  end

  context 'with a subcollection that\'s inside a challenge' do
    let(:parent_collection) { create(:collection, collection_type: 'challenge') }
    let!(:subcollection) { create(:collection, num_cards: 2, parent_collection: parent_collection) }
    let!(:inner_subcollection) { create(:collection, num_cards: 2, parent_collection: subcollection) }

    it 'the collection inside the subcollection should have a reference to its parent challenge' do
      expect(inner_subcollection.parent_challenge).to eq parent_collection
    end
  end
end
