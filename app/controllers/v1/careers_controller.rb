# frozen_string_literal: true

module V1
  class CareersController < ApplicationController
    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_application", title: error.message)
    end

    rescue_from CustomFieldDefinitions::Error do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_application", title: error.message)
    end

    # Public careers page payload by org slug — includes configurable hero photo,
    # the application form, and enough job data to apply (posting id, openings).
    def public_show
      org = Organization.find_by!(slug: params[:slug])
      Current.organization_id = org.id
      render_careers(org, "public")
    end

    def internal_show
      require_employee!
      render_careers(Organization.find(Current.organization_id), "internal")
    end

    def internal_apply
      require_employee!
      posting = Posting.find(request.path_parameters[:posting_id])
      raise ActiveRecord::RecordNotFound unless [ "internal", "both" ].include?(posting.audience) && posting.job.status == "active" && !posting.job.confidential?

      result = CareersApplication.submit!(
        organization: Organization.find(Current.organization_id), posting: posting,
        audience: "internal", answers: params[:answers],
        extras: params.permit(:phone, :linkedin, :links, :country, :region).to_h.merge(
          "display_name" => current_principal.user.name,
          "email" => current_principal.user.email
        )
      )
      render json: result, status: :created
    end

    # Path posting id wins. A body posting_id cannot retarget the application.
    def public_apply
      org = Organization.find_by!(slug: params[:slug])
      block_demo_public_write!(org.id, action: "apply")
      Current.organization_id = org.id
      posting = Posting.find(request.path_parameters[:posting_id])
      raise ActiveRecord::RecordNotFound unless [ "public", "both" ].include?(posting.audience) && posting.job.status == "active" && !posting.job.confidential?
      result = CareersApplication.submit!(
        organization: org,
        posting: posting,
        answers: params[:answers],
        extras: params.permit(:display_name, :email, :phone, :linkedin, :links, :country, :region).to_h
      )
      render json: result, status: :created
    end

    private

    def require_employee!
      response.set_header("Cache-Control", "private, no-store")
      response.set_header("X-Robots-Tag", "noindex, nofollow")
      unless current_principal&.membership&.status == "active" && current_principal.agent.nil?
        raise Authenticator::Forbidden.new("employee_required", "Sign in as an active member of this organization.")
      end
    end

    def render_careers(org, audience)
      jobs = Job.on_careers(audience).includes(:postings).order(:title).limit(100).to_a
      labels = dimension_labels(jobs)
      render json: {
        "organization" => {
          "id" => org.id,
          "name" => org.name,
          "slug" => org.slug
        },
        "careers" => {
          "hero_image_url" => org.careers_hero_image_url,
          "headline" => org.careers_headline,
          "subcopy" => org.careers_subcopy,
          "culture" => culture_blocks(org),
          "about" => org.careers_section("about"),
          "culture_intro" => org.careers_section("culture"),
          "accent_color" => org.careers_accent_color,
          "demo" => Rails.configuration.x.demo_sign_in,
          "accepts_applications" => !DemoSandbox.for_organization(org.id) || Rails.configuration.x.demo_candidate_writes
        },
        "application_form" => ApplicationFormSettings.as_json(
          ApplicationFormSettings.payload(org, public_form: true)
        ),
        "jobs" => jobs.flat_map { |job|
          job.postings.select { |posting| posting.visible_to?(audience) }.map { |posting| serialize_job(job, posting, org, labels[job.id] || {}) }
        }
      }
    end


    def culture_blocks(org)
      blocks = org.setting("careers_culture")
      return blocks if blocks.is_a?(Array) && blocks.any?

      [
        { "title" => "How we work", "body" => "Small teams, clear ownership, and a hiring loop you can see." },
        { "title" => "How we hire", "body" => "A conversation, a work sample, and a decision with the people you would work with." }
      ]
    end

    def serialize_job(job, posting, org, labels)
      job.as_json(only: %i[id title status pipeline_id openings created_at]).merge(
        "posting_id" => posting.id,
        "title" => posting.title,
        "job_title" => job.title,
        "application_form" => ApplicationFormSettings.for_posting(org, posting),
        "department" => labels["department"],
        "location" => posting.location.presence || labels["location"],
        "employment_type" => posting.employment_type,
        "description" => posting.description
      )
    end

    def dimension_labels(jobs)
      return {} if jobs.empty?

      EntityDimensionValue.where(entity_type: "Job", entity_id: jobs.map(&:id))
                          .includes(:dimension, :dimension_value)
                          .each_with_object({}) do |row, out|
        out[row.entity_id] ||= {}
        out[row.entity_id][row.dimension.key] = row.dimension_value.label
      end
    end
  end
end
