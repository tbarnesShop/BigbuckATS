# frozen_string_literal: true

# M9d: background work that actually runs.
# - sequence enrollments know when their next step is due
# - webhook deliveries retry with backoff and are created once per endpoint+event
# - import runs report progress while rows are processed in chunks
class M9dWorkers < ActiveRecord::Migration[8.1]
  def change
    add_column :sequence_enrollments, :next_run_at, :datetime
    add_index :sequence_enrollments, %i[status next_run_at], name: "index_sequence_enrollments_due"

    add_column :webhook_deliveries, :next_attempt_at, :datetime
    add_column :webhook_deliveries, :last_error, :string
    add_index :webhook_deliveries, %i[status next_attempt_at], name: "index_webhook_deliveries_due"
    add_index :webhook_deliveries, %i[organization_id webhook_endpoint_id outbox_event_id], unique: true,
                                                                                            name: "index_webhook_deliveries_once"

    add_column :import_runs, :processed_count, :integer, null: false, default: 0
    add_column :import_runs, :finished_at, :datetime
    add_index :import_rows, %i[import_run_id status], name: "index_import_rows_run_status"

    add_index :idempotency_keys, :created_at, name: "index_idempotency_keys_created_at"
  end
end
