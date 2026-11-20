# frozen_string_literal: true

# Every tenant record write leaves an audit row, even when a service saves a
# model directly instead of going through ChangeWriter. Rows are redacted by data
# class (see AuditRecorder) and written in the same transaction as the change.
#
# Not covered: update_columns / update_all / delete_all / insert_all, which skip
# callbacks by design (bookkeeping counters, bulk projections, erasure sweeps).
module AuditTrail
  extend ActiveSupport::Concern

  # Projections, logs and caches whose own rows are the record of what happened.
  EXEMPT = %w[
    AuditEvent OutboxEvent IdempotencyKey TimelineEvent ImportRow WebhookDelivery
    RetentionAction SandboxMessage
  ].freeze

  included do
    attr_accessor :audited_by_change_writer

    after_create { audit_trail!("created", saved_changes) }
    after_update { audit_trail!("updated", saved_changes) }
    after_destroy { audit_trail!("destroyed", attributes.slice("id")) }
  end

  private

  def audit_trail!(verb, changes)
    return if audited_by_change_writer
    return if EXEMPT.include?(self.class.name)
    return unless has_attribute?(:organization_id) && organization_id.present?

    changes = changes.except("updated_at", "created_at")
    return if verb == "updated" && changes.empty?

    AuditRecorder.record!(record: self, action: "#{self.class.model_name.singular}.#{verb}", changes: changes)
  end
end
