# frozen_string_literal: true

# Minimal Liquid-like {{ token }} renderer with an allowlist (no loops).
class MessageRenderer
  MissingToken = Class.new(StandardError)

  # escape: true for HTML output (letters); plain-text email passes escape: false so "O'Brien" stays "O'Brien".
  def self.render(template_string, tokens, escape: true)
    missing = []
    result = template_string.gsub(/\{\{\s*([\w.-]+)\s*\}\}/) do
      key = Regexp.last_match(1)
      if tokens.key?(key)
        escape ? ERB::Util.html_escape(tokens[key].to_s) : tokens[key].to_s
      else
        missing << key
        ""
      end
    end
    raise MissingToken, missing.uniq.join(", ") if missing.any?

    result
  end
end
