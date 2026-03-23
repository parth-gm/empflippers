# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailySyncJob do
  describe "#perform" do
    it "calls SyncListingsService then ListingExport::Orchestrator" do
      listings_service = instance_double(EmpireFlippers::SyncListingsService, call: nil)

      allow(EmpireFlippers::SyncListingsService).to receive(:new).with(no_args).and_return(listings_service)
      allow(ListingExport::Orchestrator).to receive(:call)

      described_class.new.perform

      expect(listings_service).to have_received(:call)
      expect(ListingExport::Orchestrator).to have_received(:call)
    end
  end
end
