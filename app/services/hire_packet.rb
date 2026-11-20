# frozen_string_literal: true

# Snapshot handed to HRIS (or downloaded) after hire.
class HirePacket
  def self.build(application:)
    new(application).build
  end

  def initialize(application)
    @application = application
  end

  def build
    offer = Offer.find_by(application_id: @application.id, status: "accepted")
    version = offer&.current_version
    person = @application.person
    job = @application.job
    {
      "application_id" => @application.id,
      "status" => @application.status,
      "person" => {
        "id" => person.id,
        "display_name" => person.display_name,
        "primary_email" => person.primary_email,
        "lifecycle_stage" => person.lifecycle_stage
      },
      "job" => {
        "id" => job.id,
        "title" => job.title,
        "dimensions" => job_dimensions(job)
      },
      "offer" => offer && {
        "id" => offer.id,
        "fields" => version&.fields,
        "accepted_at" => version&.offer_response&.created_at,
        "document_sha256" => version&.offer_documents&.find_by(kind: "letter")&.sha256
      }
    }
  end

  private

  def job_dimensions(job)
    EntityDimensionValue.where(entity_type: "Job", entity_id: job.id).each_with_object({}) do |edv, out|
      out[edv.dimension.key] = edv.dimension_value.key
    end
  end
end
