# frozen_string_literal: true

# Writes domain state, one audit row, and one outbox event in a single transaction.
# Pass event_type: nil for an audit-only change (sign-ins, credential use).
# Values reach audit history through AuditRecorder, redacted by data class.
class ChangeWriter
  Result = Struct.new(:record, :audit_event, :outbox_event, keyword_init: true)

  def self.call(...)
    new(...).call
  end

  def initialize(record:, action:, event_type:, payload: {}, changes: {}, actor_id: Current.audit_actor_id, actor_type: Current.actor_type)
    @record = record
    @action = action
    @event_type = event_type
    @payload = payload
    @changes = changes
    @actor_id = actor_id
    @actor_type = actor_type
  end

  def call
    raise Current::TenantRequired, "organization required" if Current.organization_id.blank?

    ActiveRecord::Base.transaction do
      # This write is audited below, so the model-level AuditTrail skips it.
      @record.audited_by_change_writer = true if @record.respond_to?(:audited_by_change_writer=)
      @record.save!

      audit = AuditRecorder.record!(
        record: @record, action: @action, actor_id: @actor_id, actor_type: @actor_type,
        changes: @changes.presence || @record.previous_changes
      )

      outbox = if @event_type
                 OutboxEvent.create!(
                   organization_id: Current.organization_id,
                   event_type: @event_type,
                   resource_type: @record.class.name,
                   resource_id: @record.id,
                   payload: @payload.merge(
                     "id" => @record.id,
                     "organization_id" => Current.organization_id,
                     "version" => @record.try(:version)
                   ),
                   subject_version: @record.try(:version),
                   api_version: audit.api_version,
                   actor_type: audit.actor_type,
                   actor_id: audit.actor_id,
                   source_surface: audit.source_surface
                 )
      end

      Result.new(record: @record, audit_event: audit, outbox_event: outbox)
    end
  ensure
    @record.audited_by_change_writer = false if @record.respond_to?(:audited_by_change_writer=)
  end
end
