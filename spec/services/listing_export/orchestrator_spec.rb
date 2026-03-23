# frozen_string_literal: true

require "rails_helper"

RSpec.describe ListingExport::Orchestrator do
  let(:alpha) { instance_double(ListingExport::HubspotDealsConnector, name: "Alpha", enabled?: true, sync!: nil) }
  let(:beta) { instance_double(ListingExport::GoogleSheetsConnector, name: "Beta", enabled?: false, sync!: nil) }
  let(:gamma) { instance_double(ListingExport::HubspotDealsConnector, name: "Gamma", enabled?: true, sync!: nil) }

  it "runs only enabled connectors in order" do
    described_class.new(connectors: [ alpha, beta, gamma ]).call

    expect(alpha).to have_received(:sync!).ordered
    expect(gamma).to have_received(:sync!).ordered
    expect(beta).not_to have_received(:sync!)
  end
end
