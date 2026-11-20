# frozen_string_literal: true

class Document < ApplicationRecord
  include HasUuid
  include TenantScoped

  SCAN_STATUSES = %w[pending clean infected failed].freeze

  has_one_attached :file
  belongs_to :person

  validates :filename, :content_type, :byte_size, :checksum, :storage_key, presence: true
  validates :scan_status, inclusion: { in: SCAN_STATUSES }

  scope :downloadable, -> { where(scan_status: "clean") }

  def download!
    principal = Current.principal
    raise Authenticator::Forbidden.new("document_not_available") unless downloadable? &&
      principal.is_a?(Principal) && principal.can?("document.read") && ResourceVisibility.people.exists?(id: person_id)
    file.download
  end

  def downloadable?
    scan_status == "clean" && file.attached? && Person.where(id: person_id, erased_at: nil).exists?
  end
end
