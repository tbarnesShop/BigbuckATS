# frozen_string_literal: true

# Public apply against a posting. The posting id comes from the path; a body
# posting id cannot retarget it. Required standard fields come from the
# application form settings. Screening answers are custom fields flagged
# `show_on_apply` that are not limited to a role.
class CareersApplication
  def self.submit!(organization:, posting:, answers: {}, extras: {}, audience: "public")
    new(
      organization: organization, audience: audience,
      posting: posting,
      answers: stringify(answers),
      extras: stringify(extras)
    ).submit!
  end

  def self.stringify(hash)
    return {} if hash.blank?

    raw = hash.respond_to?(:to_unsafe_h) ? hash.to_unsafe_h : hash.to_h
    raw.stringify_keys
  end

  def initialize(organization:, posting:, answers:, extras:, audience:)
    @audience = audience
    @organization = organization
    @posting = posting
    @answers = answers
    @extras = extras
  end

  def submit!
    Application.transaction do
      job = @posting.job
      job.lock!
      @posting.reload
      raise ArgumentError, "posting_closed" unless job.organization_id == @organization.id && @posting.visible_to?(@audience)

      questions = ApplicationFormSettings.questions(public_form: true)
      required = Array(@organization.setting("application_required_fields", ApplicationFormSettings::DEFAULT_REQUIRED))
      missing = required.select { |field| blank?(value_for(field)) }
      missing += questions.select { |field| field.required && blank?(value_for(field.key)) }.map(&:key)
      raise ArgumentError, "missing_fields:#{missing.join(',')}" if missing.any?

      local_questions = PostingQuestions.definitions(@posting)
      local_answers = PostingQuestions.answers(local_questions, @answers)

      result = PersonMatcher.find_or_create(
        display_name: value_for("display_name"),
        email: value_for("email"),
        phone: value_for("phone"),
        url: value_for("linkedin").presence || value_for("links"),
        source: "applied"
      )
      person = result.person
      fill_place!(person)
      application = ApplicationCreator.call(job: job, person: person)
      snapshot = questions.map { |field| ApplicationFormSettings.question_json(field).merge("source" => "organization") } + local_questions
      baseline_answers = {}
      questions.each do |field|
        value = value_for(field.key)
        next if blank?(value)

        row = CustomFieldValues.write!(entity_type: "Application", entity_id: application.id, key: field.key, value: value)
        baseline_answers[field.key] = row.typed_value
      end
      application.update!(posting: @posting, application_form_snapshot: snapshot, application_answers: baseline_answers.merge(local_answers))
      {
        "application_id" => application.id,
        "person_id" => person.id,
        "attached" => result.attached,
        "held_duplicate" => result.held_duplicate,
        "posting_id" => @posting.id
      }
    end
  end

  private

  def fill_place!(person)
    attrs = {}
    country = value_for("country")
    region = value_for("region")
    attrs[:country] = country if country.present? && person.country.blank?
    attrs[:region] = region if region.present? && person.region.blank?
    person.update!(attrs) if attrs.any?
  end

  # Top-level fields win over the answers object, matching a flat form post.
  def value_for(field)
    return @extras[field] if @extras.key?(field) && !blank?(@extras[field])

    @answers[field]
  end

  def blank?(value)
    return false if value == false

    value.blank?
  end
end
