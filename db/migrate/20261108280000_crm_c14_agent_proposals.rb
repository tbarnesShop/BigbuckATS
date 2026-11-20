# frozen_string_literal: true

# C14: what a sourcing agent proposes (enroll this person, with this drafted opener) waits here for a
# human decision. Enrollments carry the accepted merge fields (the opener).
class CrmC14AgentProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_proposals, id: { type: :string, limit: 36 } do |t|
      t.string :organization_id, limit: 36, null: false
      t.string :agent_id, limit: 36, null: false
      t.string :on_behalf_of_user_id, limit: 36
      t.string :kind, null: false, default: "enrollment"
      t.string :job_id, limit: 36
      t.string :person_id, limit: 36, null: false
      t.string :sequence_id, limit: 36, null: false
      t.string :mailbox_id, limit: 36, null: false
      t.string :rediscovery_candidate_id, limit: 36
      t.string :status, null: false, default: "pending"
      t.text :draft_opener
      t.text :final_opener
      t.json :rationale, null: false
      t.string :decided_by_user_id, limit: 36
      t.datetime :decided_at, precision: 6
      t.string :decision_reason
      t.string :enrollment_id, limit: 36
      t.timestamps precision: 6
    end
    add_index :agent_proposals, %i[organization_id id], unique: true, name: "index_agent_proposals_tenant_pk"
    add_index :agent_proposals, %i[organization_id status created_at], name: "index_agent_proposals_queue"
    add_index :agent_proposals, %i[organization_id sequence_id person_id], name: "index_agent_proposals_person_sequence"
    add_foreign_key :agent_proposals, :organizations, name: "fk_agent_proposals_organizations"
    add_foreign_key :agent_proposals, :agents, column: %i[organization_id agent_id], primary_key: %i[organization_id id],
      name: "fk_agent_proposals_agents_tenant"
    add_foreign_key :agent_proposals, :people, column: %i[organization_id person_id], primary_key: %i[organization_id id],
      name: "fk_agent_proposals_people_tenant"
    add_foreign_key :agent_proposals, :sequences, column: %i[organization_id sequence_id], primary_key: %i[organization_id id],
      name: "fk_agent_proposals_sequences_tenant"
    add_foreign_key :agent_proposals, :mailboxes, column: %i[organization_id mailbox_id], primary_key: %i[organization_id id],
      name: "fk_agent_proposals_mailboxes_tenant"

    add_column :sequence_enrollments, :merge_fields, :json
  end
end
