# frozen_string_literal: true

class Communication < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :person
  belongs_to :mailbox, optional: true

  validates :direction, :channel, :status, presence: true
end
