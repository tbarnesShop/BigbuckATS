# frozen_string_literal: true

require "stringio"

class RequestSecurity
  MAX_BODY = 1_048_576
  EDGE_HEADER = "HTTP_X_BIGBUCK_EDGE"
  # Paths a load balancer or uptime check may call without the edge secret.
  EDGE_OPEN_PATHS = %w[/up].freeze

  def initialize(app) = @app = app
  def call(env)
    return edge_refused unless edge_allowed?(env)

    input = env["rack.input"]
    if input
      return too_large if env["CONTENT_LENGTH"].to_i > MAX_BODY
      bytes = input.read(MAX_BODY + 1).to_s
      return too_large if bytes.bytesize > MAX_BODY
      env["rack.input"] = StringIO.new(bytes)
    end
    status, headers, body = @app.call(env)
    headers["x-content-type-options"] = "nosniff"
    headers["referrer-policy"] = "no-referrer"
    headers["cache-control"] = "private, no-store" if env["PATH_INFO"].start_with?("/v1/", "/graphql")
    [ status, headers, body ]
  end
  private

  # When BIGBUCK_EDGE_SECRET is set (the API is reachable from the internet so the Vercel-hosted web app
  # can call it), every request must carry the shared secret. Only that web app and the lab's CLI/MCP
  # child processes hold it; anyone else is refused before routing.
  def edge_allowed?(env)
    secret = ENV["BIGBUCK_EDGE_SECRET"].to_s
    return true if secret.empty? || EDGE_OPEN_PATHS.include?(env["PATH_INFO"])

    given = env[EDGE_HEADER].to_s
    given.bytesize == secret.bytesize && ActiveSupport::SecurityUtils.secure_compare(given, secret)
  end

  def edge_refused
    [ 403, { "content-type" => "application/problem+json", "cache-control" => "private, no-store" },
      [ { status: 403, code: "edge_required" }.to_json ] ]
  end

  def too_large
    [ 413, { "content-type" => "application/problem+json", "cache-control" => "private, no-store" },
      [ { status: 413, code: "request_too_large" }.to_json ] ]
  end
end
