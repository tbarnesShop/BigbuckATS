# frozen_string_literal: true

module V1
  # Public, token-authenticated. GET shows who is unsubscribing; POST records the opt-out.
  # POST is also the RFC 8058 one-click target named in the List-Unsubscribe header.
  class UnsubscribeController < ApplicationController
    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_unsubscribe", title: error.message)
    end

    def show
      person = UnsubscribeToken.verify(params[:token])
      Current.organization_id = person.organization_id
      render json: {
        "organization" => { "name" => Organization.find(person.organization_id).name },
        "email_hint" => mask(person.primary_email),
        "already_unsubscribed" => person.do_not_contact || OptOut.blocked?(person.primary_email)
      }
    end

    def create
      person = UnsubscribeToken.verify(params[:token])
      Current.organization_id = person.organization_id
      block_demo_public_write!(person.organization_id, action: "unsubscribe")
      Current.set(actor_type: "system", source_surface: "unsubscribe_link") do
        OptOut.add!(person: person, source: "unsubscribe_link")
      end
      render json: { "unsubscribed" => true }
    end

    private

    def mask(email)
      local, domain = email.to_s.split("@", 2)
      return "" if domain.blank?

      "#{local[0]}***@#{domain}"
    end
  end
end
