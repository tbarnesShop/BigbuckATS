# frozen_string_literal: true

module Mutations
  class ConnectCalendar < BaseMutation
    description "Connect a user or domain calendar. Stays pending until a real grant; unverified domains are refused."
    permission "interview.schedule"

    argument :calendar_id, String, required: true
    argument :kind, String, required: false, description: "user (default) or domain. Domain needs settings.manage."
    argument :user_id, ID, required: false, description: "Defaults to the caller. Another user needs settings.manage."
    argument :secret_ref, String, required: false, description: "Real grant. sm://demo stays pending."

    field :calendar, Types::ConnectedCalendarType, null: true, connection: false

    def resolve(calendar_id:, kind: nil, user_id: nil, secret_ref: nil)
      connection = CalendarConnector.connect!(
        calendar_id: calendar_id, kind: kind, user_id: user_id, secret_ref: secret_ref,
        actor_id: principal.user_id,
        allow_domain: principal.can?("settings.manage"),
        allow_other_user: principal.can?("settings.manage")
      )
      { calendar: connection, user_errors: [] }
    rescue Authorization::InsufficientPermission => e
      { calendar: nil, user_errors: [ user_error("insufficient_permission", e.message, path: [ "kind" ]) ] }
    rescue GoogleSignIn::DomainNotVerified => e
      { calendar: nil, user_errors: [ user_error("unverified_domain",
                                                 "Domain #{e.message} is not verified for this organization",
                                                 path: [ "calendarId" ]) ] }
    rescue ArgumentError => e
      { calendar: nil, user_errors: [ user_error("invalid_calendar", e.message) ] }
    rescue ActiveRecord::RecordInvalid => e
      { calendar: nil, user_errors: [ user_error("validation_failed", e.record.errors.full_messages.join(", ")) ] }
    end
  end
end
