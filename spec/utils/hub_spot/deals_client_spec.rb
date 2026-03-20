# frozen_string_literal: true

require "rails_helper"

# Covers HubSpot::DealsClient in app/utils/hub_spot/deals_client.rb
RSpec.describe HubSpot::DealsClient do
  let(:search_api) { double("SearchApi") }
  let(:basic_api) { double("BasicApi") }
  let(:deals) { double(search_api: search_api, basic_api: basic_api) }
  let(:crm) { double(deals: deals) }
  let(:hubspot_client) { double("Hubspot::Client", crm: crm) }

  subject(:client) { described_class.new(hubspot_client: hubspot_client) }

  describe "#create_deal" do
    let(:listing) { create(:listing, listing_number: "80294", listing_price: 250_000.5, summary: "Profitable FBA store") }

    it "sends dealname, amount, closedate, description; returns deal id" do
      travel_to Time.zone.parse("2025-06-15 12:00:00 UTC") do
        expected_closedate_ms = ((Time.current + 30.days).to_i * 1000).to_s
        created = double(id: "hs-deal-999")
        allow(basic_api).to receive(:create).and_return(created)

        deal_id = client.create_deal(listing)

        expect(deal_id).to eq("hs-deal-999")
        expect(basic_api).to have_received(:create) do |args|
          input = args[:simple_public_object_input_for_create]
          expect(input).to be_a(Hubspot::Crm::Deals::SimplePublicObjectInputForCreate)
          expect(input.properties["dealname"]).to eq("Listing #80294")
          expect(input.properties["amount"]).to eq("250000.5")
          expect(input.properties["closedate"]).to eq(expected_closedate_ms)
          expect(input.properties["description"]).to eq("Profitable FBA store")
        end
      end
    end

    it "on duplicate API error, finds existing deal by name and returns that id" do
      api_error = Class.new(StandardError) do
        attr_reader :code, :response_body
        def initialize(code:, message: "")
          @code = code
          @response_body = ""
          super(message)
        end
      end
      stub_const("Hubspot::Crm::Deals::ApiError", api_error)

      listing = create(:listing, listing_number: "555", listing_price: 1, summary: "x")
      row = double(id: "recovered-id")
      found = double(results: [ row ])
      err = Hubspot::Crm::Deals::ApiError.new(code: 409, message: "Conflict")

      allow(basic_api).to receive(:create).and_raise(err)
      allow(search_api).to receive(:do_search).and_return(found)

      expect(client.create_deal(listing)).to eq("recovered-id")
    end
  end

  describe "#find_deal_by_name" do
    it "returns deal id when HubSpot finds a match" do
      row = double(id: "existing")
      response = double(results: [ row ])
      allow(search_api).to receive(:do_search).and_return(response)

      expect(client.find_deal_by_name("Listing #1")).to eq("existing")
    end
  end

  describe ".build_default_client" do
    it "raises when HUBSPOT_API_KEY is missing" do
      previous = ENV.fetch("HUBSPOT_API_KEY", nil)
      ENV["HUBSPOT_API_KEY"] = ""
      expect { described_class.build_default_client }.to raise_error(HubSpot::DealsClient::MissingTokenError)
    ensure
      if previous
        ENV["HUBSPOT_API_KEY"] = previous
      else
        ENV.delete("HUBSPOT_API_KEY")
      end
    end
  end
end
