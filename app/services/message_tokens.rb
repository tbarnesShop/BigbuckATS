# frozen_string_literal: true

# The merge fields a template may use. One place builds them, so sequences, the send queue and the
# person-page composer all agree. Unknown tokens in a template are rejected by MessageRenderer.
class MessageTokens
  NAMES = %w[
    person.display_name person.first_name person.email person.headline person.current_title
    person.current_company person.city sender.name sender.email opener
  ].freeze

  def self.for(person:, sender: nil, sender_email: nil, extra: nil)
    company = person.current_company&.name ||
              person.affiliations.where(current: true).includes(:company).first&.company&.name
    {
      "person.display_name" => person.display_name,
      "person.first_name" => person.display_name.to_s.split.first.to_s,
      "person.email" => person.primary_email,
      "person.headline" => person.headline,
      "person.current_title" => person.current_title,
      "person.current_company" => company,
      "person.city" => person.city,
      "sender.name" => sender&.name,
      "sender.email" => sender_email || sender&.email,
      "opener" => (extra || {})["opener"]
    }.transform_values { |value| value.to_s }
  end
end
