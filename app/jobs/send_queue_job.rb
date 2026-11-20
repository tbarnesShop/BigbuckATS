# frozen_string_literal: true

class SendQueueJob < ApplicationJob
  queue_as :sequences

  def perform
    SendQueue.tick!
  end
end
