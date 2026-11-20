require "test_helper"

# Review-only probes. Each assertion describes the desired secure behavior.
# IntegrationTest transactions roll back all database records after each probe.
class SecurityAuditRegressionTest < ActionDispatch::IntegrationTest
  setup do
    @old_header_auth = Rails.configuration.x.header_auth
    Rails.configuration.x.header_auth = false
    data = OrganizationProvisioner.call(name: "Review", slug: "review-#{SecureRandom.hex(5)}",
      owner_email: "review-#{SecureRandom.hex(5)}@example.test", owner_name: "Review")
    @org = data[:organization]
    Current.organization_id = @org.id
    Current.actor_id = data[:user].id
    @user = User.create!(email: "hm-#{SecureRandom.hex(5)}@example.test", name: "Reviewer")
    Membership.create!(user: @user, role: data[:roles].fetch("hiring_manager"), status: "active")
    token = CredentialIssuer.call(kind: "session", name: "Review probe", user: @user,
      expires_at: 5.minutes.from_now).token
    @headers = { "Authorization" => "Bearer #{token}" }
    template = PipelineTemplate.create!(key: "review", name: "Review", object_type: "job")
    template.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" } ])
    @job = Job.create!(title: "Confidential review job", confidential: true, code_name: "Review",
      pipeline: Pipeline.build_from_template!(template: template), status: "active")
    @person = Person.create!(display_name: "Restricted review candidate", visibility: "restricted",
      primary_email: "restricted@example.test")
    @application = ApplicationCreator.call(job: @job, person: @person)
    Current.reset
  end

  teardown do
    Rails.configuration.x.header_auth = @old_header_auth
    Current.reset
  end

  test "application endpoint hides restricted candidate email" do
    get "/v1/people/#{@person.id}", headers: @headers
    assert_response :not_found
    get "/v1/applications/#{@application.id}", headers: @headers
    refute_includes response.body, "restricted@example.test"
  end

  test "sync endpoint hides restricted candidate email" do
    get "/v1/sync/people", headers: @headers
    assert_response :success
    refute_includes response.body, "restricted@example.test"
  end

  test "job endpoint hides confidential jobs from hiring manager" do
    get "/v1/jobs/#{@job.id}", headers: @headers
    assert_includes [ 403, 404 ], response.status
  end

  test "offer endpoint omits compensation without compensation permission" do
    Current.set(organization_id: @org.id) do
      @person.update!(visibility: "public")
      @job.update!(confidential: false)
      @offer = OfferSubmitter.create_draft!(application: @application,
        fields: { "base-salary" => 123456, "currency" => "USD" })
    end
    get "/v1/offers/#{@offer.id}", headers: @headers
    assert_response :success
    refute_includes response.body, "123456"
  end

  test "person erasure removes generated letter content and free text reasons" do
    Current.set(organization_id: @org.id) do
      @person.update!(do_not_contact_reason: "Private medical detail")
      offer = OfferSubmitter.create_draft!(application: @application, fields: { "base-salary" => 123456 })
      template = OfferTemplate.create!(key: "review-letter", name: "Review letter", body: "Dear {{ candidate.display_name }}")
      document = LetterGenerator.call(offer: offer, template: template)
      PersonEraser.call(person: @person)
      assert_empty PersonEraser.verify(@person)
      refute_includes document.reload.body_html, "Restricted review candidate"
      assert_nil @person.reload.do_not_contact_reason
    end
  end
end
