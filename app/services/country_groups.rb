# frozen_string_literal: true

# Shorthand region groups for compliance conditions.
module CountryGroups
  GROUPS = {
    "eu" => %w[AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE],
    "eea" => %w[AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE IS LI NO],
    "uk" => %w[GB UK],
    "us" => %w[US],
    "ca" => %w[CA],
    "eu-eea-uk-ch" => %w[AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE IS LI NO GB UK CH]
  }.freeze

  def self.expand(values)
    Array(values).flat_map do |v|
      key = v.to_s.downcase
      GROUPS[key] || [ v.to_s.upcase ]
    end.uniq
  end

  def self.regions_for_country(country)
    code = country.to_s.upcase
    GROUPS.select { |_name, members| members.include?(code) }.keys
  end
end
