# frozen_string_literal: true

class Company < ApplicationRecord
  include HasUuid
  include TenantScoped

  has_many :affiliations, class_name: "PersonAffiliation", dependent: :restrict_with_exception

  validates :name, :normalized_name, presence: true

  before_validation :normalize_name

  private

  def normalize_name
    self.normalized_name = name.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end
