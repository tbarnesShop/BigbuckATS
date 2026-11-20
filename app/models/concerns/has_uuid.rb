# frozen_string_literal: true

module HasUuid
  extend ActiveSupport::Concern

  included do
    before_create :assign_uuid
  end

  private

  def assign_uuid
    self.id ||= Id.generate
  end
end
