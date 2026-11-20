# frozen_string_literal: true

module V1
  # The tag vocabulary (index/create/rename/recolor/merge) and tagging a person.
  class TagsController < ApplicationController
    include PersonScoped

    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_tag", title: error.message)
    end

    def index
      counts = PersonTag.group(:tag_id).count
      render json: { data: Tag.order(:normalized_name).limit(500).map { |t| serialize(t, counts[t.id] || 0) } }
    end

    def create
      with_idempotency do
        tag = Tag.new(name: tag_params.require(:name), color: tag_params[:color].presence || "#64748b")
        audited(tag, "tag.created")
        render json: serialize(tag, 0), status: :created
      end
    end

    def update
      with_idempotency do
        tag = Tag.find(params[:id])
        tag.name = tag_params[:name] if tag_params.key?(:name)
        tag.color = tag_params[:color] if tag_params.key?(:color)
        audited(tag, "tag.updated")
        render json: serialize(tag, PersonTag.where(tag_id: tag.id).count)
      end
    end

    def merge
      with_idempotency do
        source = Tag.find(params[:id])
        target = Tag.find(params.require(:into_tag_id))
        source.merge_into!(target)
        render json: serialize(target, PersonTag.where(tag_id: target.id).count)
      end
    end

    def person_index
      person = visible_person!(params[:person_id])
      tags = Tag.where(id: PersonTag.where(person_id: person.id).select(:tag_id)).order(:normalized_name)
      render json: { data: tags.map { |t| serialize(t, nil) } }
    end

    # POST /people/:person_id/tags { tag_id } or { name } (created on first use)
    def person_add
      with_idempotency do
        person = visible_person!(params[:person_id])
        tag = params[:tag_id].present? ? Tag.find(params[:tag_id]) : Tag.find_or_create_named!(params.require(:name))
        PersonTagger.add!(person: person, tag: tag)
        render json: serialize(tag, nil), status: :created
      end
    end

    def person_remove
      with_idempotency do
        person = visible_person!(params[:person_id])
        PersonTagger.remove!(person: person, tag: Tag.find(params[:id]))
        head :no_content
      end
    end

    private

    def audited(tag, action)
      ChangeWriter.call(record: tag, action: action, event_type: action, payload: { "name" => tag.name })
    rescue ActiveRecord::RecordInvalid => e
      raise ArgumentError, e.record.errors.full_messages.to_sentence
    end

    def tag_params
      params.require(:tag).permit(:name, :color)
    end

    def serialize(tag, count)
      tag.as_json(only: %i[id name color created_at updated_at]).merge("person_count" => count)
    end

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end
  end
end
