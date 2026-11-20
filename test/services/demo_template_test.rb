require "test_helper"

class DemoTemplateTest < ActiveSupport::TestCase
  setup do
    @enabled = Rails.configuration.x.demo_sign_in
    Rails.configuration.x.demo_sign_in = true
    Current.reset
  end

  teardown do
    Rails.configuration.x.demo_sign_in = @enabled
    Current.reset
  end

  def refresh(surface)
    sandbox = DemoSandbox.find_or_create_by!(surface: surface)
    DemoWorkspaces.lock(surface) { DemoWorkspaces.refresh!(sandbox) }
    sandbox.reload
  end

  def age_snapshot!(by)
    DemoTemplateSnapshot.where(key: DemoTemplate::KEY).update_all(seeded_at: by.ago)
  end

  test "the template is a snapshot, never a live tenant" do
    before = Organization.count
    meta = DemoTemplate.ensure!
    assert_equal before, Organization.count, "the seeding tenant is rolled back"
    assert_equal DemoTemplate.fingerprint, meta.fingerprint
    assert_operator meta.row_count, :>, 1_000
  end

  test "two sandboxes copied from one snapshot match row for row and share no ids" do
    ui = refresh("ui")
    seeded_at = DemoTemplate.current.seeded_at
    tools = refresh("tools")

    assert_equal seeded_at, DemoTemplate.current.seeded_at, "the second sandbox reuses the snapshot"
    assert_empty DemoCopyCheck.count_differences(ui.organization_id, tools.organization_id)
    assert_equal 100, Person.unscoped.where(organization_id: tools.organization_id).count
    assert_empty DemoCopyCheck.orphans(ui.organization_id)
    assert_empty DemoCopyCheck.leaks(ui.organization_id, tools.organization_id)
    assert_equal "big-buck-lab-tools", Organization.find(tools.organization_id).slug
  end

  test "a refreshed sandbox replaces the old tenant" do
    first = refresh("ui")
    again = refresh("ui")
    refute_equal first.organization_id, again.organization_id
    assert_nil Organization.find_by(id: first.organization_id)
    assert_equal first.generation + 1, again.generation
  end

  test "the snapshot is rebuilt when the code that seeds it changes or it gets old" do
    first = DemoTemplate.ensure!.seeded_at
    assert_equal first, DemoTemplate.ensure!.seeded_at

    DemoTemplateSnapshot.where(key: DemoTemplate::KEY).update_all(fingerprint: "stale")
    rebuilt = DemoTemplate.ensure!
    assert_operator rebuilt.seeded_at, :>, first
    assert_equal DemoTemplate.fingerprint, rebuilt.fingerprint

    age_snapshot!(DemoTemplate::MAX_AGE + 1.hour)
    assert_operator DemoTemplate.ensure!.seeded_at, :>, 1.minute.ago
  end

  test "times move forward by the snapshot's age, rounded to the half hour, and ids move with them" do
    ui = refresh("ui")
    # Inside MAX_AGE, so the snapshot is reused; the 7 minutes round away so :00/:30 times stay put.
    age_snapshot!(15.hours + 7.minutes)
    tools = refresh("tools")

    millis = ->(id) { id.delete("-")[0, 12].to_i(16) }
    pick = lambda do |org|
      Person.unscoped.where(organization_id: org).pluck(:display_name, :primary_email, :id, :created_at).to_h { |n, e, *rest| [ [ n, e ], rest ] }
    end
    before = pick[ui.organization_id]
    after = pick[tools.organization_id]
    assert_equal before.keys.sort, after.keys.sort
    before.each do |name, (id, created_at)|
      new_id, new_created_at = after.fetch(name)
      # ui was copied moments after seeding (shift rounds to 0), tools as if the snapshot were 15h7m old.
      assert_in_delta 15.hours.to_f, new_created_at - created_at, 1.0
      assert_in_delta 15.hours.in_milliseconds, millis[new_id] - millis[id], 1_000
    end
  end

  test "sandboxes share résumé files, and a file outlives every wipe while the snapshot lists it" do
    attach = lambda do |org_id|
      Current.set(organization_id: org_id) do
        blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4 test"), filename: "cv.pdf", content_type: "application/pdf")
        doc = Document.create!(person: Person.first, filename: "cv.pdf", content_type: "application/pdf", byte_size: 13,
                               checksum: "x", storage_key: blob.key, scan_status: "clean", visibility: "internal")
        doc.file.attach(blob)
        blob
      end
    end
    # Make the seeder produce a file, as the enriched demo seeder does.
    seeder = Module.new do
      define_singleton_method(:name) { "SeederWithFile" }
      define_singleton_method(:call) do |slug:|
        BigBuckDataset.call(slug: slug).tap { |result| attach.call(result.organization.id) }
      end
    end
    DemoWorkspaces.singleton_class.alias_method(:original_seeder, :seeder)
    DemoWorkspaces.define_singleton_method(:seeder) { seeder }
    begin
      ui = refresh("ui")
      tools = refresh("tools")
    ensure
      DemoWorkspaces.singleton_class.alias_method(:seeder, :original_seeder)
    end

    blob_id = DemoTemplate.current.blob_ids.sole
    blob = ActiveStorage::Blob.find(blob_id)
    assert_equal 2, ActiveStorage::Attachment.where(blob_id: blob_id).count
    copied = Document.unscoped.find_by!(organization_id: tools.organization_id, storage_key: blob.key)
    assert_equal "%PDF-1.4 test", copied.file.download

    conn = ActiveRecord::Base.connection
    [ ui, tools ].each { |sandbox| DemoWorkspaces.wipe_organization!(conn, sandbox.organization_id) }
    conn.execute("SET FOREIGN_KEY_CHECKS=1")
    conn.execute("SET @bigbuck_audit_purge=NULL")
    assert ActiveStorage::Blob.exists?(blob_id), "the snapshot still lists the file"
    assert blob.service.exist?(blob.key)

    DemoTemplate.release_blobs!([ blob_id ]) # what a rebuild does with the old snapshot's files
    assert_not ActiveStorage::Blob.exists?(blob_id)
  end

  test "bearer credentials are never captured" do
    assert_includes DemoTemplate::SECRET_TABLES, "api_credentials"
    ui = refresh("ui")
    payload = DemoTemplate.payload(DemoTemplate.current)
    assert_empty payload["tables"].select { |table, *| DemoTemplate::SECRET_TABLES.include?(table) }
    assert_equal 0, ApiCredential.unscoped.where(organization_id: ui.organization_id).count
  end

  test "with BIGBUCK_DEMO_TEMPLATE=0 each sandbox is seeded directly" do
    ENV["BIGBUCK_DEMO_TEMPLATE"] = "0"
    sandbox = refresh("ui")
    assert_nil DemoTemplate.current
    assert_equal 100, Person.unscoped.where(organization_id: sandbox.organization_id).count
  ensure
    ENV.delete("BIGBUCK_DEMO_TEMPLATE")
  end
end
