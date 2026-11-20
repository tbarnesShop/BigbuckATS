# frozen_string_literal: true

# Careers listings need a real job description, location and employment type; offers track the
# steps around the letter (references, verbal offer) that recruiters run outside the approval chain.
class AddPostingDetailsAndOfferChecklist < ActiveRecord::Migration[8.1]
  def change
    add_column :postings, :description, :text
    add_column :postings, :location, :string
    add_column :postings, :employment_type, :string
    add_column :offers, :checklist, :json
  end
end
