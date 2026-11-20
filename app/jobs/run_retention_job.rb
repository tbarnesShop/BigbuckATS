# frozen_string_literal: true

# Nightly retention: anonymize, delete or queue review per the matching policy.
class RunRetentionJob < ApplicationJob
  queue_as :maintenance

  def perform
    RetentionSweep.call
  end
end
