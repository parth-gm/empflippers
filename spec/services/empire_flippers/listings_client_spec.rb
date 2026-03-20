# frozen_string_literal: true

require "rails_helper"

# Covers EmpireFlippers::ListingsClient in app/utils/empire_flippers/listings_client.rb
RSpec.describe EmpireFlippers::ListingsClient do
  let(:base_url) { "https://api.empireflippers.com" }
  let(:path) { "/api/v1/listings/list" }

  describe "#fetch_for_sale" do
    it "returns listings array from a single page response" do
      body = {
        data: {
          listings: [
            { listing_number: 80_294, listing_price: 100_000, summary: "Nice", listing_status: "For Sale" }
          ],
          pages: 1,
          page: 1,
          limit: 100
        }
      }
      stub_request(:get, "#{base_url}#{path}")
        .with(query: hash_including("page" => "1", "limit" => "100", "listing_status" => "For Sale"))
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: body.to_json)

      rows = described_class.new.fetch_for_sale

      expect(rows.size).to eq(1)
      expect(rows.first[:listing_number]).to eq(80_294)
      expect(rows.first[:summary]).to eq("Nice")
    end

    it "paginates correctly when multiple pages exist (rate-limit sleep between pages)" do
      stub_request(:get, "#{base_url}#{path}")
        .with(query: hash_including("page" => "1"))
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            data: {
              listings: [ { listing_number: 1, listing_price: 1, summary: "A", listing_status: "For Sale" } ],
              pages: 2,
              page: 1,
              limit: 100
            }
          }.to_json
        )

      stub_request(:get, "#{base_url}#{path}")
        .with(query: hash_including("page" => "2"))
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            data: {
              listings: [ { listing_number: 2, listing_price: 2, summary: "B", listing_status: "For Sale" } ],
              pages: 2,
              page: 2,
              limit: 100
            }
          }.to_json
        )

      rows = described_class.new.fetch_for_sale

      expect(rows.map { |r| r[:listing_number] }).to eq([ 1, 2 ])
      expect(WebMock).to have_requested(:get, "#{base_url}#{path}")
        .with(query: hash_including("page" => "1")).once
      expect(WebMock).to have_requested(:get, "#{base_url}#{path}")
        .with(query: hash_including("page" => "2")).once
    end

    it "returns empty array when API returns no listings" do
      stub_request(:get, "#{base_url}#{path}")
        .with(query: hash_including("page" => "1", "limit" => "100", "listing_status" => "For Sale"))
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { data: { listings: [], pages: 1, page: 1, limit: 100 } }.to_json
        )

      expect(described_class.new.fetch_for_sale).to eq([])
    end

    it "raises error on non-200 response" do
      stub_request(:get, %r{\A#{Regexp.escape(base_url)}#{Regexp.escape(path)}})
        .to_return(status: 503, body: "unavailable")

      expect { described_class.new.fetch_for_sale }.to raise_error(/503/)
    end
  end
end
