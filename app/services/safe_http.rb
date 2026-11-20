# frozen_string_literal: true

require "net/http"
require "resolv"
require "ipaddr"

# Outbound HTTP for customer-supplied URLs (webhooks). Refuses hosts that resolve
# to private, loopback, link-local or metadata addresses, never follows
# redirects, caps time, and reads only the first bytes of the response.
class SafeHttp
  Refused = Class.new(StandardError)

  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 7
  SNIPPET_BYTES = 500
  BLOCKED = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
    192.0.0.0/24 192.168.0.0/16 198.18.0.0/15 224.0.0.0/4 240.0.0.0/4
    ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8
  ].map { |cidr| IPAddr.new(cidr) }.freeze

  def self.public_address?(address)
    ip = IPAddr.new(address)
    ip = ip.native if ip.ipv4_mapped?
    BLOCKED.none? { |range| range.include?(ip) }
  rescue IPAddr::InvalidAddressError
    false
  end

  def post(url, body:, headers:)
    uri = URI.parse(url)
    raise Refused, "only https URLs are allowed" unless uri.is_a?(URI::HTTPS)

    addresses = Resolv.getaddresses(uri.host)
    raise Refused, "#{uri.host} does not resolve" if addresses.empty?
    unless addresses.all? { |a| self.class.public_address?(a) }
      raise Refused, "#{uri.host} resolves to a non-public address"
    end

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ipaddr = addresses.first # connect to the address we checked
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    http.write_timeout = READ_TIMEOUT

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = body
    status = nil
    snippet = +""
    http.request(request) do |response|
      status = response.code.to_i
      response.read_body { |chunk| snippet << chunk if snippet.bytesize < SNIPPET_BYTES }
    end
    { status: status, body: snippet.byteslice(0, SNIPPET_BYTES).to_s.scrub }
  end
end
