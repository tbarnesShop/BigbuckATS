# frozen_string_literal: true

class PersonContactPoint < ApplicationRecord
  include HasUuid
  include TenantScoped

  KINDS = %w[email phone url].freeze

  belongs_to :person

  validates :kind, inclusion: { in: KINDS }
  validates :value, :normalized_value, presence: true

  before_validation :normalize

  def held_duplicate?
    duplicate_of_person_id.present?
  end

  def self.normalize_email(value)
    value.to_s.strip.downcase
  end

  # E.164 where the number says enough: "+44 20 7946 0958" -> "+442079460958",
  # "(610) 555-0100" -> "+16105550100" (10 digits default to NANP, +1),
  # "0044 20..." -> "+4420...". Short or ambiguous numbers keep their digits, so
  # the same input always yields the same key. Changing this rule? Run
  # CleanContactPointsJob to re-key existing rows.
  def self.normalize_phone(value)
    raw = value.to_s.strip
    digits = raw.gsub(/\D/, "")
    return "" if digits.empty?
    return "+#{digits}" if raw.start_with?("+")
    return "+#{digits.delete_prefix('00')}" if digits.start_with?("00") && digits.length > 10
    return "+1#{digits}" if digits.length == 10
    return "+#{digits}" if digits.length == 11 && digits.start_with?("1")

    digits
  end

  def self.normalize_url(value)
    value.to_s.strip.downcase.sub(%r{\Ahttps?://}, "").sub(/\Awww\./, "").sub(/[?#].*\z/, "").delete_suffix("/")
  end

  def self.normalize_for(kind, value)
    case kind.to_s
    when "email" then normalize_email(value)
    when "phone" then normalize_phone(value)
    when "url" then normalize_url(value)
    else value.to_s.strip.downcase
    end
  end

  private

  def normalize
    self.normalized_value = self.class.normalize_for(kind, value)
    self.canonical_key = held_duplicate? ? nil : normalized_value
  end
end
