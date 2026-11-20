# frozen_string_literal: true

module V1
  class NotesController < ApplicationController
    include PersonScoped

    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_note", title: error.message)
    end

    def index
      person = visible_person!(params[:person_id])
      rows = PersonNote.where(person_id: person.id).order(pinned: :desc, created_at: :desc).limit(200)
      render json: { data: serialize_all(rows) }
    end

    def create
      with_idempotency do
        person = visible_person!(params[:person_id])
        note = PersonNote.new(person: person, body: note_params[:body].to_s, pinned: truthy(note_params[:pinned]),
          author_user_id: Current.actor_id.presence, agent_id: Current.agent_id.presence)
        write(note, "note.created", person)
        render json: serialize_all([ note ]).first, status: :created
      end
    end

    def update
      with_idempotency do
        note = PersonNote.find(params[:id])
        person = visible_person!(note.person_id)
        note.body = note_params[:body] if note_params.key?(:body)
        note.pinned = truthy(note_params[:pinned]) if note_params.key?(:pinned)
        write(note, "note.updated", person)
        render json: serialize_all([ note ]).first
      end
    end

    def destroy
      with_idempotency do
        note = PersonNote.find(params[:id])
        visible_person!(note.person_id)
        raise ArgumentError, "only_the_author_can_delete" unless note.author_user_id.blank? || note.author_user_id == Current.actor_id

        note.destroy!
        head :no_content
      end
    end

    private

    def write(note, event, person)
      ActiveRecord::Base.transaction do
        outcome = ChangeWriter.call(
          record: note, action: event, event_type: event,
          payload: { "person_id" => person.id, "note_id" => note.id, "pinned" => note.pinned },
          changes: { "pinned" => [ note.pinned_before_last_save, note.pinned ] }.compact
        )
        TimelineProjector.call(outbox_event: outcome.outbox_event)
      end
    end

    def truthy(value) = ActiveModel::Type::Boolean.new.cast(value) || false

    def note_params
      params.require(:note).permit(:body, :pinned)
    end

    def serialize_all(rows)
      users = User.where(id: rows.filter_map(&:author_user_id)).index_by(&:id)
      rows.map do |note|
        note.as_json(only: %i[id person_id body pinned author_user_id agent_id created_at updated_at])
            .merge("author" => users[note.author_user_id]&.as_json(only: %i[id name]))
      end
    end

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end
  end
end
