# frozen_string_literal: true

class PersonTag < ApplicationRecord
  include HasUuid
  include TenantScoped

  belongs_to :person
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: %i[organization_id person_id] }
end
