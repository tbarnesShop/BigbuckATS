# frozen_string_literal: true

# Reminds interviewers whose scorecards are overdue (2 hours after the
# interview, then daily for two weeks).
class ScorecardNudgeJob < ApplicationJob
  queue_as :maintenance

  def perform(as_of: Time.current)
    Organization.find_each do |org|
      Current.set(organization_id: org.id, actor_type: "system", source_surface: "automation") do
        ScorecardNudge.due(as_of: as_of).each do |due|
          Notifier.notify(kind: "scorecard_due", user_id: due[:user_id], organization_id: org.id,
                          data: { interview_id: due[:interview_id], ends_at: due[:ends_at] })
        end
      end
    end
  end
end
