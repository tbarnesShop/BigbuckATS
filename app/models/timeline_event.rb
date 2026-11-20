# frozen_string_literal: true

class TimelineEvent < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :person

  validates :event_type, :payload, :occurred_at, presence: true
end
