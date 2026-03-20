# frozen_string_literal: true

require "faraday"
require "json"

module EmpireFlippers
  # HTTP client for https://empireflippers.com/marketplace-api/ (no ActiveRecord).
  class ListingsClient
    BASE_URL = "https://api.empireflippers.com"
    PATH = "/api/v1/listings/list"
    DEFAULT_LISTING_STATUS = "For Sale"
    PAGE_LIMIT = 100
    RATE_LIMIT_SECONDS = 1.1

    def initialize(connection: nil, listing_status: DEFAULT_LISTING_STATUS)
      @connection = connection || build_connection
      @listing_status = listing_status
    end

    # Paginated GET; returns listing hashes (symbol keys). Respects API rate (~1 req/sec).
    def fetch_for_sale
      page = 1
      results = []
      ProgressLog.info("[EmpireFlippers] fetch start (status=#{@listing_status})")
      loop do
        ProgressLog.info("[EmpireFlippers] GET page #{page}")
        response = @connection.get(PATH) do |req|
          req.params[:page] = page
          req.params[:limit] = PAGE_LIMIT
          req.params[:listing_status] = @listing_status
        end

        raise "Empire Flippers API error: #{response.status} #{response.body}" unless response.success?

        payload = JSON.parse(response.body, symbolize_names: true)
        batch = payload.dig(:data, :listings) || []
        break if batch.empty?

        meta = payload[:data] || {}
        total_pages = meta[:pages].to_i
        label = total_pages.positive? ? total_pages.to_s : "?"
        ProgressLog.info("[EmpireFlippers] page #{page}/#{label}: +#{batch.size} (total #{results.size + batch.size})")

        results.concat(batch)

        break if total_pages.zero? || page >= total_pages

        page += 1
        sleep RATE_LIMIT_SECONDS
      end
      ProgressLog.info("[EmpireFlippers] fetch done: #{results.size} listings")
      results
    end

    private

    def build_connection
      Faraday.new(url: BASE_URL) do |f|
        f.request :url_encoded
        f.adapter Faraday.default_adapter
        f.headers["Accept"] = "application/json"
        f.headers["User-Agent"] = "EmpflippersRailsApp/1.0"
      end
    end
  end
end
