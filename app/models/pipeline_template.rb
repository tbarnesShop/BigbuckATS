# frozen_string_literal: true

class PipelineTemplate < ApplicationRecord
  include HasUuid
  include TenantScoped

  has_many :versions, class_name: "PipelineTemplateVersion", dependent: :destroy

  validates :key, :name, :object_type, presence: true
  validates :key, uniqueness: { scope: :organization_id }

  def publish!(stages:)
    next_version = published_version + 1
    version = versions.create!(
      version: next_version,
      stages: normalize_template_stages(stages),
      published_at: Time.current
    )
    update!(published_version: next_version)
    version
  end

  def latest_stages
    versions.find_by!(version: published_version).stages
  end

  private

  def normalize_template_stages(stages)
    Array(stages).map do |s|
      s = s.deep_stringify_keys
      {
        "key" => s.fetch("key"),
        "name" => s.fetch("name"),
        "type" => s.fetch("type"),
        "origin" => "template",
        "interviews" => Array(s["interviews"]).map { |i| i.deep_stringify_keys.merge("origin" => "template") }
      }
    end
  end
end
