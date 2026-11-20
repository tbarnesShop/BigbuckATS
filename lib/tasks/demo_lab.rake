namespace :demo do
  desc "Prepare the shared lab tenants (ui, tools); FORCE=1 refreshes ready ones too, FORCE_TEMPLATE=1 reseeds the template they copy"
  task prepare: :environment do
    DemoWorkspaces.retire_legacy!
    force = ENV["FORCE"] == "1"
    if DemoTemplate.enabled?
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      meta = DemoTemplate.ensure!(force: ENV["FORCE_TEMPLATE"] == "1")
      puts "template: #{meta.row_count} rows, #{(meta.byte_size / 1024.0).round}KB, seeded #{meta.seeded_at} " \
           "(ready in #{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)}s)"
    end
    DemoSandbox::SANDBOXES.each do |surface|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      attempts = 0
      begin
        sandbox = DemoWorkspaces.prepare!(surface, force: force)
      rescue DemoWorkspaces::Error => error
        raise unless error.code == "sandbox_busy" && (attempts += 1) <= 5

        puts "#{surface}: busy, retry #{attempts}/5"
        sleep 10
        retry
      end
      seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)
      puts "#{surface}: generation=#{sandbox.generation} state=#{sandbox.state} resets_at=#{sandbox.resets_at} in #{seconds}s"
    end
  end

  desc "Check the lab sandboxes after demo:prepare: no dangling references, no ids shared between them, row counts"
  task check: :environment do
    ids = DemoSandbox.where(surface: DemoSandbox::SANDBOXES).pluck(:surface, :organization_id).to_h.compact
    failed = false
    ids.each do |surface, org_id|
      orphans = DemoCopyCheck.orphans(org_id)
      failed ||= orphans.any?
      puts "#{surface}: #{orphans.empty? ? 'no dangling references' : "DANGLING #{orphans.join(', ')}"}"
    end
    if ids.size == 2
      a, b = ids.values
      leaks = DemoCopyCheck.leaks(a, b)
      failed ||= leaks.any?
      puts "shared ids: #{leaks.empty? ? 'none' : leaks}"
      # Differs once visitors have used a sandbox; identical straight after demo:prepare.
      differences = DemoCopyCheck.count_differences(a, b)
      puts "row counts: #{differences.empty? ? 'identical' : differences}"
    end
    abort "demo:check failed" if failed
  end
end
