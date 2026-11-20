# frozen_string_literal: true

# Org-managed vocabulary. Names are unique ignoring case and spacing, so "Go" and " go " are one tag.
class Tag < ApplicationRecord
  include HasUuid
  include TenantScoped

  COLOR = /\A#\h{6}\z/

  has_many :person_tags, dependent: :destroy

  before_validation :normalize

  validates :name, presence: true, length: { maximum: 60 }
  validates :normalized_name, uniqueness: { scope: :organization_id }
  validates :color, format: { with: COLOR }

  def self.normalize_name(value)
    value.to_s.strip.gsub(/\s+/, " ").downcase
  end

  def self.find_or_create_named!(name)
    key = normalize_name(name)
    raise ArgumentError, "tag_name_required" if key.blank?

    find_by(normalized_name: key) || create!(name: name.to_s.strip.gsub(/\s+/, " "))
  end

  # Moves every person onto `target`, skipping people who already carry it, then removes this tag.
  def merge_into!(target)
    raise ArgumentError, "cannot_merge_into_itself" if target.id == id

    transaction do
      already = PersonTag.where(tag_id: target.id).pluck(:person_id)
      PersonTag.where(tag_id: id).where.not(person_id: already).update_all(tag_id: target.id, updated_at: Time.current)
      destroy!
    end
    target
  end

  private

  def normalize
    self.name = name.to_s.strip.gsub(/\s+/, " ")
    self.normalized_name = self.class.normalize_name(name)
  end
end
