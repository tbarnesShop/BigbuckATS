# frozen_string_literal: true

class DncCompany < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :company, optional: true

  validate :company_or_domain

  private

  def company_or_domain
    return if company_id.present? || domain.present?

    errors.add(:base, "company_id_or_domain_required")
  end
end
