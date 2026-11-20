# frozen_string_literal: true

# Renders an offer letter from a template; refuses when required tokens are missing.
class LetterGenerator
  def self.call(offer:, template:)
    new(offer: offer, template: template).call
  end

  def initialize(offer:, template:)
    @offer = offer
    @template = template
    @version = offer.current_version
  end

  def call
    html = MessageRenderer.render(@template.body, tokens)
    sha = Digest::SHA256.hexdigest(html)
    doc = OfferDocument.create!(
      offer_version: @version,
      kind: "letter",
      body_html: html,
      sha256: sha
    )
    @version.update!(offer_template: @template)
    doc
  end

  private

  def tokens
    person = @offer.application.person
    job = @offer.application.job
    fields = (@version.fields || {}).deep_stringify_keys
    out = {
      "candidate.display_name" => person.display_name,
      "candidate.preferred_name" => person.display_name,
      "job.title" => job.title
    }
    fields.each { |k, v| out["offer.fields.#{k}"] = money_field?(k, v) ? delimit(v) : v }
    out
  end

  MONEY_KEY = /salary|bonus|amount|compensation|stipend/

  # "180000" reads as a typo in a letter; "180,000" does not. The currency stays its own merge field.
  def money_field?(key, value)
    key.to_s.match?(MONEY_KEY) && value.to_s.match?(/\A\d+(\.\d+)?\z/)
  end

  def delimit(value)
    ActiveSupport::NumberHelper.number_to_delimited(value.to_s)
  end
end
