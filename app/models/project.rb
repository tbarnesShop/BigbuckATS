# frozen_string_literal: true

class Project < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :pipeline, optional: true
  belongs_to :job, optional: true
  has_many :project_members, dependent: :restrict_with_exception

  validates :name, presence: true
end
