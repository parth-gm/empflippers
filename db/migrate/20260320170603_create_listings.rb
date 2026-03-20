class CreateListings < ActiveRecord::Migration[8.0]
  def change
    create_table :listings do |t|
      t.string :listing_number, null: false
      t.decimal :listing_price, precision: 14, scale: 2
      t.text :summary
      t.string :listing_status
      t.string :hubspot_deal_id
      t.jsonb :raw_data, default: {}, null: false

      t.timestamps
    end
    add_index :listings, :listing_number, unique: true
    add_index :listings, :hubspot_deal_id
  end
end
