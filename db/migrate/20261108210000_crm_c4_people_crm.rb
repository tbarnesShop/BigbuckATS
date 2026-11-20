# frozen_string_literal: true

# C4: the person becomes a CRM record. Headline fields recruiters scan on, where the person came
# from (set once), and engagement fields a projector keeps current from communications.
class CrmC4PeopleCrm < ActiveRecord::Migration[8.1]
  def change
    change_table :people, bulk: true do |t|
      t.string :headline
      t.string :current_title
      t.string :current_company_id, limit: 36
      t.string :city
      t.string :time_zone
      t.string :source
      t.string :source_detail
      t.string :sourced_by_user_id, limit: 36
      t.datetime :sourced_at, precision: 6
      t.datetime :last_contacted_at, precision: 6
      t.datetime :last_replied_at, precision: 6
      t.datetime :last_activity_at, precision: 6
      t.string :engagement_status, null: false, default: "not_contacted"
    end
    add_index :people, %i[organization_id engagement_status], name: "index_people_engagement"
    add_index :people, %i[organization_id source], name: "index_people_source_kind"
    add_index :people, %i[organization_id last_contacted_at], name: "index_people_last_contacted"
    add_foreign_key :people, :companies, column: %i[organization_id current_company_id],
      primary_key: %i[organization_id id], name: "fk_people_current_company_tenant"

    reversible do |dir|
      dir.up do
        execute "UPDATE people SET engagement_status = 'do_not_contact' WHERE do_not_contact = 1"
        execute <<~SQL.squish
          UPDATE people p JOIN (
            SELECT organization_id, person_id,
                   MAX(CASE WHEN direction = 'outbound' THEN created_at END) AS contacted,
                   MAX(CASE WHEN direction = 'inbound' AND (classification IS NULL OR classification = 'interested') THEN created_at END) AS replied,
                   MAX(created_at) AS active
            FROM communications GROUP BY organization_id, person_id
          ) c ON c.organization_id = p.organization_id AND c.person_id = p.id
          SET p.last_contacted_at = c.contacted, p.last_replied_at = c.replied, p.last_activity_at = c.active,
              p.engagement_status = CASE
                WHEN p.engagement_status = 'do_not_contact' THEN 'do_not_contact'
                WHEN c.replied IS NOT NULL THEN 'replied'
                WHEN c.contacted IS NOT NULL THEN 'contacted'
                ELSE p.engagement_status END
        SQL
      end
    end
  end
end
