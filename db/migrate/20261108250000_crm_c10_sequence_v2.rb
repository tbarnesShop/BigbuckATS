# frozen_string_literal: true

# C10: sequences get an owner and a description; each queued send remembers the stable id of the
# step that produced it so per-step stats survive edits.
class CrmC10SequenceV2 < ActiveRecord::Migration[8.1]
  def change
    change_table :sequences, bulk: true do |t|
      t.text :description
      t.string :owner_user_id, limit: 36
    end
    add_column :scheduled_messages, :sequence_step_id, :string, limit: 64
    add_index :scheduled_messages, %i[organization_id sequence_enrollment_id sequence_step_id], name: "index_scheduled_messages_step"
  end
end
