# frozen_string_literal: true

module TenantScoped
  extend ActiveSupport::Concern

  TENANT_COLUMN = :organization_id

  included do
    belongs_to :organization, optional: false

    validates TENANT_COLUMN, presence: true

    before_validation :assign_tenant_from_current, on: :create

    default_scope -> { tenant_default_scope }
  end

  class_methods do
    def tenant_default_scope
      org_id = Current.organization_id
      if org_id.blank?
        where("1 = 0")
      else
        where(TENANT_COLUMN => org_id)
      end
    end

    def within_organization(organization_id)
      raise ArgumentError, "organization_id required" if organization_id.blank?

      unscoped.where(TENANT_COLUMN => organization_id)
    end
  end

  private

  def assign_tenant_from_current
    self.organization_id ||= Current.organization_id
  end
end
