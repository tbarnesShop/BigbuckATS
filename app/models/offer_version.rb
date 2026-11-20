# frozen_string_literal: true

class OfferVersion < ApplicationRecord
  include HasUuid
  include TenantScoped

  APPROVAL_STATES = %w[not_required pending approved changes_requested carried_over].freeze

  belongs_to :offer
  belongs_to :approval_policy, optional: true
  belongs_to :offer_template, optional: true
  has_many :offer_documents, dependent: :destroy
  has_many :signature_requests, dependent: :destroy
  has_one :offer_response, dependent: :restrict_with_exception
  has_many :approvals, foreign_key: :entity_version_id, primary_key: :id, inverse_of: false, dependent: :nullify

  validates :version_number, :fields, :approval_state, presence: true
  validates :approval_state, inclusion: { in: APPROVAL_STATES }
end
