# frozen_string_literal: true

# Something an agent wants to do that needs a person's say-so. Today: enroll a person in a sequence
# with a drafted opener. Nothing is sent until a human approves (unless the org policy allows it).
class AgentProposal < ApplicationRecord
  include HasUuid
  include TenantScoped

  STATUSES = %w[pending approved rejected].freeze

  belongs_to :agent
  belongs_to :person
  belongs_to :sequence
  belongs_to :mailbox

  validates :status, inclusion: { in: STATUSES }
  validates :kind, inclusion: { in: %w[enrollment] }

  scope :pending, -> { where(status: "pending") }

  def pending? = status == "pending"
end
