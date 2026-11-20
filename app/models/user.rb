# frozen_string_literal: true

class User < ApplicationRecord
  include HasUuid

  has_many :memberships, dependent: :restrict_with_exception

  validates :email, :name, presence: true
  validates :email, uniqueness: true

  before_validation :normalize_email

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end
end
