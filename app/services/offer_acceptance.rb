# frozen_string_literal: true

# Candidate accept/decline via signed token, or recruiter-recorded response.
class OfferAcceptance
  Result = Struct.new(:offer, :response, :hired, keyword_init: true)

  def self.accept!(token:, ip_address:, user_agent:, typed_name: nil)
    new(token: token).accept!(ip_address: ip_address, user_agent: user_agent, typed_name: typed_name)
  end

  def self.decline!(token:, reason_key: nil, ip_address: nil, user_agent: nil)
    new(token: token).decline!(reason_key: reason_key, ip_address: ip_address, user_agent: user_agent)
  end

  def self.record!(offer:, response:, actor_id:, note: nil, reason_key: nil)
    new(offer: offer, actor_id: actor_id).record!(response: response, note: note, reason_key: reason_key)
  end

  def initialize(token: nil, offer: nil, actor_id: nil)
    @token = token
    @offer = offer
    @actor_id = actor_id
  end

  def accept!(ip_address:, user_agent:, typed_name:)
    request = SignatureRequestToken.verify(@token)
    Current.organization_id ||= request.organization_id
    version = request.offer_version
    offer = version.offer
    raise ArgumentError, "not_sent" unless offer.status == "sent"

    letter = version.offer_documents.find_by!(kind: "letter")
    hired = false
    response = nil
    ActiveRecord::Base.transaction do
      response = OfferResponse.create!(
        offer_version: version,
        response: "accepted",
        responded_by: "candidate",
        document_sha256: letter.sha256,
        ip_address: ip_address,
        user_agent: user_agent,
        link_sent_to_email: request.sent_to_email,
        typed_name: typed_name,
        created_at: Time.current
      )
      request.update!(status: "completed", completed_at: Time.current)
      offer.update!(status: "accepted", version: offer.version + 1)
      ChangeWriter.call(
        record: offer,
        action: "offer.accepted",
        event_type: "offer.accepted",
        payload: { "offer_response_id" => response.id },
        changes: { "status" => %w[sent accepted] }
      )
      hired = maybe_hire!(offer)
    end
    Result.new(offer: offer, response: response, hired: hired)
  end

  def decline!(reason_key:, ip_address:, user_agent:)
    request = SignatureRequestToken.verify(@token)
    Current.organization_id ||= request.organization_id
    version = request.offer_version
    offer = version.offer
    raise ArgumentError, "not_sent" unless offer.status == "sent"

    letter = version.offer_documents.find_by(kind: "letter")
    response = nil
    ActiveRecord::Base.transaction do
      response = OfferResponse.create!(
        offer_version: version,
        response: "declined",
        responded_by: "candidate",
        reason_key: reason_key,
        document_sha256: letter&.sha256,
        ip_address: ip_address,
        user_agent: user_agent,
        link_sent_to_email: request.sent_to_email,
        created_at: Time.current
      )
      request.update!(status: "declined", completed_at: Time.current)
      offer.update!(status: "declined", version: offer.version + 1)
      ChangeWriter.call(
        record: offer,
        action: "offer.declined",
        event_type: "offer.declined",
        payload: { "reason_key" => reason_key }.compact,
        changes: { "status" => %w[sent declined] }
      )
    end
    Result.new(offer: offer, response: response, hired: false)
  end

  def record!(response:, note:, reason_key:)
    offer = @offer
    raise ArgumentError, "bad_response" unless %w[accepted declined].include?(response)
    raise ArgumentError, "not_sent" unless offer.status == "sent"

    version = offer.current_version
    row = nil
    hired = false
    ActiveRecord::Base.transaction do
      row = OfferResponse.create!(
        offer_version: version,
        response: response,
        responded_by: "recorded_by_user",
        recorded_by_user_id: @actor_id,
        note: note,
        reason_key: reason_key,
        created_at: Time.current
      )
      offer.update!(status: response, version: offer.version + 1)
      ChangeWriter.call(
        record: offer,
        action: "offer.#{response}",
        event_type: "offer.#{response}",
        payload: { "recorded_by" => @actor_id },
        changes: { "status" => [ "sent", response ] }
      )
      hired = maybe_hire!(offer) if response == "accepted"
    end
    Result.new(offer: offer, response: row, hired: hired)
  end

  private

  def maybe_hire!(offer)
    org = Organization.find(Current.organization_id)
    return false unless org.hire_on_accept?

    application = offer.application
    SubjectTransitions.hire(subject: application)
    application.person.update!(lifecycle_stage: "employee")
    true
  end
end
