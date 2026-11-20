class AddJobCareersVisibility < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :careers_visibility, :string, null: false, default: "public"
  end
end
