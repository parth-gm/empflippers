# frozen_string_literal: true

require "rails_helper"

RSpec.describe HubSpot::SyncHubspotDealsService do
  let(:deals_client) { instance_spy(HubSpot::DealsClient) }

  describe "#call" do
    it "only processes listings with status For Sale and blank hubspot_deal_id" do
      create(:listing, listing_number: "F1", status: "For Sale", hubspot_deal_id: nil)
      create(:listing, listing_number: "S1", status: "Sold", hubspot_deal_id: nil)
      create(:listing, listing_number: "F2", status: "For Sale", hubspot_deal_id: "has-id")

      allow(deals_client).to receive(:find_deal_by_name).and_return(nil)
      allow(deals_client).to receive(:create_deal).and_return("hs-1")

      described_class.new(deals_client: deals_client).call

      expect(deals_client).to have_received(:find_deal_by_name).with("Listing #F1").once
      expect(deals_client).to have_received(:create_deal).once
      expect(Listing.find_by(listing_number: "F1").hubspot_deal_id).to eq("hs-1")
    end

    it "skips listings that already have hubspot_deal_id" do
      create(:listing, listing_number: "X1", status: "For Sale", hubspot_deal_id: "existing")

      described_class.new(deals_client: deals_client).call

      expect(deals_client).not_to have_received(:find_deal_by_name)
      expect(deals_client).not_to have_received(:create_deal)
    end

    it "saves returned deal_id to listing.hubspot_deal_id" do
      listing = create(:listing, listing_number: "777", status: "For Sale", hubspot_deal_id: nil)
      allow(deals_client).to receive(:find_deal_by_name).with("Listing #777").and_return(nil)
      allow(deals_client).to receive(:create_deal).with(listing).and_return("new-hs-id")

      described_class.new(deals_client: deals_client).call

      expect(listing.reload.hubspot_deal_id).to eq("new-hs-id")
    end

    it "reuses existing HubSpot deal when find_deal_by_name returns an id" do
      listing = create(:listing, listing_number: "888", status: "For Sale", hubspot_deal_id: nil)
      allow(deals_client).to receive(:find_deal_by_name).and_return("from-search")
      allow(deals_client).to receive(:create_deal)

      described_class.new(deals_client: deals_client).call

      expect(deals_client).not_to have_received(:create_deal)
      expect(listing.reload.hubspot_deal_id).to eq("from-search")
    end

    it "skips HubSpot calls if reload shows hubspot_deal_id already set (e.g. another worker)" do
      listing = create(:listing, listing_number: "RACE", status: "For Sale", hubspot_deal_id: nil)
      relation = Listing.where(id: listing.id)
      allow(Listing).to receive(:pending_hubspot_sync).and_return(relation)
      allow(relation).to receive(:find_each).and_yield(listing)

      allow(listing).to receive(:with_lock).and_yield
      allow(listing).to receive(:reload) do
        listing.assign_attributes(hubspot_deal_id: "other-worker")
        listing
      end

      described_class.new(deals_client: deals_client).call

      expect(deals_client).not_to have_received(:find_deal_by_name)
      expect(deals_client).not_to have_received(:create_deal)
    end

    it "does not call HubSpot client methods when no eligible listings exist" do
      create(:listing, status: "Sold", hubspot_deal_id: nil)
      create(:listing, status: "For Sale", hubspot_deal_id: "x")

      described_class.new(deals_client: deals_client).call

      expect(deals_client).not_to have_received(:find_deal_by_name)
      expect(deals_client).not_to have_received(:create_deal)
    end
  end
end
