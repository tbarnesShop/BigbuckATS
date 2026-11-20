# frozen_string_literal: true

class M5HolidaysRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :holidays, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :name, null: false
      t.date :observed_on, null: false
      t.string :location_key # nil = org-wide
      t.timestamps
    end
    add_index :holidays, %i[organization_id observed_on location_key], name: "index_holidays_on_day"
    add_index :holidays, %i[organization_id id], unique: true, name: "index_holidays_tenant_pk"
    add_foreign_key :holidays, :organizations, column: :organization_id

    create_table :rooms, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :key, null: false
      t.string :name, null: false
      t.string :resource_email, null: false
      t.string :location_key
      t.integer :capacity, null: false, default: 4
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :rooms, %i[organization_id key], unique: true
    add_index :rooms, %i[organization_id id], unique: true, name: "index_rooms_tenant_pk"
    add_foreign_key :rooms, :organizations, column: :organization_id

    create_table :interviewer_blocks, id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :organization_id, null: false, limit: 36
      t.string :user_id, null: false, limit: 36
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :reason
      t.timestamps
    end
    add_index :interviewer_blocks, %i[organization_id user_id starts_at], name: "index_interviewer_blocks_user"
    add_index :interviewer_blocks, %i[organization_id id], unique: true, name: "index_interviewer_blocks_tenant_pk"
    add_foreign_key :interviewer_blocks, :organizations, column: :organization_id
  end
end
