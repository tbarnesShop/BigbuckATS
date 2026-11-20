# frozen_string_literal: true

namespace :crm do
  desc "Answer unanswered mail in an org's Test mailboxes: ORG=<id> KIND=reply|bounce|auto_reply LIMIT=10"
  task simulate_replies: :environment do
    org = Organization.find(ENV.fetch("ORG"))
    kind = ENV.fetch("KIND", "reply")
    limit = ENV.fetch("LIMIT", "10").to_i
    Current.set(organization_id: org.id, actor_type: "system", source_surface: "automation") do
      total = Mailbox.where(provider: "sandbox").sum { |m| SandboxInbox.answer_unanswered!(mailbox: m, kind: kind, limit: limit).size }
      puts "Answered #{total} message(s) as #{kind}"
    end
  end

  desc "Seed a believable CRM database for the walkthrough: ORG=<organization id> [COUNT=300]. Refuses demo orgs and re-runs."
  task demo_seed: :environment do
    org = Organization.find(ENV.fetch("ORG"))
    abort "Refusing to seed a demo sandbox org" if org.respond_to?(:demo?) && org.demo?
    summary = CrmDemoSeed.call(organization: org, count: ENV.fetch("COUNT", "300").to_i)
    puts JSON.pretty_generate(summary.to_h)
  end
end
