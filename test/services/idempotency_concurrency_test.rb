require "test_helper"
require "timeout"

# Separate committed connections are essential: transactional fixtures would hide
# the organization lock from the second writer and cannot prove serialization.
class IdempotencyConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  class Writer < ActionController::API
    include IdempotentRequest

    def execute(&block)
      with_idempotency(&block)
    end

    def controller_name = "people"
  end

  test "simultaneous duplicates commit one mutation and replay the same response" do
    org = Organization.create!(name: "Concurrency", slug: "concurrency-#{SecureRandom.hex(6)}")
    ready = Queue.new
    start = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Current.set(organization_id: org.id, principal: Principal.legacy) do
            writer = Writer.new
            request = ActionDispatch::TestRequest.create
            request.env["REQUEST_METHOD"] = "POST"
            request.env["PATH_INFO"] = "/v1/people"
            request.env["action_dispatch.request.request_parameters"] = { "person" => { "display_name" => "Once" } }
            request.headers["Idempotency-Key"] = "concurrent-duplicate"
            writer.set_request!(request)
            writer.set_response!(ActionDispatch::TestResponse.create)
            ready << true
            start.pop
            writer.execute do
              person = Person.create!(display_name: "Once")
              writer.render json: { id: person.id }, status: :created
            end
            [ writer.response.status, JSON.parse(writer.response.body) ]
          end
        end
      end
    end
    Timeout.timeout(20) do
      2.times { ready.pop }
      2.times { start << true }
      results = threads.map(&:value)
      assert_equal results.first, results.last
      assert_equal 201, results.first.first
    end
    assert_equal 1, Person.unscoped.where(organization_id: org.id).count
    assert_equal 1, IdempotencyKey.unscoped.where(organization_id: org.id).count
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
    threads&.each(&:join)
    if org
      IdempotencyKey.unscoped.where(organization_id: org.id).delete_all
      Person.unscoped.where(organization_id: org.id).delete_all
      ActiveRecord::Base.connection.execute("SET @bigbuck_audit_purge = 1")
      begin
        AuditEvent.unscoped.where(organization_id: org.id).delete_all
      ensure
        ActiveRecord::Base.connection.execute("SET @bigbuck_audit_purge = 0")
      end
      org.destroy!
    end
    Current.reset
  end
end
