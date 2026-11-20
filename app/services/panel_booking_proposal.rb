# frozen_string_literal: true

# A short-lived, signed snapshot of exactly the interview the recruiter reviewed.
# The token binds attendees, calendar, duration, application, stage, and actor.
class PanelBookingProposal
  def self.suggest(application:, **input)
    raise ArgumentError, "application_not_active" unless application.status == "active"
    plan = Array(application.pipeline.resolved_stages).find { |stage| stage["key"] == application.current_stage_key }
    keys = Array(plan&.fetch("interviews", [])).map { |definition| definition["key"] }
    defs = input.fetch(:interview_defs)
    valid_defs = defs.present? && defs.all? do |definition|
      keys.include?(definition[:key]) && definition[:duration_minutes].between?(15, 480) &&
        definition[:count].between?(1, 10) && definition[:candidate_user_ids].present?
    end
    unless valid_defs
      raise ArgumentError, "invalid_interview_plan"
    end
    unless input[:search_start] && input[:search_end] && input[:search_end] > input[:search_start] && input[:search_end] - input[:search_start] <= 14.days
      raise ArgumentError, "invalid_search_window"
    end
    input[:search_start] = [ input[:search_start], Time.current ].max
    return [] if input[:search_end] <= input[:search_start]

    PanelBooking.new(application: application, **input).suggest.map do |option|
      selected = PanelBooking.serialize_option(option)
      token = verifier.generate(
        { application_id: application.id, stage_key: application.current_stage_key,
          pipeline_version: application.pipeline.version,
          actor_id: Current.actor_id,
          input: input.merge(search_start: input[:search_start].iso8601, search_end: input[:search_end].iso8601),
          selected: selected }, expires_in: 10.minutes
      )
      selected.merge("token" => token)
    end
  end

  def self.confirm!(application:, token:)
    payload = verifier.verified(token)&.deep_symbolize_keys
    unless payload && payload[:application_id] == application.id && payload[:actor_id] == Current.actor_id
      raise ArgumentError, "proposal_expired"
    end

    application.with_lock do
      unless application.status == "active" && payload[:stage_key] == application.current_stage_key &&
             payload[:pipeline_version] == application.pipeline.reload.version
        raise ArgumentError, "application_changed"
      end
      input = payload.fetch(:input)
      input[:search_start] = Time.iso8601(input[:search_start])
      input[:search_end] = Time.iso8601(input[:search_end])
      input[:user_emails] = input[:user_emails].stringify_keys
      raise ArgumentError, "slot_unavailable" if Time.iso8601(payload.dig(:selected, :starts_at)) <= Time.current
      PanelBooking.new(application: application, **input)
                  .book_selected!(payload.fetch(:selected).deep_stringify_keys)
    end
  end

  def self.verifier
    Rails.application.message_verifier("panel_booking_proposal")
  end
  private_class_method :verifier
end
