# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmpireFlippers::SyncListingsService do
  let(:client) { instance_double(EmpireFlippers::ListingsClient) }

  describe "#call" do
    it "creates new listings that do not exist in DB" do
      allow(client).to receive(:fetch_for_sale).and_return(
        [
          {
            listing_number: 11_111,
            listing_price: 50_000,
            summary: "New listing",
            listing_status: "For Sale",
            niche: "Pets",
            monetizations: "Amazon FBA"
          }
        ]
      )

      expect { described_class.new(client: client).call }.to change(Listing, :count).by(1)

      row = Listing.find_by!(listing_number: "11111")
      expect(row.listing_price).to eq(50_000)
      expect(row.summary).to eq("New listing")
      expect(row.status).to eq("For Sale")
      expect(row.niche).to eq("Pets")
      expect(row.monetization).to eq("Amazon FBA")
    end

    it "updates existing listings (find_or_initialize_by listing_number)" do
      existing = create(:listing, listing_number: "22222", summary: "old", listing_price: 1)

      allow(client).to receive(:fetch_for_sale).and_return(
        [
          {
            listing_number: 22_222,
            listing_price: 99_999,
            summary: "updated",
            listing_status: "For Sale"
          }
        ]
      )

      expect { described_class.new(client: client).call }.not_to change(Listing, :count)

      existing.reload
      expect(existing.summary).to eq("updated")
      expect(existing.listing_price).to eq(99_999)
    end

    it "does not create duplicate records for the same listing_number" do
      allow(client).to receive(:fetch_for_sale).and_return(
        [
          { listing_number: 3, listing_price: 100, summary: "first", listing_status: "For Sale" },
          { listing_number: 3, listing_price: 200, summary: "second", listing_status: "For Sale" }
        ]
      )

      expect { described_class.new(client: client).call }.to change(Listing, :count).by(1)
      expect(Listing.find_by(listing_number: "3").summary).to eq("second")
    end

    it "handles empty API response gracefully" do
      allow(client).to receive(:fetch_for_sale).and_return([])

      expect { described_class.new(client: client).call }.not_to change(Listing, :count)
    end

    it "does not clear hubspot_deal_id when updating" do
      allow(client).to receive(:fetch_for_sale).and_return(
        [ { listing_number: 99_001, listing_price: 1, summary: "x", listing_status: "For Sale" } ]
      )
      existing = create(:listing, listing_number: "99001", hubspot_deal_id: "deal-preserved")

      described_class.new(client: client).call

      expect(existing.reload.hubspot_deal_id).to eq("deal-preserved")
    end
  end

  describe ".call" do
    it "delegates to instance with default client" do
      fake_client = instance_double(EmpireFlippers::ListingsClient)
      allow(EmpireFlippers::ListingsClient).to receive(:new).with(no_args).and_return(fake_client)
      allow(fake_client).to receive(:fetch_for_sale).and_return([])

      described_class.call

      expect(fake_client).to have_received(:fetch_for_sale)
    end
  end
end
