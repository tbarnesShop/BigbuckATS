# frozen_string_literal: true

# Resolves notices/consents for the apply form and gates application create.
class ApplyCompliance
  Error = Class.new(StandardError)
  MissingConsent = Class.new(Error)
  MissingNotice = Class.new(Error)

  Result = Struct.new(:policies, :notices, :required_consents, :optional_consents, keyword_init: true)

  def self.requirements(person:, job:, locale: "en")
    new(person: person, job: job, locale: locale).requirements
  end

  def self.apply!(person:, job:, locale:, granted_purpose_keys:, ip_address: nil, user_agent: nil)
    new(person: person, job: job, locale: locale).apply!(
      granted_purpose_keys: granted_purpose_keys, ip_address: ip_address, user_agent: user_agent
    )
  end

  def initialize(person:, job:, locale:)
    @person = person
    @job = job
    @locale = locale
  end

  def requirements
    policies = CompliancePolicyMatcher.call(person: @person, job: @job, locale: @locale)
    notices = []
    required = []
    optional = []
    policies.each do |policy|
      policy.notices_req.each do |n|
        show = Array(n["show"] || n[:show]).map(&:to_s)
        next unless show.include?("apply-form") || show.include?("apply_form")

        notice = Notice.find_by!(key: n["notice"] || n[:notice])
        version = notice.latest_for(@locale)
        raise MissingNotice, notice.key unless version

        notices << { policy: policy, notice: notice, version: version, locale: version.locale }
      end
      policy.consents_req.each do |c|
        collect = (c["collect"] || c[:collect]).to_s
        next unless collect.in?(%w[apply-form apply_form])

        purpose = ConsentPurpose.find_by!(key: c["purpose"] || c[:purpose])
        entry = { policy: policy, purpose: purpose, required: ActiveModel::Type::Boolean.new.cast(c.fetch("required", c[:required])) }
        (entry[:required] ? required : optional) << entry
      end
    end
    Result.new(policies: policies, notices: notices.uniq { |n| n[:version].id }, required_consents: required, optional_consents: optional)
  end

  def apply!(granted_purpose_keys:, ip_address:, user_agent:)
    req = requirements
    granted = Array(granted_purpose_keys).map(&:to_s)
    missing = req.required_consents.reject { |c| granted.include?(c[:purpose].key) }
    raise MissingConsent, missing.map { |c| c[:purpose].key }.join(",") if missing.any?

    ActiveRecord::Base.transaction do
      req.notices.each do |n|
        NoticeReceipt.create!(
          person: @person,
          notice_version: n[:version],
          shown_via: "apply_form",
          locale: n[:locale],
          ip_address: ip_address,
          user_agent: user_agent,
          shown_at: Time.current,
          created_at: Time.current
        )
      end

      primary_notice = req.notices.first&.dig(:version)
      (req.required_consents + req.optional_consents).each do |c|
        next unless granted.include?(c[:purpose].key)

        Consent.create!(
          person: @person,
          consent_purpose: c[:purpose],
          notice_version: primary_notice,
          compliance_policy: c[:policy],
          lawful_basis: c[:purpose].lawful_basis,
          status: "granted",
          captured_via: "apply_form",
          captured_at: Time.current,
          ip_address: ip_address,
          user_agent: user_agent,
          evidence_json: { "locale" => @locale },
          created_at: Time.current
        )
      end

      ApplicationCreator.call(job: @job, person: @person)
    end
  end
end
