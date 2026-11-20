# frozen_string_literal: true

# Resumes sequence enrollments whose wait step is over.
class AdvanceSequencesJob < ApplicationJob
  queue_as :sequences

  def perform(limit: 200)
    SequenceRunner.tick!(limit: limit)
  end
end
