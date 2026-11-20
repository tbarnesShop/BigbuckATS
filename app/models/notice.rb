# frozen_string_literal: true

class Notice < ApplicationRecord
  include HasUuid
  include TenantScoped

  has_many :notice_versions, dependent: :destroy

  validates :key, :name, presence: true
  validates :key, uniqueness: { scope: :organization_id }

  def publish!(locale:, body:, version_number: nil)
    next_version = version_number || ((notice_versions.maximum(:version_number) || 0) + 1)
    notice_versions.create!(
      version_number: next_version,
      locale: locale,
      body: body,
      body_sha256: Digest::SHA256.hexdigest(body),
      created_at: Time.current
    )
  end

  def latest_for(locale)
    notice_versions.where(locale: locale).order(version_number: :desc).first ||
      notice_versions.where(locale: "en").order(version_number: :desc).first
  end
end
