# frozen_string_literal: true

# All matching policies apply; fallback when none match. No policies → empty (nothing required).
class CompliancePolicyMatcher
  def self.call(person:, job: nil, locale: "en")
    new(person: person, job: job, locale: locale).call
  end

  def initialize(person:, job:, locale:)
    @person = person
    @job = job
    @locale = locale
  end

  def call
    policies = CompliancePolicy.order(priority: :desc, created_at: :asc).to_a
    return [] if policies.empty?

    context = build_context
    matched = policies.reject(&:is_fallback).select { |p| matches?(p, context) }
    return matched if matched.any?

    Array(policies.find(&:is_fallback))
  end

  private

  def build_context
    regions = []
    regions << @person.region if @person.region.present?
    regions.concat(CountryGroups.regions_for_country(@person.country)) if @person.country.present?
    {
      "candidate" => {
        "location" => {
          "country" => @person.country&.upcase,
          "region" => regions.uniq
        }.compact
      },
      "job" => @job ? { "id" => @job.id, "title" => @job.title } : {}
    }
  end

  def matches?(policy, context)
    conditions = policy.conditions
    return true if conditions.blank?

    # Dimension-style: candidate.location.region: [eu, eea]
    if conditions.is_a?(Hash) && !conditions.key?("op") && !conditions.key?(:op)
      conditions.deep_stringify_keys.all? { |path, expected| location_or_value_match?(path, expected, context) }
    else
      RuleEngine.evaluate(conditions, context)
    end
  end

  def location_or_value_match?(path, expected, context)
    actual = resolve(context, path)
    wanted = Array(expected).map { |v| v.to_s.downcase }
    actuals = Array(actual).map { |a| a.to_s.downcase }
    country = context.dig("candidate", "location", "country")&.upcase

    if path == "candidate.location.region"
      wanted.any? do |w|
        if CountryGroups::GROUPS.key?(w)
          actuals.include?(w) || (country && CountryGroups::GROUPS[w].include?(country))
        else
          actuals.include?(w) || w.upcase == country
        end
      end
    else
      (actuals & wanted).any?
    end
  end

  def resolve(context, path)
    path.split(".").reduce(context) { |acc, part| acc.is_a?(Hash) ? acc[part] : nil }
  end
end
