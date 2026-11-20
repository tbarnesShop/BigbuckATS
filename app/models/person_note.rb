# frozen_string_literal: true

# A recruiter's (or an agent's) note on a person. Visible to whoever can see the person.
class PersonNote < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :person

  validates :body, presence: true, length: { maximum: 20_000 }
end
