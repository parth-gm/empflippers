# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailySyncJob do
  describe "#perform" do
    it "calls EmpireFlippers::SyncListingsService.new.call then HubSpot::SyncHubspotDealsService.new.call" do
      listings_service = instance_double(EmpireFlippers::SyncListingsService, call: nil)
      hubspot_service = instance_double(HubSpot::SyncHubspotDealsService, call: nil)

      allow(EmpireFlippers::SyncListingsService).to receive(:new).with(no_args).and_return(listings_service)
      allow(HubSpot::SyncHubspotDealsService).to receive(:new).with(no_args).and_return(hubspot_service)

      described_class.new.perform

      expect(listings_service).to have_received(:call)
      expect(hubspot_service).to have_received(:call)
    end
  end
end
