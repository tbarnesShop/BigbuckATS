# frozen_string_literal: true

# Erases personal data while keeping an empty person row for FKs / reporting.
# mode: delete (clears messages/enrollments/scorecards text) | anonymize (clears text, keeps rows)
class PersonEraser
  Error = Class.new(StandardError)
  Held = Class.new(Error)

  # Inventory of person-linked surfaces checked by the proving test.
  INVENTORY = %i[
    person_fields contact_points communications timeline_events
    outbox_events consents notice_receipts custom_field_values
    documents import_rows idempotency_keys webhook_deliveries application_answers
    offer_documents offer_versions referrals affiliations scheduled_messages scorecards file_cleanup_pending sandbox_messages person_notes person_tags sourcing_tasks rediscovery_candidates agent_proposals
  ].freeze

  def self.call(person:, mode: "delete", actor_id: Current.actor_id)
    new(person: person, mode: mode, actor_id: actor_id).call
  end

  def self.verify(person)
    new(person: person, mode: "delete", actor_id: nil).residuals
  end

  def initialize(person:, mode:, actor_id:)
    @person = person
    @mode = mode.to_s
    @actor_id = actor_id
    raise ArgumentError, "invalid_erasure_mode" unless @mode.in?(%w[delete anonymize])
  end

  def call
    if DemoSandbox.for_organization(@person.organization_id)
      raise Authenticator::Forbidden.new("demo_action_blocked", DemoPolicy::MESSAGE)
    end
    raise Held, "legal_hold" if LegalHoldService.person_held?(@person.id)
    raise ArgumentError, "already_erased" if @person.erased?

    @prior_email = @person.primary_email
    @prior_emails = ([ @prior_email ] + PersonContactPoint.where(person_id: @person.id, kind: "email").pluck(:value)).compact_blank.uniq
    @blobs = []
    @legacy_keys = []
    ActiveRecord::Base.transaction do
      clear_webhook_snippets!
      redact_outbox!
      clear_person!
      clear_contact_points!
      clear_communications!
      clear_sandbox_messages!
      clear_timeline!
      redact_evidence!
      clear_custom_field_values!
      clear_documents!
      clear_import_rows!
      clear_cached_responses!
      clear_scorecards_and_enrollments!
      clear_derived_copies!
      clear_notes_and_tags!
      clear_tasks!

      @cleanup_action = RetentionAction.create!(
        person: @person,
        action: @mode == "anonymize" ? "anonymized" : "erased",
        actor_id: @actor_id,
        details: { "mode" => @mode, "blob_ids" => @blobs.map(&:id), "legacy_keys" => @legacy_keys,
          "blobs" => @blobs.map { |blob| { "id" => blob.id, "key" => blob.key, "service_name" => blob.service_name } } },
        created_at: Time.current
      )
      ChangeWriter.call(
        record: @person,
        action: "person.erased",
        event_type: "person.erased",
        payload: { "mode" => @mode, "person_id" => @person.id, "redacted" => true },
        changes: { "erased_at" => [ nil, @person.erased_at ] }
      )
    end
    # The transaction is committed before irreversible storage cleanup. Retry
    # jobs retain cleanup intent, and verification reports pending storage work.
    ErasedDocumentCleanupJob.perform_later(@cleanup_action.id) if @blobs.any?
    @legacy_keys.each { |key| LegacyDocumentCleanupJob.perform_later(@person.organization_id, key) }
    residuals = self.residuals - [ "file_cleanup_pending" ]
    raise Error, "residual_pii:#{residuals.join(",")}" if residuals.any?

    @person
  end

  def residuals
    found = []
    p = Person.unscoped.find(@person.id)
    found << "person_fields" if p.primary_email.present? || p.primary_phone.present? || p.country.present? || p.region.present? ||
                                   p.headline.present? || p.current_title.present? || p.city.present? || p.source_detail.present?
    found << "contact_points" if PersonContactPoint.unscoped.where(person_id: p.id).where.not(value: [ nil, "" ]).exists?
    found << "communications" if Communication.unscoped.where(person_id: p.id)
                                                      .where("(subject IS NOT NULL AND subject != '') OR (body IS NOT NULL AND body != '')")
                                                      .exists?
    if @prior_email.present? && SandboxMessage.unscoped.where(organization_id: p.organization_id).where("from_address = :a OR to_address = :a", a: @prior_email).exists?
      found << "sandbox_messages"
    end
    found << "timeline_events" if defined?(TimelineEvent) && TimelineEvent.unscoped.where(person_id: p.id).exists?
    if @prior_email.present?
      found << "outbox_events" if OutboxEvent.unscoped.where(organization_id: p.organization_id)
                                                     .where("payload LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@prior_email)}%")
                                                     .exists?
    end
    found << "consents" if Consent.unscoped.where(person_id: p.id).where("ip_address IS NOT NULL OR user_agent IS NOT NULL").exists?
    found << "application_answers" if Application.unscoped.where(organization_id: p.organization_id, person_id: p.id).where.not(application_answers: nil).exists?
    found << "custom_field_values" if personal_custom_values(p).exists?
    found << "documents" if Document.unscoped.where(person_id: p.id).where.not(filename: ERASED).exists?
    found << "import_rows" if import_rows_for(p.organization_id, p.id, @prior_email).where("raw IS NOT NULL OR mapped IS NOT NULL").exists?
    found << "idempotency_keys" if cached_responses_for(p.organization_id, p.id, @prior_email).exists?
    found << "person_fields" if p.do_not_contact_reason.present? || p.display_name != ERASED
    app_ids = Application.unscoped.where(organization_id: p.organization_id, person_id: p.id).select(:id)
    version_ids = OfferVersion.unscoped.where(organization_id: p.organization_id, offer_id: Offer.unscoped.where(organization_id: p.organization_id, application_id: app_ids).select(:id)).select(:id)
    found << "offer_documents" if OfferDocument.unscoped.where(organization_id: p.organization_id, offer_version_id: version_ids).where.not(body_html: ERASED).exists?
    found << "offer_versions" if OfferVersion.unscoped.where(organization_id: p.organization_id, id: version_ids).where("JSON_LENGTH(fields) > 0").exists?
    found << "referrals" if Referral.unscoped.where(organization_id: p.organization_id, person_id: p.id).where.not(note: nil).exists?
    found << "affiliations" if PersonAffiliation.unscoped.where(organization_id: p.organization_id, person_id: p.id).exists?
    found << "sourcing_tasks" if SourcingTask.unscoped.where(organization_id: p.organization_id, person_id: p.id).where("title <> ? OR description IS NOT NULL", ERASED).exists?
    found << "person_notes" if PersonNote.unscoped.where(organization_id: p.organization_id, person_id: p.id).exists?
    found << "agent_proposals" if AgentProposal.unscoped.where(organization_id: p.organization_id, person_id: p.id).where.not(draft_opener: ERASED).exists?
    found << "rediscovery_candidates" if RediscoveryCandidate.unscoped.where(organization_id: p.organization_id, person_id: p.id).exists?
    found << "person_tags" if PersonTag.unscoped.where(organization_id: p.organization_id, person_id: p.id).exists?
    found << "scheduled_messages" if ScheduledMessage.unscoped.where(organization_id: p.organization_id, person_id: p.id).where.not(body: ERASED).exists?
    found << "scorecards" if Scorecard.unscoped.where(organization_id: p.organization_id, interview_id: Interview.unscoped.where(organization_id: p.organization_id, application_id: app_ids).select(:id)).where.not(notes: nil).exists?
    actions = RetentionAction.unscoped.where(organization_id: p.organization_id, person_id: p.id)
    blob_ids = actions.flat_map { |action| Array(action.details["blob_ids"]) }
    storage_pending = actions.flat_map { |action| Array(action.details["blobs"]) }.any? do |entry|
      begin
        ActiveStorage::Blob.services.fetch(entry.fetch("service_name")).exist?(entry.fetch("key"))
      rescue StandardError
        true # An unavailable storage backend cannot prove cleanup succeeded.
      end
    end
    legacy_keys = actions.flat_map { |action| Array(action.details["legacy_keys"]) }
    legacy_pending = legacy_keys.any? do |key|
      !key.match?(%r{\Aquarantine/#{Regexp.escape(p.organization_id)}/[a-zA-Z0-9-]+/[^/\\]+\z}) || Rails.root.join("storage", key).exist?
    end
    found << "file_cleanup_pending" if storage_pending || legacy_pending || ActiveStorage::Blob.where(id: blob_ids).exists?
    found << "data_requests" if DataRequest.unscoped.where(organization_id: p.organization_id, person_id: p.id).where.not(requester_email: ERASED).exists?
    found << "signature_requests" if SignatureRequest.unscoped.where(organization_id: p.organization_id, offer_version_id: version_ids).where.not(sent_to_email: ERASED).exists?
    found.uniq
  end

  private

  def clear_person!
    @person.update_columns(
      display_name: "erased",
      primary_email: nil,
      primary_phone: nil,
      country: nil,
      region: nil,
      headline: nil,
      current_title: nil,
      current_company_id: nil,
      city: nil,
      source_detail: nil,
      do_not_contact_reason: nil,
      source_id: nil,
      do_not_contact: true,
      erased_at: Time.current,
      updated_at: Time.current
    )
    @person.reload
  end

  def clear_contact_points!
    PersonContactPoint.where(person_id: @person.id).find_each do |cp|
      cp.update_columns(value: "", normalized_value: "", canonical_key: nil, updated_at: Time.current)
    end
  end


  def clear_communications!
    Communication.where(person_id: @person.id).update_all(subject: nil, body: nil, updated_at: Time.current)
  end

  def clear_tasks!
    SourcingTask.where(person_id: @person.id).update_all(title: ERASED, description: nil, status: "cancelled", updated_at: Time.current)
  end

  def clear_notes_and_tags!
    PersonNote.where(person_id: @person.id).delete_all
    PersonTag.where(person_id: @person.id).delete_all
    RediscoveryCandidate.where(person_id: @person.id).delete_all
    AgentProposal.where(person_id: @person.id).update_all(draft_opener: ERASED, final_opener: nil, rationale: {}, decision_reason: nil, status: "rejected", updated_at: Time.current)
    SequenceEnrollment.where(person_id: @person.id).update_all(merge_fields: nil)
  end

  def clear_sandbox_messages!
    @prior_emails.each do |address|
      scope = SandboxMessage.where(organization_id: @person.organization_id)
      scope.where(from_address: address).update_all(from_address: ERASED, subject: nil, mime: nil, updated_at: Time.current)
      scope.where(to_address: address).update_all(to_address: ERASED, subject: nil, mime: nil, updated_at: Time.current)
    end
  end

  def clear_timeline!
    TimelineEvent.where(person_id: @person.id).delete_all if defined?(TimelineEvent)
  end

  def redact_outbox!
    candidates = OutboxEvent.where(organization_id: @person.organization_id)
                            .where("JSON_UNQUOTE(JSON_EXTRACT(payload, '$.person_id')) = ? OR CAST(payload AS CHAR) LIKE ?",
                                   @person.id, "%#{OutboxEvent.sanitize_sql_like(@prior_email.to_s.presence || @person.id)}%")
    candidates.find_each do |event|
      payload = event.payload
      next unless payload.is_a?(Hash)


      redacted = { "person_id" => @person.id, "redacted" => true }
      event.update_columns(payload: redacted)
    end
  end

  def redact_evidence!
    Consent.where(person_id: @person.id).update_all(ip_address: nil, user_agent: nil, evidence_json: {})
    NoticeReceipt.where(person_id: @person.id).update_all(ip_address: nil, user_agent: nil)
    Application.where(person_id: @person.id).update_all(application_answers: nil)
    app_ids = Application.where(person_id: @person.id).pluck(:id)
    version_ids = Offer.where(application_id: app_ids).flat_map { |o| o.offer_versions.pluck(:id) }
    OfferResponse.where(offer_version_id: version_ids).update_all(
      note: nil, link_sent_to_email: nil, ip_address: nil, user_agent: nil, typed_name: nil
    ) if version_ids.any?
  end

  ERASED = "erased"

  # Values of personal fields on the person and their applications.
  def personal_custom_values(person)
    app_ids = Application.unscoped.where(organization_id: person.organization_id, person_id: person.id).select(:id)
    scoped = CustomFieldValue.unscoped.where(organization_id: person.organization_id)
    values = scoped.where(entity_type: "Person", entity_id: person.id)
                   .or(scoped.where(entity_type: "Application", entity_id: app_ids))
                   .where("value_text IS NOT NULL OR value_number IS NOT NULL OR value_date IS NOT NULL OR value_json IS NOT NULL")
    values
  end

  def clear_custom_field_values!
    personal_custom_values(@person).update_all(value_text: nil, value_number: nil, value_date: nil, value_json: nil,
                                               updated_at: Time.current)
  end

  # Uploaded files (resumes) are removed from storage; the row stays for references.
  def clear_documents!
    Document.where(person_id: @person.id).find_each do |doc|
      # Active Storage purge jobs run after commit and can be retried. Never
      # delete a physical file inside a SQL transaction that might roll back.
      if doc.file.attached?
        @blobs << doc.file.blob
        doc.file.detach
      elsif doc.storage_key.present? && !doc.storage_key.start_with?("erased/")
        @legacy_keys << doc.storage_key
      end
      doc.update_columns(filename: ERASED, storage_key: "#{ERASED}/#{doc.id}", updated_at: Time.current)
    end
  end

  def import_rows_for(org_id, person_id, email)
    rows = ImportRow.unscoped.where(organization_id: org_id)
    linked = rows.where(resource_type: "Person", resource_id: person_id)
    return linked if email.blank?

    linked.or(rows.where("JSON_SEARCH(raw, 'one', ?) IS NOT NULL OR JSON_SEARCH(mapped, 'one', ?) IS NOT NULL", email, email))
  end

  def clear_import_rows!
    import_rows_for(@person.organization_id, @person.id, @prior_email).update_all(raw: nil, mapped: nil, updated_at: Time.current)
  end

  # Idempotency keys cache API responses, which can contain the person.
  def cached_responses_for(org_id, person_id, email)
    keys = IdempotencyKey.unscoped.where(organization_id: org_id)
    match = keys.where("CAST(response_body AS CHAR) LIKE ?", "%#{IdempotencyKey.sanitize_sql_like(person_id)}%")
    return match if email.blank?

    match.or(keys.where("CAST(response_body AS CHAR) LIKE ?", "%#{IdempotencyKey.sanitize_sql_like(email)}%"))
  end

  def clear_cached_responses!
    cached_responses_for(@person.organization_id, @person.id, @prior_email).delete_all
  end

  # Webhook deliveries keep a short slice of the receiver's response, which can
  # echo the event payload. Clear it for every delivery of an event about this
  # person. Runs before redact_outbox! so events matched by email are still found.
  def clear_webhook_snippets!
    event_ids = OutboxEvent.where(organization_id: @person.organization_id)
                           .where("JSON_UNQUOTE(JSON_EXTRACT(payload, '$.person_id')) = ? OR CAST(payload AS CHAR) LIKE ?",
                                  @person.id, "%#{OutboxEvent.sanitize_sql_like(@prior_email.to_s.presence || @person.id)}%")
                           .pluck(:id)
    return if event_ids.empty?

    WebhookDelivery.where(outbox_event_id: event_ids).update_all(response_snippet: nil, updated_at: Time.current)
  end

  def clear_derived_copies!
    app_ids = Application.where(person_id: @person.id).select(:id)
    version_ids = OfferVersion.where(offer_id: Offer.where(application_id: app_ids).select(:id)).pluck(:id)
    OfferDocument.where(offer_version_id: version_ids).update_all(body_html: ERASED)
    OfferVersion.where(id: version_ids).update_all(fields: {})
    SignatureRequest.where(offer_version_id: version_ids).update_all(sent_to_email: ERASED, status: "voided")
    Referral.where(person_id: @person.id).update_all(note: nil)
    DataRequest.where(person_id: @person.id).update_all(requester_email: ERASED, outcome_note: nil)
    PersonAffiliation.where(person_id: @person.id).delete_all
    ScheduledMessage.where(person_id: @person.id).update_all(subject: ERASED, body: ERASED, last_error: nil, status: "cancelled")
    StageTransition.where(subject_type: "Application", subject_id: app_ids).update_all(reason: nil)
    ProjectMember.where(person_id: @person.id).update_all(note: nil)
    ProjectMember.where(person_id: @person.id).find_each do |member|
      StageTransition.where(subject_type: "ProjectMember", subject_id: member.id).update_all(reason: nil)
    end
  end

  def clear_scorecards_and_enrollments!
    SequenceEnrollment.where(person_id: @person.id).update_all(status: "stopped", updated_at: Time.current)
    app_ids = Application.where(person_id: @person.id).pluck(:id)
    interview_ids = Interview.where(application_id: app_ids).pluck(:id)
    Scorecard.where(interview_id: interview_ids).update_all(notes: nil, rating: nil, updated_at: Time.current) if interview_ids.any?
  end
end
