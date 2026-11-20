# frozen_string_literal: true

class WebhookEndpoint < ApplicationRecord
  include HasUuid
  include TenantScoped

  has_many :webhook_deliveries, dependent: :destroy

  before_validation :generate_signing_key, on: :create
  validates :key, :url, :secret_ref, presence: true

  def signing_secret
    signing_encryptor.decrypt_and_verify(secret_ref.delete_prefix("enc:v1:")) if secret_ref.start_with?("enc:v1:")
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def rotate_signing_secret!
    secret = SecureRandom.urlsafe_base64(32)
    update!(secret_ref: "enc:v1:#{signing_encryptor.encrypt_and_sign(secret)}")
    secret
  end

  private

  def generate_signing_key
    self.secret_ref = "enc:v1:#{signing_encryptor.encrypt_and_sign(SecureRandom.urlsafe_base64(32))}"
  end

  def signing_encryptor
    ActiveSupport::MessageEncryptor.new(Rails.application.key_generator.generate_key("webhook-signing", 32))
  end

  public
  validates :key, uniqueness: { scope: :organization_id }

  def accepts?(event_type)
    event_types.nil? || Array(event_types).include?(event_type)
  end
end
