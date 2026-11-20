# frozen_string_literal: true

# Builds one audit row for a change, redacting values by data class. Used by
# ChangeWriter (explicit domain changes) and AuditTrail (every other model write).
class AuditRecorder
  def self.record!(record:, action:, changes:, actor_id: Current.audit_actor_id, actor_type: Current.actor_type)
    org_id = record.try(:organization_id).presence || Current.organization_id
    raise Current::TenantRequired, "organization required" if org_id.blank?

    AuditEvent.create!(
      organization_id: org_id,
      action: action,
      resource_type: record.class.name,
      resource_id: record.id,
      actor_id: actor_id,
      actor_type: actor_type.presence || (actor_id ? "user" : "system"),
      on_behalf_of_id: Current.on_behalf_of_id,
      credential_id: Current.credential_id,
      source_surface: Current.source_surface.presence || "system",
      api_version: api_version,
      change_set: redact(record, changes, org_id),
      request_id: Current.request_id
    )
  end

  def self.api_version
    principal = Current.principal
    principal.respond_to?(:api_version) && principal.api_version.present? ? principal.api_version : ApiCredential::CURRENT_API_VERSION
  end

  # pii/sensitive -> keyed hashes; secret -> dropped; internal -> as-is.
  def self.redact(record, changes, org_id)
    table = record.class.table_name
    columns = record.class.column_names
    changes.to_h.each_with_object({}) do |(key, pair), out|
      cls = column_class(record, table, columns, key.to_s)
      next if cls == "secret"

      values = Array(pair)
      out[key.to_s] = DataClasses::HASHED.include?(cls) ? values.map { |v| AuditHasher.digest(org_id, v) } : values
    end
  end

  def self.column_class(record, table, columns, key)
    cls = DataClasses.lookup(table, key)
    if cls == "dynamic"
      return record.respond_to?(:custom_field) ? (record.custom_field&.data_class.presence || "pii") : "pii"
    end
    return cls if cls

    # A key that is not a column of the table (a synthetic change like
    # "merged_id") is hashed: fail closed, never stored in the clear.
    return "pii" unless columns.include?(key)

    message = "#{table}.#{key} has no data class in config/data_classes.yml"
    raise DataClasses::Unclassified, message if Rails.env.local?

    Rails.logger.warn({ event: "audit.unclassified_column", column: "#{table}.#{key}" }.to_json)
    "pii"
  end

  private_class_method :column_class
end
