# frozen_string_literal: true

namespace :big_buck do
  desc "Seed the Big Buck org (100 people + admin/recruiter/hiring_manager/non-user)"
  task seed: :environment do
    result = BigBuckDataset.call(reset: ENV["RESET"].present?)
    payload = BigBuckDataset.fixture_payload(result)
    puts "Seeded #{payload['organization']['name']} (#{payload['organization']['id']})"
    puts "People: #{payload['people'].size}"
    puts "Applications: #{payload['applications'].size}  Offers: #{payload['offers'].size}"
    puts "Project members: #{payload['project_members'].size}"
    payload["users"].each do |role, user|
      puts "  #{role}: #{user['email']} (#{user['id']})"
    end
    puts "Expectations: #{payload['expectations'].inspect}"
  end

  desc "Add internal visibility to existing published Big Buck jobs without resetting the dataset"
  task seed_internal_openings: :environment do
    org = Organization.find_by!(slug: ENV.fetch("BIGBUCK_ORG_SLUG", BigBuckDataset::DEFAULT_SLUG))
    BigBuckDataset.seed_internal_openings!(organization: org)
    Current.set(organization_id: org.id) do
      puts "Internal openings for #{org.slug}: #{Job.on_careers('internal').pluck(:title).join(', ')}"
    end
  end

  desc "Seed Big Buck and write web/test/fixtures/bigbuck.json for UI e2e"
  task export_fixture: :environment do
    # Unique slug avoids destructive resets; rewrite IDs to stable demo values for the committed fixture.
    result = BigBuckDataset.call(slug: "big-buck-fixture-#{Time.now.to_i}", reset: false)
    payload = BigBuckDataset.stable_fixture_payload(result)
    path = Rails.root.join("web/test/fixtures/bigbuck.json")
    FileUtils.mkdir_p(path.dirname)
    File.write(path, JSON.pretty_generate(payload))
    puts "Wrote #{path} (#{payload['people'].size} people, #{payload['applications'].size} apps, #{payload['jobs'].size} jobs)"
  end
end
