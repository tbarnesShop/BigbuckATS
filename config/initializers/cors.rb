# frozen_string_literal: true

# Remix on Vercel (and local web) call the Rails API. Origins come from WEB_ORIGINS
# (comma-separated). Localhost is always allowed in development/test.
allowed = ENV.fetch("WEB_ORIGINS", "")
  .split(",")
  .map(&:strip)
  .reject(&:blank?)

if Rails.env.local?
  allowed |= %w[
    http://127.0.0.1:44100
    http://localhost:44100
    http://127.0.0.1:3000
    http://localhost:3000
  ]
end

if allowed.any?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*allowed)

      resource "/v1/*",
        headers: :any,
        methods: %i[get post put patch delete options head],
        expose: %w[X-Request-Id],
        max_age: 600
    end
  end
elsif Rails.env.production?
  Rails.logger.warn("[cors] WEB_ORIGINS is unset; browser cross-origin calls to /v1 will be blocked")
end
