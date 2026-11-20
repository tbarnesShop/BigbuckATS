# frozen_string_literal: true

# C9: a pool gets an owner, a description and an optional smart-pool saved search; a member gets a note.
class CrmC9PoolsV2 < ActiveRecord::Migration[8.1]
  def change
    change_table :projects, bulk: true do |t|
      t.text :description
      t.string :owner_user_id, limit: 36
      t.string :saved_search_id, limit: 36
    end
    change_table :project_members, bulk: true do |t|
      t.text :note
      t.string :added_by_user_id, limit: 36
    end
  end
end
