# frozen_string_literal: true

# C6: sourcing_tasks become general follow-ups: a type (call / linkedin / email / other), an assignee
# user or agent, optional links to a pool member or application, and a flag for tasks that pause a
# sequence until they are done.
class CrmC6Tasks < ActiveRecord::Migration[8.1]
  def change
    change_table :sourcing_tasks, bulk: true do |t|
      t.string :task_type, null: false, default: "other"
      t.text :description
      t.string :assignee_agent_id, limit: 36
      t.string :application_id, limit: 36
      t.string :project_member_id, limit: 36
      t.string :created_by_user_id, limit: 36
      t.boolean :pauses_enrollment, null: false, default: false
    end
    add_index :sourcing_tasks, %i[organization_id assignee_user_id status due_at], name: "index_sourcing_tasks_queue"
    add_foreign_key :sourcing_tasks, :applications, column: %i[organization_id application_id],
      primary_key: %i[organization_id id], name: "fk_sourcing_tasks_applications_tenant"
    add_foreign_key :sourcing_tasks, :project_members, column: %i[organization_id project_member_id],
      primary_key: %i[organization_id id], name: "fk_sourcing_tasks_project_members_tenant"
  end
end
