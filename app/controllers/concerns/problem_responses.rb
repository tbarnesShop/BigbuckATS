# frozen_string_literal: true

# RFC 9457 problem+json errors with a stable code and request_id.
module ProblemResponses
  extend ActiveSupport::Concern

  private

  def render_problem(status:, code:, title:, detail: nil, param: nil)
    body = {
      type: "https://bigbuck.dev/problems/#{code}",
      title: title,
      status: Rack::Utils.status_code(status),
      code: code,
      request_id: Current.request_id || request.request_id
    }
    body[:detail] = detail if detail
    body[:param] = param if param

    render json: body, status: status, content_type: "application/problem+json"
  end
end
