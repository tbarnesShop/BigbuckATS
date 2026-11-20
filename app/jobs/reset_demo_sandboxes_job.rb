class ResetDemoSandboxesJob < ApplicationJob
  queue_as :maintenance
  # Recurring every minute: only one refresh at a time. Overlapping runs were the stuck
  # "busy or refreshing" loop after an expired sandbox (InnoDB lock waits on wipe/copy).
  limits_concurrency to: 1, key: "reset_demo_sandboxes", duration: 30.minutes

  def perform
    return unless Rails.configuration.x.demo_sign_in
    DemoSandbox.where("resets_at <= ?", Time.current).pluck(:surface).each do |surface|
      DemoWorkspaces.prepare!(surface)
    rescue DemoWorkspaces::Error, ActiveRecord::LockWaitTimeout => error
      code = error.respond_to?(:code) ? error.code : "lock_wait_timeout"
      Rails.logger.info({ event: "demo.reset_deferred", surface: surface, code: code }.to_json)
    end
  end
end
