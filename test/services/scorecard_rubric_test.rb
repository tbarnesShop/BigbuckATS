# frozen_string_literal: true

require "test_helper"

class ScorecardRubricTest < ActiveSupport::TestCase
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "RubricCo", slug: "rb-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@rb.test", owner_name: "Owner"
    )
    Current.organization_id = @provisioned[:organization].id
    Current.actor_id = @provisioned[:user].id

    ScorecardRubric.create!(
      key: "coding-rubric", name: "Coding",
      attributes_spec: [
        { "key" => "problem-solving", "name" => "Problem solving", "required" => true },
        { "key" => "communication", "name" => "Communication" },
        { "key" => "bonus", "name" => "Bonus", "required" => false }
      ]
    )

    template = PipelineTemplate.create!(key: "eng", name: "Eng", object_type: "job")
    template.publish!(stages: [
      { "key" => "onsite", "name" => "Onsite", "type" => "interview",
        "interviews" => [
          { "key" => "coding", "name" => "Coding", "required" => true, "rubric_key" => "coding-rubric" },
          { "key" => "chat", "name" => "Chat", "required" => false },
          { "key" => "ghost", "name" => "Ghost", "required" => false, "rubric_key" => "missing-rubric" }
        ] }
    ])
    job = Job.create!(title: "Eng", status: "active", pipeline: Pipeline.build_from_template!(template: template))
    application = ApplicationCreator.call(job: job, person: Person.create!(display_name: "Cand"))
    @interviewer = User.create!(email: "iv-#{SecureRandom.hex(2)}@rb.test", name: "IV")
    %w[coding chat ghost].each do |key|
      instance_variable_set(
        "@#{key}",
        Interview.create!(
          application: application, stage_key: "onsite", interview_key: key,
          status: "completed", interviewer_user_ids: [ @interviewer.id ]
        )
      )
    end
  end

  teardown { Current.reset }

  test "required_keys skips attributes marked optional" do
    rubric = ScorecardRubric.find_by!(key: "coding-rubric")
    assert_equal %w[problem-solving communication], rubric.required_keys
    assert_equal %w[problem-solving communication bonus], rubric.attribute_keys
  end

  test "a rubric needs at least one attribute with a unique key" do
    assert_not ScorecardRubric.new(key: "a", name: "A", attributes_spec: []).valid?
    assert_not ScorecardRubric.new(key: "a", name: "A", attributes_spec: [ { "name" => "No key" } ]).valid?
    duplicate = ScorecardRubric.new(key: "a", name: "A", attributes_spec: [ { "key" => "x" }, { "key" => "x" } ])
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:attributes_spec], "attribute keys must be unique"
  end

  test "submitting without every required rating is refused" do
    error = assert_raises(ArgumentError) do
      ScorecardSubmitter.call(interview: @coding, user: @interviewer, rating: "yes",
                              attribute_ratings: { "problem-solving" => 4 })
    end
    assert_match(/rubric_incomplete:communication/, error.message)
    assert_not Scorecard.exists?(interview_id: @coding.id)
  end

  test "submitting with every required rating stores them" do
    scorecard = ScorecardSubmitter.call(
      interview: @coding, user: @interviewer, rating: "yes",
      attribute_ratings: { "problem-solving" => 4, "communication" => 3 }
    )
    assert_equal "submitted", scorecard.status
    assert_equal({ "problem-solving" => 4, "communication" => 3 }, scorecard.reload.attribute_ratings)
  end

  test "an interview without a rubric behaves as before" do
    scorecard = ScorecardSubmitter.call(interview: @chat, user: @interviewer, rating: "yes", notes: "ok")
    assert_equal "submitted", scorecard.status
    assert_nil scorecard.reload.attribute_ratings
  end

  test "an interview naming a rubric that does not exist is refused" do
    error = assert_raises(ArgumentError) do
      ScorecardSubmitter.call(interview: @ghost, user: @interviewer, rating: "yes")
    end
    assert_match(/rubric_not_found:missing-rubric/, error.message)
  end
end
