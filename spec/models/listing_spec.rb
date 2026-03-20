# frozen_string_literal: true

require "rails_helper"

RSpec.describe Listing, type: :model do
  describe "validations" do
    it "requires listing_number" do
      listing = build(:listing, listing_number: nil)
      expect(listing).not_to be_valid
    end

    it "enforces unique listing_number" do
      create(:listing, listing_number: "12345")
      dup = build(:listing, listing_number: "12345")
      expect(dup).not_to be_valid
    end
  end

  describe "scopes" do
    it ".for_sale returns only For Sale" do
      create(:listing, listing_number: "A1", status: "For Sale")
      create(:listing, listing_number: "A2", status: "Sold")
      expect(Listing.for_sale.pluck(:listing_number)).to eq([ "A1" ])
    end

    it ".pending_hubspot_sync returns for-sale rows without hubspot_deal_id" do
      create(:listing, listing_number: "B1", status: "For Sale", hubspot_deal_id: nil)
      create(:listing, listing_number: "B2", status: "For Sale", hubspot_deal_id: "hs-1")
      create(:listing, listing_number: "B3", status: "Sold", hubspot_deal_id: nil)
      expect(Listing.pending_hubspot_sync.pluck(:listing_number)).to eq([ "B1" ])
    end
  end
end
