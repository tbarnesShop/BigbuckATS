module V1
  class ApplicationQuestionTemplatesController < ApplicationController
    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_question_template", title: error.message)
    end

    def index
      render json: { data: ApplicationQuestionTemplate.includes(:owner).order(:name).limit(100).map { |template| serialize(template) } }
    end

    def create
      with_idempotency do
        owner_id = current_principal&.user_id || Current.actor_id
        raise Authenticator::Forbidden.new("template_owner_required", "A template needs an active human owner.") unless owner_id && Membership.exists?(user_id: owner_id, status: "active")
        template = ApplicationQuestionTemplate.new(owner_user_id: owner_id, name: params.dig(:question_template, :name), questions: [])
        assign(template)
        ChangeWriter.call(record: template, action: "question_template.created", event_type: "question_template.created")
        render json: serialize(template), status: :created
      end
    end

    def update
      template = ApplicationQuestionTemplate.find(params[:id])
      unless can_edit?(template)
        raise Authenticator::Forbidden.new("template_owner_required", "Only the template owner or a settings administrator can edit it.")
      end
      template.with_lock do
        expected = params.dig(:question_template, :expected_version)
        if expected && expected.to_i != template.version
          return render_problem(status: :conflict, code: "stale_version", title: "The template changed. Reload before saving.")
        end
        assign(template)
        template.version += 1
        ChangeWriter.call(record: template, action: "question_template.updated", event_type: "question_template.updated")
        render json: serialize(template)
      end
    end

    private

    def can_edit?(template)
      template.owner_user_id == (current_principal&.user_id || Current.actor_id) || permitted?("settings.manage")
    end

    def assign(template)
      raw = params.require(:question_template)
      template.assign_attributes(raw.permit(:name, :status).to_h)
      template.questions = PostingQuestions.normalize(raw[:questions]) if raw.key?(:questions)
    end

    def serialize(template)
      template.as_json(only: %i[id owner_user_id name status version questions]).merge("owner_name" => template.owner.name, "can_edit" => can_edit?(template))
    end
  end
end
