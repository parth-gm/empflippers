# frozen_string_literal: true

class RefactorListingsStatusNicheMonetization < ActiveRecord::Migration[8.0]
  def change
    add_column :listings, :niche, :string
    add_column :listings, :monetization, :string
    rename_column :listings, :listing_status, :status
  end
end
