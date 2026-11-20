# frozen_string_literal: true

# Daily: snapshots yesterday's outreach funnel for every organization.
class OutreachSnapshotJob < ApplicationJob
  queue_as :maintenance

  def perform(day: Date.current - 1)
    Organization.find_each do |org|
      Current.set(organization_id: org.id, actor_type: "system", source_surface: "automation") do
        OutreachSnapshotter.call(day: day)
      end
    end
  end
end
