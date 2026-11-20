# frozen_string_literal: true

class Person < ApplicationRecord
  include HasUuid
  include TenantScoped

  after_update_commit :stop_sequences_on_do_not_contact

  def stop_sequences_on_do_not_contact
    return unless saved_change_to_do_not_contact? && do_not_contact

    EnrollmentStopper.call(person: self, reason: "do_not_contact")
  end

  self.table_name = "people"

  SOURCES = %w[sourced referral applied event import agent].freeze
  ENGAGEMENT_STATUSES = %w[not_contacted contacted replied interested not_interested do_not_contact].freeze
  # Statuses a person can be set to by hand; the rest are earned or follow the do-not-contact flag.
  MANUAL_ENGAGEMENT = %w[not_contacted contacted replied interested not_interested].freeze

  LIFECYCLES = %w[prospect candidate employee alumni].freeze
  VISIBILITIES = %w[public restricted confidential private].freeze

  has_many :contact_points, class_name: "PersonContactPoint", dependent: :destroy
  has_many :affiliations, class_name: "PersonAffiliation", dependent: :destroy
  has_many :documents, dependent: :destroy

  validates :display_name, presence: true
  validates :lifecycle_stage, inclusion: { in: LIFECYCLES }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :source, inclusion: { in: SOURCES }, allow_nil: true
  validates :engagement_status, inclusion: { in: ENGAGEMENT_STATUSES }
  validate :source_is_set_once, on: :update

  belongs_to :current_company, class_name: "Company", optional: true

  before_save :follow_do_not_contact

  scope :not_merged, -> { where(merged_into_id: nil) }
  scope :not_erased, -> { where(erased_at: nil) }
  scope :visible_catalog, -> { not_merged.not_erased }

  # Where a person came from is recorded once and survives conversion, so source-of-hire stays true.
  def source_is_set_once
    return unless source_changed? && source_was.present?

    errors.add(:source, "is already set and cannot change")
  end

  # The flag and the status agree: flagging wins; clearing the flag returns to what the history shows.
  def follow_do_not_contact
    if do_not_contact
      self.engagement_status = "do_not_contact"
    elsif engagement_status == "do_not_contact"
      self.engagement_status = last_replied_at ? "replied" : (last_contacted_at ? "contacted" : "not_contacted")
    end
  end

  def employee_or_alumni?
    lifecycle_stage.in?(%w[employee alumni])
  end

  def restricted?
    visibility != "public"
  end

  # Region is what the person gave; country groups expand shorthand in policies.
  def location_context
    {
      "country" => country,
      "region" => region
    }.compact
  end

  def erased?
    erased_at.present?
  end
end
