# frozen_string_literal: true

require "rails_helper"

RSpec.describe ListingExport::HubspotDealsConnector do
  describe "#enabled?" do
    it "is true when HUBSPOT_API_KEY is set" do
      with_env("HUBSPOT_API_KEY" => "secret") do
        expect(described_class.new.enabled?).to be true
      end
    end

    it "is false when HUBSPOT_API_KEY is blank" do
      with_env("HUBSPOT_API_KEY" => "") do
        expect(described_class.new.enabled?).to be false
      end
    end
  end

  describe "#sync!" do
    it "delegates to SyncHubspotDealsService" do
      with_env("HUBSPOT_API_KEY" => "x") do
        allow(HubSpot::SyncHubspotDealsService).to receive(:call)
        described_class.new.sync!
        expect(HubSpot::SyncHubspotDealsService).to have_received(:call)
      end
    end
  end
end
