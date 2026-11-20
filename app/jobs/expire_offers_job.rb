# frozen_string_literal: true

class ExpireOffersJob < ApplicationJob
  queue_as :maintenance

  def perform
    OfferExpirer.call
  end
end
