FactoryBot.define do
  factory :item do
    transient do
      parent_collection nil
      add_editors []
      add_viewers []
    end

    name { Faker::Food.dish }

    factory :text_item, class: 'Item::TextItem' do
      content { Faker::BackToTheFuture.quote }
      data_content { { ops: [{ insert: 'Hola, world.' }] } }
    end

    factory :link_item, class: 'Item::LinkItem' do
      content { Faker::BackToTheFuture.quote }
      url { Faker::Internet.url('example.com') }
    end

    factory :file_item, class: 'Item::FileItem' do
      name nil # name gets generated by filestack_file
      filestack_file
    end

    factory :pdf_file_item, class: 'Item::FileItem' do
      name nil # name gets generated by filestack_file
      filestack_file factory: :filestack_pdf_file
    end

    factory :video_item, class: 'Item::VideoItem' do
      url 'https://www.youtube.com/watch?v=igJ4qADrSwo'
      thumbnail_url { Faker::Company.logo }
      name '80s Best Dance Hits'
    end

    factory :question_item, class: 'Item::QuestionItem' do
      question_type :question_useful
    end

    factory :chart_item, class: 'Item::ChartItem' do
      trait :with_question_item do
        data_source factory: :question_item
      end
      trait :with_remote_url do
        url 'https://creativedifference.ideo.com/api/v4/quality_scores'
      end
    end

    factory :data_item, class: 'Item::DataItem' do
      trait :report_type_collections_and_items do
        report_type :report_type_collections_and_items
        data_settings { { d_measure: 'participants', d_timeframe: 'ever' } }
      end

      trait :report_type_network_app_metric do
        report_type :report_type_network_app_metric
        url 'https://profile.ideo.com/api/v1/app_metrics'
      end

      trait :report_type_record do
        data_content(
          datasets: [
            {
              measure: 'IDEO',
              single_value: 0,
              order: 0,
              data: [{ date: '2018-10-03', amount: 80 }],
            },
            {
              measure: 'All Organizations',
              single_value: 0,
              order: 1,
              data: [{ date: '2018-11-13', amount: 24 }],
            },
          ],
        )
        report_type :report_type_record
      end
    end

    factory :legend_item, class: 'Item::LegendItem'

    after(:build) do |item, evaluator|
      if evaluator.parent_collection
        item.parent_collection_card = build(
          :collection_card,
          parent: evaluator.parent_collection,
          order: evaluator.parent_collection.collection_cards.count,
          width: 1,
          height: 1,
        )
      end
    end

    after(:create) do |item, evaluator|
      if evaluator.add_editors.present?
        item.unanchor_and_inherit_roles_from_anchor!
        evaluator.add_editors.each do |user|
          user.add_role(Role::EDITOR, item.becomes(Item))
        end
      end

      if evaluator.add_viewers.present?
        item.unanchor_and_inherit_roles_from_anchor!
        evaluator.add_viewers.each do |user|
          user.add_role(Role::VIEWER, item.becomes(Item))
        end
      end
    end
  end
end
