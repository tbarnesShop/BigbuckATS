# frozen_string_literal: true

class Sequence < ApplicationRecord
  include HasUuid
  include TenantScoped

  has_many :enrollments, class_name: "SequenceEnrollment", dependent: :restrict_with_exception

  validates :key, :name, :steps, presence: true

  scope :templates, -> { where(is_template: true) }
  scope :shared_with_team, -> { where(shared: true) }
end
