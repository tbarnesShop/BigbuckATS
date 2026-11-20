# frozen_string_literal: true

require "test_helper"

class V1::NotesAndTagsTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "NoteCo", slug: "n-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@n.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    Current.organization_id = @org.id
    Current.actor_id = @provisioned[:user].id
    @headers = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @provisioned[:user].id }
    @person = PersonMatcher.find_or_create(display_name: "Nora", email: "nora@example.com",
      viewer: @provisioned[:membership]).person
  end

  teardown { Current.reset }

  def idem = { "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }

  test "notes: create, pin, list pinned first, and they reach the timeline and activity" do
    post "/v1/people/#{@person.id}/notes", params: { note: { body: "Strong on distributed systems" } }, headers: @headers.merge(idem), as: :json
    assert_response :created
    first = response.parsed_body
    assert_equal "Owner", first.dig("author", "name")

    post "/v1/people/#{@person.id}/notes", params: { note: { body: "Prefers remote", pinned: true } }, headers: @headers.merge(idem), as: :json
    get "/v1/people/#{@person.id}/notes", headers: @headers
    assert_equal [ "Prefers remote", "Strong on distributed systems" ], response.parsed_body["data"].map { |n| n["body"] }

    patch "/v1/notes/#{first['id']}", params: { note: { pinned: true } }, headers: @headers.merge(idem), as: :json
    assert_response :success
    assert TimelineEvent.where(person_id: @person.id, event_type: "note.created").count >= 2
    assert @person.reload.last_activity_at
  end

  test "a blank note is rejected and only the author deletes" do
    post "/v1/people/#{@person.id}/notes", params: { note: { body: "" } }, headers: @headers.merge(idem), as: :json
    assert_response :unprocessable_content

    note = PersonNote.create!(person: @person, body: "x", author_user_id: SecureRandom.uuid)
    delete "/v1/notes/#{note.id}", headers: @headers.merge(idem)
    assert_response :unprocessable_content
  end

  test "tags: names are unique ignoring case, tagging is idempotent, rename and merge keep people" do
    post "/v1/tags", params: { tag: { name: "Go", color: "#16a34a" } }, headers: @headers.merge(idem), as: :json
    assert_response :created
    go = response.parsed_body
    post "/v1/tags", params: { tag: { name: " go " } }, headers: @headers.merge(idem), as: :json
    assert_response :unprocessable_content

    2.times do
      post "/v1/people/#{@person.id}/tags", params: { tag_id: go["id"] }, headers: @headers.merge(idem), as: :json
      assert_response :created
    end
    assert_equal 1, PersonTag.where(person_id: @person.id).count

    post "/v1/people/#{@person.id}/tags", params: { name: "Golang" }, headers: @headers.merge(idem), as: :json
    golang = Tag.find_by!(normalized_name: "golang")
    post "/v1/tags/#{golang.id}/merge", params: { into_tag_id: go["id"] }, headers: @headers.merge(idem), as: :json
    assert_response :success
    assert_equal [ go["id"] ], PersonTag.where(person_id: @person.id).pluck(:tag_id)
    assert_nil Tag.find_by(id: golang.id)

    get "/v1/tags", headers: @headers
    assert_equal 1, response.parsed_body["data"].find { |t| t["id"] == go["id"] }["person_count"]

    delete "/v1/people/#{@person.id}/tags/#{go['id']}", headers: @headers.merge(idem)
    assert_response :no_content
    assert_equal 0, PersonTag.where(person_id: @person.id).count
  end

  test "bulk tag and untag" do
    other = PersonMatcher.find_or_create(display_name: "Owen", email: "owen@example.com", viewer: @provisioned[:membership]).person
    post "/v1/people/bulk", params: { bulk_action: "tag", person_ids: [ @person.id, other.id ], tag_name: "Silver" },
         headers: @headers.merge(idem), as: :json
    assert_response :success
    assert_equal 2, PersonTag.joins(:tag).where(tags: { normalized_name: "silver" }).count
    post "/v1/people/bulk", params: { bulk_action: "untag", person_ids: [ @person.id ], tag_name: "silver" },
         headers: @headers.merge(idem), as: :json
    assert_equal 1, PersonTag.count
  end

  test "erasing a person removes their notes and tags" do
    post "/v1/people/#{@person.id}/notes", params: { note: { body: "private" } }, headers: @headers.merge(idem), as: :json
    post "/v1/people/#{@person.id}/tags", params: { name: "x" }, headers: @headers.merge(idem), as: :json
    PersonEraser.call(person: @person, actor_id: @provisioned[:user].id)
    assert_equal 0, PersonNote.where(person_id: @person.id).count
    assert_equal 0, PersonTag.where(person_id: @person.id).count
    assert_empty PersonEraser.verify(@person.reload)
  end
end
