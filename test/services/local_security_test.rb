# frozen_string_literal: true

require "test_helper"

class LocalSecurityTest < ActiveSupport::TestCase
  test "recovery rejects storage keys that could escape isolated disk storage" do
    ErasureRecovery.validate_key!("abc123XYZ_opaque-key")
    [ "../../outside", "/absolute", "nested/key", "..\\outside", "", nil ].each do |key|
      assert_raises(LocalSecurity::Error) { ErasureRecovery.validate_key!(key) }
    end
  end

  test "audit purge restores the prior connection flag after failure" do
    connection = ActiveRecord::Base.connection
    connection.execute("SET @bigbuck_audit_purge=7")
    assert_raises(RuntimeError) do
      AuditPurge.with_access do
        assert_equal 1, connection.select_value("SELECT @bigbuck_audit_purge")
        raise "failed maintenance"
      end
    end
    assert_equal 7, connection.select_value("SELECT @bigbuck_audit_purge")
  ensure
    connection.execute("SET @bigbuck_audit_purge=NULL")
  end

  test "missing audit purge permission refuses demo reset before state changes" do
    organization = Organization.create!(name: "Existing demo", slug: "reset-#{SecureRandom.hex(4)}")
    sandbox = DemoSandbox.create!(surface: "tools", organization_id: organization.id, state: "ready", generation: 3)
    original = AuditPurge.method(:ensure_access!)
    AuditPurge.define_singleton_method(:ensure_access!) { raise AuditPurge::MaintenanceRequired }
    error = assert_raises(DemoWorkspaces::Error) { DemoWorkspaces.refresh!(sandbox) }
    assert_equal "maintenance_required", error.code
    assert_equal "ready", sandbox.reload.state
    assert_equal 3, sandbox.generation
    assert Organization.exists?(organization.id)
  ensure
    AuditPurge.define_singleton_method(:ensure_access!, original) if original
  end

  test "scanner kills and reaps a timed out process and rejects oversized raw files" do
    original = ENV["BIGBUCK_CLAMSCAN"]
    Tempfile.create("slow-scanner") do |script|
      path = script.path
      script.close
      File.write(path, "#!/bin/sh\nexec sleep 10\n")
      File.chmod(0700, path)
      ENV["BIGBUCK_CLAMSCAN"] = path
      Tempfile.create("scan-input") do |input|
        input.write("safe")
        input.flush
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        assert_equal "failed", DocumentScanner.call(input.path, timeout: 0.1)
        assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 3
        input.truncate(11 * 1024 * 1024)
        assert_equal "failed", DocumentScanner.call(input.path)
      end
    end
  ensure
    ENV["BIGBUCK_CLAMSCAN"] = original
  end
end
