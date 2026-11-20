# frozen_string_literal: true

module Sources
  # Each application's next scheduled interview (one query for a whole board).
  class UpcomingInterviews < GraphQL::Dataloader::Source
    def fetch(application_ids)
      rows = Interview.where(application_id: application_ids.uniq, status: "scheduled")
                      .where("starts_at >= ?", Time.current.beginning_of_day)
                      .order(:starts_at).to_a.group_by(&:application_id)
      application_ids.map { |id| rows[id]&.first }
    end
  end
end
