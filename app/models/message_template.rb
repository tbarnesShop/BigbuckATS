# frozen_string_literal: true

class MessageTemplate < ApplicationRecord
  include HasUuid
  include TenantScoped

  validates :key, :message_type, :subject, :body, presence: true

  # Archived templates drop out of lists and pickers. Sequences that already
  # reference one by key keep rendering it.
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  STATUSES = %w[active archived all].freeze

  def self.create_template!(key:, message_type:, subject:, body:, locale: nil)
    locale = locale.presence || "en"
    raise ArgumentError, "key_taken" if exists?(key: key, locale: locale)

    template = new(key: key, message_type: message_type, locale: locale, subject: subject, body: body)
    ChangeWriter.call(
      record: template, action: "message_template.created", event_type: "message_template.created",
      payload: { "key" => template.key, "locale" => template.locale }
    )
    template
  end

  def update_template!(subject:, body:, message_type: nil)
    raise ArgumentError, "archived_template" if archived_at.present?

    before = { "subject" => self.subject, "body" => self.body, "message_type" => self.message_type }
    assign_attributes({ subject: subject, body: body, message_type: message_type.presence || self.message_type })
    changed = before.reject { |key, value| public_send(key) == value }.to_h { |key, value| [ key, [ value, public_send(key) ] ] }
    return self if changed.empty?

    ChangeWriter.call(
      record: self, action: "message_template.updated", event_type: "message_template.updated",
      payload: { "key" => key, "locale" => locale }, changes: changed.except("body").merge(changed.key?("body") ? { "body" => [ "…", "…" ] } : {})
    )
    self
  end

  def archive_template!
    raise ArgumentError, "already_archived" if archived_at.present?

    self.archived_at = Time.current
    ChangeWriter.call(
      record: self, action: "message_template.archived", event_type: "message_template.archived",
      payload: { "key" => key, "locale" => locale },
      changes: { "archived_at" => [ nil, archived_at ] }
    )
    self
  end
end
