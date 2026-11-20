module V1
  class PostingsController < ApplicationController
    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_posting", title: error.message)
    end

    def index
      job = ResourceVisibility.jobs.find(params[:job_id])
      render json: { data: job.postings.order(:created_at, :id).map { |posting| serialize(posting) }, application_form: ApplicationFormSettings.as_json(ApplicationFormSettings.payload(Organization.find(Current.organization_id), public_form: true)) }
    end

    def create
      with_idempotency do
        job = ResourceVisibility.jobs.find(params[:job_id])
        Job.transaction do
          job.lock!
          posting = job.postings.build(title: params.dig(:posting, :title), audience: params.dig(:posting, :audience) || job.careers_visibility)
          assign(posting)
          ChangeWriter.call(record: posting, action: "posting.created", event_type: "posting.created")
          render json: serialize(posting), status: :created
        end
      end
    end

    def update
      posting = Posting.find(params[:id])
      Job.transaction do
        posting.job.lock!
        posting.lock!
        expected = params.dig(:posting, :expected_version)
        if expected && expected.to_i != posting.version
          return render_problem(status: :conflict, code: "stale_version", title: "The posting changed. Reload before saving.")
        end
        assign(posting)
        posting.version += 1
        ChangeWriter.call(record: posting, action: "posting.updated", event_type: "posting.updated")
        render json: serialize(posting)
      end
    end

    private

    def assign(posting)
      posting.assign_attributes(params.require(:posting).permit(:title, :audience, :status, :description, :location, :employment_type).to_h)
      raw = params[:posting]
      posting.questions = PostingQuestions.normalize(raw[:questions]) if raw.key?(:questions)
      return unless raw.key?(:question_template_id)
      if raw[:question_template_id].blank?
        posting.assign_attributes(question_template: nil, template_questions: [], template_version: nil)
      else
        template = ApplicationQuestionTemplate.find(raw[:question_template_id])
        raise ArgumentError, "This template is archived" unless template.status == "active"
        posting.assign_attributes(question_template: template, template_questions: template.questions.deep_dup, template_version: template.version)
      end
    end

    def serialize(posting)
      posting.as_json(only: %i[id job_id title description location employment_type audience status questions template_questions question_template_id template_version version]).merge(
        "application_form" => ApplicationFormSettings.for_posting(Organization.find(Current.organization_id), posting)
      )
    end
  end
end
