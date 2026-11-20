# frozen_string_literal: true

module CalendarClient
  class << self
    attr_accessor :backend

    def free_busy(user_ids:, time_min:, time_max:)
      return user_ids.index_with { [] } if DemoSandbox.for_organization(Current.organization_id)
      (backend || Null).free_busy(user_ids: user_ids, time_min: time_min, time_max: time_max)
    end

    def create_event!(organizer_calendar:, starts_at:, ends_at:, attendee_emails:, summary:)
      return { id: "demo_evt_#{SecureRandom.uuid}", captured: true } if DemoSandbox.for_organization(Current.organization_id)
      (backend || Null).create_event!(
        organizer_calendar: organizer_calendar, starts_at: starts_at, ends_at: ends_at,
        attendee_emails: attendee_emails, summary: summary
      )
    end

    def create_event_with_live_check!(organizer_calendar:, starts_at:, ends_at:, interviewer_user_ids:, summary:, user_emails:)
      if DemoSandbox.for_organization(Current.organization_id)
        return { id: "demo_evt_#{SecureRandom.uuid}", captured: true }
      end
      raise ArgumentError, "calendar_not_connected" unless backend

      backend.create_event_with_live_check!(
        organizer_calendar: organizer_calendar, starts_at: starts_at, ends_at: ends_at,
        interviewer_user_ids: interviewer_user_ids, summary: summary, user_emails: user_emails
      )
    end

    def delete_event!(event_id:)
      return true if DemoSandbox.for_organization(Current.organization_id)
      (backend || Null).delete_event!(event_id: event_id)
    end
  end

  module Null
    module_function

    def free_busy(**) = {}
    def create_event!(**) = raise("CalendarClient backend not configured")
    def delete_event!(**) = raise("CalendarClient backend not configured")
  end

  class Fake
    attr_reader :events, :busy

    def initialize
      @events = []
      @busy = Hash.new { |h, k| h[k] = [] }
      @seq = 0
    end

    def set_busy(user_id, ranges)
      @busy[user_id] = ranges
    end

    def free_busy(user_ids:, time_min:, time_max:)
      user_ids.index_with do |uid|
        @busy[uid].select { |a, b| a < time_max && b > time_min }
      end
    end

    def create_event!(organizer_calendar:, starts_at:, ends_at:, attendee_emails:, summary:)
      # Live re-check: refuse if any attendee now busy
      attendee_emails.each do |email|
        uid = email # tests use user id as email local-part mapping via callers
      end
      @seq += 1
      event = {
        id: "evt_#{@seq}", organizer_calendar: organizer_calendar,
        starts_at: starts_at, ends_at: ends_at, attendees: attendee_emails, summary: summary
      }
      @events << event
      event
    end

    def create_event_with_live_check!(organizer_calendar:, starts_at:, ends_at:, interviewer_user_ids:, summary:, user_emails:)
      busy = free_busy(user_ids: interviewer_user_ids, time_min: starts_at, time_max: ends_at)
      conflict = interviewer_user_ids.find { |uid| busy[uid].any? { |a, b| a < ends_at && b > starts_at } }
      raise StaleSlot, conflict if conflict

      create_event!(
        organizer_calendar: organizer_calendar,
        starts_at: starts_at,
        ends_at: ends_at,
        attendee_emails: interviewer_user_ids.map { |id| user_emails.fetch(id) },
        summary: summary
      )
    end

    def delete_event!(event_id:)
      @events.reject! { |e| e[:id] == event_id }
      true
    end
  end

  class StaleSlot < StandardError
    attr_reader :user_id

    def initialize(user_id)
      @user_id = user_id
      super("slot_stale:#{user_id}")
    end
  end
end
