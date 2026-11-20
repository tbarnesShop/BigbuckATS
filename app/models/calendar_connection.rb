# frozen_string_literal: true

class CalendarConnection < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :kind, :calendar_id, :secret_ref, :status, presence: true
end
