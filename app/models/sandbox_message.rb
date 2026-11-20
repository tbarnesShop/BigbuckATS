# frozen_string_literal: true

# A message in the in-product mail store behind the Sandbox transport. Outbound
# rows are what a real provider would have sent; inbound rows are what the Test
# inbox delivers back through InboundIngestor.
class SandboxMessage < ApplicationRecord
  include HasUuid
  include TenantScoped

  DIRECTIONS = %w[outbound inbound].freeze

  belongs_to :mailbox

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :rfc822_message_id, :thread_id, :from_address, :to_address, presence: true
end
