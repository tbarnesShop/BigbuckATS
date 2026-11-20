# frozen_string_literal: true

class Organization < ApplicationRecord
  include HasUuid

  self.table_name = "organizations"

  has_many :memberships, dependent: :restrict_with_exception
  has_many :roles, dependent: :restrict_with_exception
  has_many :people, dependent: :restrict_with_exception
  has_many :companies, dependent: :restrict_with_exception
  has_many :dimensions, dependent: :restrict_with_exception
  has_many :audit_events, dependent: :restrict_with_exception
  has_many :outbox_events, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  def setting(key, default = nil)
    (settings || {}).deep_stringify_keys.fetch(key.to_s, default)
  end

  def hire_on_accept?
    ActiveModel::Type::Boolean.new.cast(setting("offers_hire_on_accept", false))
  end

  def hire_requires_accepted_offer?
    ActiveModel::Type::Boolean.new.cast(setting("hire_requires_accepted_offer", true))
  end

  # Careers page branding — hero photo URL is org config (not hardcoded in the web app).
  def careers_hero_image_url
    setting("careers_hero_image_url", "/careers-canopy.avif")
  end

  def careers_headline
    setting("careers_headline", "Open roles")
  end

  def careers_subcopy
    setting("careers_subcopy", "Build with us.")
  end

  # Optional titled careers sections ("about", "culture") shown above the open roles.
  CAREERS_SECTIONS = %w[about culture].freeze
  ACCENT_COLOR = /\A#\h{6}\z/

  def careers_section(key)
    title = setting("careers_#{key}_title").to_s.strip
    body = setting("careers_#{key}_body").to_s.strip
    return nil if title.empty? && body.empty?

    { "title" => title, "body" => body }
  end

  # Employer brand accent for the public careers page; nil keeps the app accent.
  def careers_accent_color
    value = setting("careers_accent_color").to_s
    value.match?(ACCENT_COLOR) ? value : nil
  end

  def contact_cooldown_days
    raw = setting("contact_cooldown_days", OutreachPolicy::DEFAULT_COOLDOWN_DAYS)
    [ [ raw.to_i, 0 ].max, 365 ].min
  end

  def merge_settings!(attrs)
    next_settings = (settings || {}).deep_stringify_keys.merge(attrs.deep_stringify_keys)
    update!(settings: next_settings)
  end
end
