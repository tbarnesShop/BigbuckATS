# frozen_string_literal: true

class MembershipScope < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :membership
  belongs_to :dimension
  belongs_to :dimension_value
end
