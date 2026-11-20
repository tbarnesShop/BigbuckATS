# frozen_string_literal: true

class ReferralCreator
  def self.call(referrer_user:, display_name:, email: nil, job: nil, note: nil)
    new(referrer_user: referrer_user, display_name: display_name, email: email, job: job, note: note).call
  end

  def initialize(referrer_user:, display_name:, email:, job:, note:)
    @referrer_user = referrer_user
    @display_name = display_name
    @email = email
    @job = job
    @note = note
  end

  def call
    result = PersonMatcher.find_or_create(
      display_name: @display_name,
      email: @email,
      viewer: nil,
      source: "referral"
    )
    person = result.person
    unless result.attached
      ChangeWriter.call(
        record: person,
        action: "person.created",
        event_type: "person.created",
        payload: { "display_name" => person.display_name, "source" => "referral" }
      )
    end

    application = nil
    if @job
      application = Application.find_by(job_id: @job.id, person_id: person.id) ||
                    ApplicationCreator.call(job: @job, person: person)
    end

    referral = Referral.create!(
      person: person,
      referrer_user_id: @referrer_user.id,
      job: @job,
      application: application,
      status: application ? "converted" : "submitted",
      note: @note
    )
    ChangeWriter.call(
      record: referral,
      action: "referral.created",
      event_type: "referral.created",
      payload: {
        "person_id" => person.id,
        "referrer_user_id" => @referrer_user.id,
        "job_id" => @job&.id,
        "application_id" => application&.id
      }
    )
    referral
  end
end
