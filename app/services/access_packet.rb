# frozen_string_literal: true

# Everything held about the person except interviewer scorecards and offer compensation.
class AccessPacket
  def self.build(person:)
    new(person).build
  end

  def initialize(person)
    @person = person
  end

  def build
    {
      "person" => {
        "id" => @person.id,
        "display_name" => @person.display_name,
        "primary_email" => @person.primary_email,
        "primary_phone" => @person.primary_phone,
        "country" => @person.country,
        "region" => @person.region,
        "lifecycle_stage" => @person.lifecycle_stage
      },
      "contact_points" => @person.contact_points.map { |cp| { "kind" => cp.kind, "value" => cp.value } },
      "applications" => Application.where(person_id: @person.id).map { |a|
        { "id" => a.id, "job_id" => a.job_id, "status" => a.status, "stage" => a.current_stage_key,
          "posting_id" => a.posting_id, "application_form_snapshot" => a.application_form_snapshot,
          "application_answers" => a.application_answers }
      },
      "communications" => Communication.where(person_id: @person.id).map { |c|
        { "id" => c.id, "direction" => c.direction, "subject" => c.subject, "sent_at" => c.created_at }
      },
      "consents" => Consent.where(person_id: @person.id).map { |c|
        { "purpose_id" => c.consent_purpose_id, "status" => c.status, "captured_at" => c.captured_at }
      },
      "offers" => offers_without_compensation,
      "custom_fields" => custom_fields,
      "documents" => Document.where(person_id: @person.id).map { |d|
        { "id" => d.id, "filename" => d.filename, "content_type" => d.content_type, "uploaded_at" => d.created_at }
      },
      "notices_shown" => NoticeReceipt.where(person_id: @person.id).map { |r|
        { "notice_version_id" => r.notice_version_id, "shown_at" => r.try(:shown_at) || r.created_at }
      },
      "excluded" => {
        "scorecards" => "Interviewer scorecards are the company's call to share",
        "offer_compensation" => "Compensation fields require offer.view_compensation"
      }
    }
  end

  private

  def custom_fields
    CustomFieldValue.where(entity_type: "Person", entity_id: @person.id).includes(:custom_field).filter_map do |row|
      next unless CustomFieldTypes.present?(row, row.custom_field.field_type)

      { "key" => row.custom_field.key, "label" => row.custom_field.label, "value" => row.typed_value }
    end
  end

  def offers_without_compensation
    app_ids = Application.where(person_id: @person.id).pluck(:id)
    Offer.where(application_id: app_ids).map do |offer|
      fields = OfferFieldPolicy.read(offer.current_version&.fields)
      { "id" => offer.id, "status" => offer.status, "fields" => fields }
    end
  end
end
