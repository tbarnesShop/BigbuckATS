# frozen_string_literal: true

class Requisition < ApplicationRecord
  include HasUuid
  include TenantScoped

  STATUSES = %w[draft pending_approval approved open filled closed].freeze

  has_many :jobs, dependent: :nullify

  validates :code, :title, :status, presence: true
  validates :code, uniqueness: { scope: :organization_id }
  validates :status, inclusion: { in: STATUSES }
  validates :headcount, numericality: { only_integer: true, greater_than: 0 }

  def filled_count
    Application.joins(:job).where(jobs: { requisition_id: id }, status: "hired").count
  end

  def open!
    update!(status: "open", approved_at: approved_at || Time.current, closed_at: nil)
  end

  def close!
    update!(status: "closed", closed_at: Time.current)
  end
end
