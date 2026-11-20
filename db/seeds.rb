# frozen_string_literal: true

# Idempotent Big Buck demo org used by the local UI and e2e fixtures.
# Development gets BigBuckDemoSeed = the deterministic BigBuckDataset base plus demo-quality enrichment
# (jobs, pipelines, templates, sequences, resumes, interviews, offers, ...). Test keeps the small base
# (enriched rows would leak into tests that run global workers); set BIGBUCK_DEMO_ENRICH=1/0 to override. Re-runnable:
#   bin/rails db:seed          # create or top up
#   RESET=1 bin/rails db:seed  # wipe the big-buck org and rebuild
#   FORCE=1 bin/rails db:seed  # re-run enrichment even if already applied
result = DemoWorkspaces.seeder.call(reset: ENV["RESET"].present?)
payload = BigBuckDataset.fixture_payload(result)

puts "Seeded #{payload['organization']['name']} (slug=#{payload['organization']['slug']})"
puts "  organization_id=#{payload['organization']['id']}"
payload["users"].each do |role, user|
  puts "  #{role}: #{user['email']} actor_id=#{user['id']}"
end
puts "  people=#{payload['people'].size}"
puts "  BIGBUCK_ORG_ID=#{payload['organization']['id']}"
puts "  BIGBUCK_ACTOR_ID=#{payload['users']['admin']['id']}  # admin; swap for recruiter/hiring_manager"
