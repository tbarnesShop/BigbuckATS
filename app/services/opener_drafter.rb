# frozen_string_literal: true

# Drafts a one-sentence opener from what we actually know about the person: the evidence behind the
# criteria they met. Plain rules, no invented facts. A person approves (and may edit) it before use.
class OpenerDrafter
  def self.draft(person:, job:, verdicts: [], bucket: nil)
    first = person.display_name.to_s.split.first
    evidence = Array(verdicts).select { |v| v["met"] }.flat_map { |v| Array(v["evidence"]) }.first
    focus = evidence ? evidence.sub(/\A\w+:\s*…?/, "").sub(/…\z/, "").strip : person.headline.presence || person.current_title
    lead =
      case bucket
      when "silver_medalist" then "You were a strong candidate with us before, and"
      when "internal_transfer" then "Given your time with us,"
      else "I came across your profile and"
      end
    sentence = focus.present? ? "#{lead} your background (#{focus.first(90)}) stood out for our #{job.title} role." : "#{lead} thought you might be a fit for our #{job.title} role."
    "Hi #{first}, #{sentence}"
  end
end
