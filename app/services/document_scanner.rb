# frozen_string_literal: true

require "timeout"

# ClamAV exit codes: 0 verified clean, 1 infected, 2+ scanner failure. Lack of
# a scanner or definitions never makes a quarantined file downloadable.
class DocumentScanner
  def self.call(path, timeout: 30)
    raise ArgumentError, "scanner timeout must be between 0 and 30 seconds" unless timeout > 0 && timeout <= 30
    return "failed" if File.size(path) > 10 * 1024 * 1024
    executable = ENV.fetch("BIGBUCK_CLAMSCAN", "clamscan")
    arguments = [ "--no-summary", "--alert-exceeds-max=yes", "--max-scantime=30000",
      "--max-filesize=10M", "--max-scansize=30M", "--max-recursion=8", "--", path.to_s
    ]
    arguments.unshift("--database=#{ENV.fetch('BIGBUCK_CLAMAV_DATABASE')}") unless ENV.fetch("BIGBUCK_CLAMAV_DATABASE", "").empty?
    pid = Process.spawn(executable, *arguments, out: File::NULL, err: File::NULL)
    Timeout.timeout(timeout) do
      _, status = Process.wait2(pid)
      return "clean" if status.exitstatus == 0
      return "infected" if status.exitstatus == 1
      "failed"
    end
  rescue Timeout::Error
    Process.kill("KILL", pid)
    Process.wait(pid)
    "failed"
  rescue SystemCallError
    "failed"
  end
end
