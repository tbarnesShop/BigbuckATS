# frozen_string_literal: true

# Sends an approved offer: generates the letter, opens a click-to-accept request.
class OfferSender
  Result = Struct.new(:offer, :signature_request, :token, :document, keyword_init: true)

  def self.call(offer:, template:, to_email:, expires_at: nil, actor_id: Current.actor_id)
    new(offer: offer, template: template, to_email: to_email, expires_at: expires_at, actor_id: actor_id).call
  end

  def initialize(offer:, template:, to_email:, expires_at:, actor_id:)
    @offer = offer
    @template = template
    @to_email = to_email
    @expires_at = expires_at
    @actor_id = actor_id
  end

  def call
    raise ArgumentError, "not_approved" unless @offer.status == "approved"

    version = @offer.current_version
    expires = @expires_at || (@template.expires_after_days.days.from_now)

    ActiveRecord::Base.transaction do
      document = LetterGenerator.call(offer: @offer, template: @template)
      request = SignatureRequest.create!(
        offer_version: version,
        provider: "click_to_accept",
        sent_to_email: @to_email,
        status: "sent",
        expires_at: expires
      )
      version.update!(sent_at: Time.current, expires_at: expires)
      @offer.update!(status: "sent", version: @offer.version + 1)
      ChangeWriter.call(
        record: @offer,
        action: "offer.sent",
        event_type: "offer.sent",
        payload: { "signature_request_id" => request.id, "to" => @to_email },
        changes: { "status" => %w[approved sent] }
      )
      Result.new(
        offer: @offer,
        signature_request: request,
        token: SignatureRequestToken.issue(request),
        document: document
      )
    end
  end
end
