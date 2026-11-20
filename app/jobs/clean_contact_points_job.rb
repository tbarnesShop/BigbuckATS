# frozen_string_literal: true

# Re-derives contact point keys after a normalization rule changes, and opens
# merge suggestions for people who now share an email or phone.
class CleanContactPointsJob < ApplicationJob
  queue_as :maintenance

  def perform(organization_id = nil)
    ContactPointCleaner.call(organization_ids: organization_id && [ organization_id ])
  end
end
