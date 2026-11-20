# frozen_string_literal: true

# Rule-engine context for offer approval matching and step conditions.
class OfferContext
  def self.build(offer:, fields: nil)
    new(offer: offer, fields: fields).build
  end

  def initialize(offer:, fields:)
    @offer = offer
    @application = offer.application
    @job = @application.job
    @fields = (fields || offer.current_version&.fields || {}).deep_stringify_keys
  end

  def build
    {
      "offer" => { "fields" => @fields, "status" => @offer.status },
      "job" => {
        "id" => @job.id,
        "title" => @job.title,
        "dimensions" => job_dimensions
      },
      "subject" => { "id" => @application.id, "status" => @application.status }
    }
  end

  def attribute_at(path)
    # e.g. job.dimensions.department.head → value_attributes["head"] on the job's department value
    parts = path.to_s.split(".")
    return nil unless parts[0] == "job" && parts[1] == "dimensions" && parts.size >= 4

    dim_key = parts[2]
    attr_key = parts[3..]
    value = dimension_value_for(dim_key)
    return nil unless value

    attr_key.reduce(value.value_attributes) { |acc, key| acc.is_a?(Hash) ? acc[key] : nil }
  end

  private

  def job_dimensions
    EntityDimensionValue.where(entity_type: "Job", entity_id: @job.id).each_with_object({}) do |edv, out|
      dim = edv.dimension
      val = edv.dimension_value
      out[dim.key] = val.key
      out[dim.key + "_id"] = val.id
    end
  end

  def dimension_value_for(dim_key)
    dim = Dimension.find_by(key: dim_key)
    return nil unless dim

    edv = EntityDimensionValue.find_by(entity_type: "Job", entity_id: @job.id, dimension_id: dim.id)
    edv&.dimension_value
  end
end
