# frozen_string_literal: true

class Job < ApplicationRecord
  include HasUuid
  include TenantScoped

  STATUSES = %w[draft active paused closed archived].freeze

  CAREERS_VISIBILITIES = %w[public internal both hidden].freeze

  scope :on_careers, ->(audience) {
    where(id: Posting.visible_on_careers(audience).select("postings.job_id"))
  }

  def visible_on_careers?(audience)
    %w[public internal].include?(audience) && status == "active" && !confidential? &&
      postings.where(status: "published", audience: [ audience, "both" ]).exists?
  end

  # Compatibility for the original job-level bulk audience control.
  after_update do
    if saved_change_to_careers_visibility?
      postings.each { |posting| posting.update!(audience: careers_visibility) }
    end
  end

  validates :careers_visibility, inclusion: { in: CAREERS_VISIBILITIES }

  belongs_to :pipeline
  belongs_to :requisition, optional: true
  has_one :hiring_team
  has_many :applications, dependent: :restrict_with_exception
  has_many :postings, dependent: :destroy

  validates :title, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :code_name, presence: true, if: :confidential?

  def activate!
    update!(status: "active")
  end
end
