require 'rails_helper'

RSpec.describe DataReport::QuestionItem, type: :service do
  let(:organization) { create(:organization) }
  let(:collection) { create(:collection, organization: organization) }

  context 'no responses' do
    let(:empty_dataset) do
      [
        { column: 1, value: 0, percentage: 0 },
        { column: 2, value: 0, percentage: 0 },
        { column: 3, value: 0, percentage: 0 },
        { column: 4, value: 0, percentage: 0 },
      ]
    end
    let(:question_item) { create(:question_item) }
    let(:dataset) { create(:question_dataset, data_source: question_item) }

    describe '#call' do
      it 'returns datasets for question item' do
        expect(DataReport::QuestionItem.call(dataset: dataset)).to match_array(empty_dataset)
      end
    end
  end

  context 'with responses' do
    let!(:test_collection) { create(:test_collection, :completed, num_cards: 1, organization: organization) }
    before { test_collection.launch! }
    # Create another test collection so we have other responses in the org
    let(:other_test_collection) do
      create(:test_collection,
             :with_responses,
             num_responses: 5,
             organization: organization)
    end
    let!(:survey_response) { create(:survey_response, test_collection: test_collection) }
    let!(:question_item) { survey_response.question_items.select(&:question_useful?).first }
    let!(:question_answers) do
      survey_response.question_items.map do |question_item|
        create(:question_answer,
               survey_response: survey_response,
               question: question_item)
      end
    end

    before do
      other_test_collection.reload
    end

    context 'question dataset' do
      let!(:dataset) do
        create(:question_dataset, data_source: question_item)
      end

      describe '#call' do
        it 'returns data for question' do
          expect(DataReport::QuestionItem.call(dataset: dataset)).to match_array(
            [
              { column: 1, value: 1, percentage: 100 },
              { column: 2, value: 0, percentage: 0 },
              { column: 3, value: 0, percentage: 0 },
              { column: 4, value: 0, percentage: 0 },
            ],
          )
        end
      end

      describe '#total' do
        it 'returns 1' do
          expect(
            DataReport::QuestionItem.new(dataset: dataset).total,
          ).to eq(1)
        end
      end
    end

    context 'filtering by org' do
      let!(:dataset) do
        create(:org_wide_question_dataset,
               question_type: question_item.question_type,
               groupings: [{ type: 'Organization', id: organization.id }])
      end

      describe '#call' do
        it 'returns org-wide data' do
          expect(DataReport::QuestionItem.call(dataset: dataset)).to match_array(
            [
              { column: 1, value: 7, percentage: 100 },
              { column: 2, value: 0, percentage: 0 },
              { column: 3, value: 0, percentage: 0 },
              { column: 4, value: 0, percentage: 0 },
            ],
          )
        end
      end

      describe '#total' do
        it 'returns 7' do
          expect(
            DataReport::QuestionItem.new(dataset: dataset).total,
          ).to eq(7)
        end
      end
    end

    context 'filtering by test audience' do
      let!(:audience) { create(:audience, organization: organization) }
      let!(:test_audience) { create(:test_audience, audience: audience, test_collection: test_collection) }
      let!(:survey_response) { create(:survey_response, test_collection: test_collection, test_audience: test_audience) }
      let!(:question_item) { survey_response.question_items.select(&:question_useful?).first }
      let!(:dataset) do
        create(:question_dataset,
               data_source: question_item,
               question_type: question_item.question_type,
               groupings: [{ type: 'TestAudience', id: test_audience.id }])
      end
      let!(:question_answers) do
        survey_response.question_items.map do |question_item|
          create(:question_answer,
                 survey_response: survey_response,
                 question: question_item)
        end
      end

      it 'returns test audience data' do
        expect(DataReport::QuestionItem.call(dataset: dataset)).to match_array(
          [
            { column: 1, value: 1, percentage: 100 },
            { column: 2, value: 0, percentage: 0 },
            { column: 3, value: 0, percentage: 0 },
            { column: 4, value: 0, percentage: 0 },
          ],
        )
      end
    end
  end
end
