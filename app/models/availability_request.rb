# frozen_string_literal: true

class AvailabilityRequest < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :scheduling_link
end
