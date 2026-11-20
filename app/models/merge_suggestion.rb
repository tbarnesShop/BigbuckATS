# frozen_string_literal: true

class MergeSuggestion < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :person_a, class_name: "Person"
  belongs_to :person_b, class_name: "Person"

  validates :reason, :status, presence: true
end
