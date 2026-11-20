# frozen_string_literal: true

class PersonAffiliation < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :person
  belongs_to :company
end
