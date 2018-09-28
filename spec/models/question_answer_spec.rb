require 'rails_helper'

RSpec.describe QuestionAnswer, type: :model do
  context 'associations' do
    it { should belong_to(:survey_response) }
    it { should belong_to(:question) }
  end

  describe 'callbacks' do
    let!(:survey_response) { create(:survey_response) }
    let(:question) { survey_response.question_items.first }
    let(:question_answer) do
      build(:question_answer,
            survey_response: survey_response,
            question: question)
    end

    describe '#update_survey_response' do
      it 'on save, calls question_answer_created_or_destroyed' do
        expect(survey_response).to receive(:question_answer_created_or_destroyed)
        question_answer.save
      end

      it 'on destroy, calls question_answer_created_or_destroyed' do
        expect(survey_response).to receive(:question_answer_created_or_destroyed).twice
        question_answer.save
        question_answer.destroy
      end
    end

    describe '#update_open_response_item' do
      let(:user) { create(:user) }

      before do
        survey_response.question_items.each do |question|
          question.update(
            question_type: Item::QuestionItem.question_types[:type_open],
          )
        end
        survey_response
          .test_collection
          .launch_test!(initiated_by: user)
      end

      it 'does not create open response item' do
        expect {
          question_answer.save
        }.not_to change(Item::TextItem, :count)
      end

      context 'completed response' do
        let!(:question_answers) do
          survey_response.question_items.map do |question|
            create(:question_answer,
                   survey_response: survey_response,
                   question: question)
          end
        end
        let!(:question_answer) { question_answers.sample }

        before do
          expect(survey_response.reload.completed?).to be true
        end

        it 'creates open response item if it does not exist' do
          expect(question_answer.open_response_item).to exist
        end

        it 'updates open response item with updated answer' do
          expect(question_answer.open_response_item.plain_content).not_to eq(
            'What a jolly prototype',
          )
          question_answer.update(
            answer_text: 'What a jolly prototype',
          )
          question_answer.open_response_item.reload.plain_content.to eq(
            'What a jolly prototype',
          )
        end
      end

      describe '#destroy_open_response_item_and_card' do
        it 'destroys open response item' do
          item = question_answer.open_response_item
          expect(item).to exist
          question_answer.destroy
          expect(item).not_to exist
        end
      end
    end
  end
end
