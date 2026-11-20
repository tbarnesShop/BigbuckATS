# frozen_string_literal: true

require "uri"
require "ipaddr"

# Shape-only check for a customer-supplied webhook URL, run when the endpoint is
# saved so a bad URL fails with a 422 instead of failing quietly on every
# delivery attempt. It deliberately does no DNS lookup: SafeHttp resolves the
# host, pins the address and re-checks it at send time, and stays the authority.
class WebhookUrl
  Invalid = Class.new(StandardError)

  MAX_LENGTH = 2048
  LOCAL_SUFFIXES = %w[.localhost .local .internal].freeze

  def self.validate!(raw)
    new(raw).validate!
  end

  def initialize(raw)
    @raw = raw.to_s.strip
  end

  def validate!
    raise Invalid, "url is required" if @raw.empty?
    raise Invalid, "url is too long" if @raw.length > MAX_LENGTH

    uri = parse
    raise Invalid, "url must use https" unless uri.is_a?(URI::HTTPS)
    raise Invalid, "url must include a host" if uri.hostname.to_s.empty?
    raise Invalid, "url must not include credentials" if uri.userinfo.present?

    host = uri.hostname.downcase
    raise Invalid, "url host is not allowed" if local_name?(host)

    ip = literal_ip(host)
    raise Invalid, "url host must be a public address" if ip && !SafeHttp.public_address?(ip.to_s)

    uri
  end

  private

  def parse
    URI.parse(@raw)
  rescue URI::InvalidURIError
    raise Invalid, "url is not valid"
  end

  def local_name?(host)
    host == "localhost" || LOCAL_SUFFIXES.any? { |suffix| host.end_with?(suffix) }
  end

  def literal_ip(host)
    IPAddr.new(host)
  rescue IPAddr::Error
    nil
  end
end
