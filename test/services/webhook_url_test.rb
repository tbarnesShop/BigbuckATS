# frozen_string_literal: true

require "test_helper"

class WebhookUrlTest < ActiveSupport::TestCase
  test "accepts a public https url" do
    assert WebhookUrl.validate!("https://hooks.example.test/events")
    assert WebhookUrl.validate!("https://8.8.8.8/events")
  end

  test "rejects anything that is not https" do
    %w[http://hooks.example.test/events ftp://hooks.example.test file:///etc/passwd].each do |url|
      assert_raises(WebhookUrl::Invalid, url) { WebhookUrl.validate!(url) }
    end
  end

  test "rejects local and private hosts" do
    [
      "https://localhost/hook", "https://api.localhost/hook", "https://printer.local/hook",
      "https://db.internal/hook", "https://127.0.0.1/hook", "https://10.0.0.5/hook",
      "https://192.168.1.10/hook", "https://169.254.169.254/latest", "https://[::1]/hook"
    ].each do |url|
      assert_raises(WebhookUrl::Invalid, url) { WebhookUrl.validate!(url) }
    end
  end

  test "rejects credentials, blanks and over-long urls" do
    assert_raises(WebhookUrl::Invalid) { WebhookUrl.validate!("https://user:pw@hooks.example.test/x") }
    assert_raises(WebhookUrl::Invalid) { WebhookUrl.validate!("") }
    assert_raises(WebhookUrl::Invalid) { WebhookUrl.validate!(nil) }
    assert_raises(WebhookUrl::Invalid) { WebhookUrl.validate!("https://hooks.example.test/#{'a' * 2100}") }
    assert_raises(WebhookUrl::Invalid) { WebhookUrl.validate!("https://") }
  end
end
