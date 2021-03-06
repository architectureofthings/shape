class Api::V1::QuestionAnswersController < Api::V1::BaseController
  deserializable_resource :question_answer, class: DeserializableQuestionAnswer, only: %i[create update]
  skip_before_action :check_api_authentication!
  before_action :load_survey_response

  before_action :build_question_answer, only: %i[create]
  def create
    if @question_answer.save
      render jsonapi: @question_answer
    else
      render_api_errors @question_answer.errors
    end
  end

  load_resource :question_answer, only: %i[update]
  def update
    if @question_answer.update(question_answer_params)
      render jsonapi: @question_answer
    else
      render_api_errors @question_answer.errors
    end
  end

  private

  def question_answer_params
    params.require(:question_answer).permit(
      :answer_text,
      :answer_number,
      :question_id,
      :idea_id,
      selected_choice_ids: [],
    )
  end

  def question_answer_update_params
    params.require(:question_answer).permit(
      :answer_text,
      :answer_number,
      selected_choice_ids: [],
    )
  end

  def load_survey_response
    @survey_response = SurveyResponse.find_by_session_uid(params[:survey_response_id])
    accepting_answers = @survey_response.present? && @survey_response.test_collection.still_accepting_answers?
    return if accepting_answers

    @survey_response.errors.add(:base, 'no longer accepting answers')
    render_api_errors @survey_response.errors
  end

  def build_question_answer
    @question_answer = @survey_response.question_answers.build(question_answer_params)
  end
end
