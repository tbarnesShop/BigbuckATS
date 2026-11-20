# frozen_string_literal: true

require "test_helper"

class V1::TasksTest < ActionDispatch::IntegrationTest
  setup do
    @provisioned = OrganizationProvisioner.call(
      name: "TaskCo", slug: "t-#{SecureRandom.hex(3)}",
      owner_email: "o-#{SecureRandom.hex(3)}@t.test", owner_name: "Owner"
    )
    @org = @provisioned[:organization]
    @user = @provisioned[:user]
    Current.organization_id = @org.id
    Current.actor_id = @user.id
    @headers = { "X-Organization-Id" => @org.id, "X-Actor-Id" => @user.id }
    @person = PersonMatcher.find_or_create(display_name: "Tess", email: "tess@example.com",
      viewer: @provisioned[:membership]).person
    @mailbox = Mailbox.create!(kind: "personal", email: "rec@t.test", provider: "sandbox", status: "connected",
      secret_ref: "sandbox://mailbox", user: @user)
  end

  teardown { Current.reset }

  def idem = { "Idempotency-Key" => "k-#{SecureRandom.hex(4)}" }

  def create_task(**attrs)
    post "/v1/tasks", params: { task: { person_id: @person.id, title: "Call Tess", task_type: "call" }.merge(attrs) },
         headers: @headers.merge(idem), as: :json
    response.parsed_body
  end

  test "create defaults the assignee to me, and the Today panel lists mine due today including overdue" do
    due_now = create_task(due_at: 1.hour.from_now.iso8601)
    overdue = create_task(title: "Old", due_at: 2.days.ago.iso8601)
    create_task(title: "Later", due_at: 5.days.from_now.iso8601)
    assert_equal @user.id, due_now["assignee_user_id"]
    assert_equal true, overdue["overdue"]

    get "/v1/tasks", params: { assignee: "me", due: "today" }, headers: @headers
    assert_equal [ "Old", "Call Tess" ], response.parsed_body["data"].map { |t| t["title"] }
    get "/v1/tasks", params: { due: "upcoming" }, headers: @headers
    assert_equal [ "Later" ], response.parsed_body["data"].map { |t| t["title"] }
  end

  test "complete closes it, lands on the timeline and the person's activity" do
    id = create_task["id"]
    post "/v1/tasks/#{id}/complete", headers: @headers.merge(idem)
    assert_response :success
    assert_equal "completed", response.parsed_body["status"]
    assert TimelineEvent.exists?(person_id: @person.id, event_type: "task.completed")
    post "/v1/tasks/#{id}/complete", headers: @headers.merge(idem)
    assert_response :unprocessable_content
  end

  test "a sequence task step pauses the enrollment until the task is done" do
    sequence = Sequence.create!(key: "li", name: "LinkedIn touch", steps: [
      { "type" => "task", "title" => "Connect on LinkedIn", "task_type" => "linkedin" },
      { "type" => "email", "template_key" => "starter-intro" }
    ])
    enrollment = SequenceRunner.enroll!(sequence: sequence, person: @person, mailbox: @mailbox)
    task = SourcingTask.find_by!(sequence_enrollment_id: enrollment.id)
    assert task.pauses_enrollment
    assert_equal "linkedin", task.task_type
    assert_equal @user.id, task.assignee_user_id
    assert_equal 0, ScheduledMessage.where(sequence_enrollment_id: enrollment.id).count

    task.complete!
    assert_equal 1, ScheduledMessage.where(sequence_enrollment_id: enrollment.id, status: "sent").count
  end

  test "pause_until_done false keeps the old continue-through behaviour" do
    sequence = Sequence.create!(key: "fyi", name: "FYI", steps: [
      { "type" => "task", "title" => "FYI", "pause_until_done" => false },
      { "type" => "email", "template_key" => "starter-intro" }
    ])
    enrollment = SequenceRunner.enroll!(sequence: sequence, person: @person, mailbox: @mailbox)
    assert_equal 1, ScheduledMessage.where(sequence_enrollment_id: enrollment.id, status: "sent").count
  end

  test "stopping a paused enrollment cancels its task, and erasure scrubs task text" do
    sequence = Sequence.create!(key: "p", name: "P", steps: [ { "type" => "task", "title" => "Call Tess about Acme" } ])
    enrollment = SequenceRunner.enroll!(sequence: sequence, person: @person, mailbox: @mailbox)
    enrollment.stop!("reply")
    assert_equal "cancelled", SourcingTask.find_by!(sequence_enrollment_id: enrollment.id).status

    PersonEraser.call(person: @person, actor_id: @user.id)
    assert_equal [ "erased" ], SourcingTask.where(person_id: @person.id).pluck(:title).uniq
    assert_empty PersonEraser.verify(@person.reload)
  end
end
