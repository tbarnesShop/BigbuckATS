# frozen_string_literal: true

# Applies retention to every person in every organization, in batches, as the
# system actor. RetentionRunner decides per person (legal holds, open
# applications, employees and policies all respected).
class RetentionSweep
  BATCH = 500
  # Receiver response snippets on webhook deliveries are debugging aids only.
  WEBHOOK_SNIPPET_TTL = 30.days

  def self.call(as_of: Time.current, organization_ids: nil)
    totals = Hash.new(0)
    purged_snippets = 0
    orgs = organization_ids ? Organization.where(id: organization_ids) : Organization.all
    orgs.find_each do |org|
      next if DemoSandbox.for_organization(org.id)
      Current.set(organization_id: org.id, actor_type: "system", source_surface: "automation") do
        Person.where(erased_at: nil, merged_into_id: nil).find_each(batch_size: BATCH) do |person|
          result = RetentionRunner.call(person: person, as_of: as_of, actor_id: nil)
          totals[result[:action]] += 1
        rescue StandardError => e
          totals["error"] += 1
          Rails.logger.error({ event: "retention.failed", person_id: person.id, error: e.class.name, message: e.message }.to_json)
        end
        purged_snippets += WebhookDelivery.where("updated_at < ?", as_of - WEBHOOK_SNIPPET_TTL)
                                          .where.not(response_snippet: [ nil, "" ])
                                          .update_all(response_snippet: nil)
      end
    end
    Rails.logger.info({ event: "retention.sweep", as_of: as_of, totals: totals,
                        purged_webhook_snippets: purged_snippets }.to_json)
    totals
  end
end
