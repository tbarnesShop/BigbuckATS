# frozen_string_literal: true

namespace :tenant do
  desc "Fail if a TenantScoped model query can run without organization_id in source conventions"
  task check: :environment do
    Rails.application.eager_load!
    models = ApplicationRecord.descendants.select { |m| m.included_modules.include?(TenantScoped) }
    abort "No TenantScoped models loaded" if models.empty?

    missing = models.reject { |m| m.column_names.include?("organization_id") }
    abort "TenantScoped models missing organization_id: #{missing.map(&:name).join(', ')}" if missing.any?

    puts "tenant:check OK (#{models.map(&:name).sort.join(', ')})"
  end
end
