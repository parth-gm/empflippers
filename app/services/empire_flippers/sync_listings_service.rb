# frozen_string_literal: true

module EmpireFlippers
  # Fetches via ListingsClient, upserts Listing rows (keeps existing hubspot_deal_id).
  class SyncListingsService
    class << self
      def call(client: ListingsClient.new)
        new(client: client).call
      end
    end

    def initialize(client: ListingsClient.new)
      @client = client
    end

    def call
      ProgressLog.info("[EmpireFlippers] SyncListingsService: upserting…")
      count = 0
      @client.fetch_for_sale.each do |attrs|
        upsert_listing(attrs)
        count += 1
      end
      ProgressLog.info("[EmpireFlippers] SyncListingsService: #{count} rows, For Sale in DB: #{Listing.for_sale.count}")
    end

    private

    def upsert_listing(attrs)
      number = extract_listing_number(attrs)
      return if number.blank?

      record = Listing.find_or_initialize_by(listing_number: number)
      record.assign_attributes(
        listing_price: extract_listing_price(attrs),
        summary: extract_summary(attrs),
        niche: extract_niche(attrs),
        monetization: extract_monetization(attrs),
        status: extract_status(attrs),
        raw_data: stringify_keys(attrs)
      )
      record.save!
    end

    def extract_listing_number(attrs)
      v = attrs[:listing_number] || attrs["listing_number"]
      v&.to_s&.strip
    end

    def extract_listing_price(attrs)
      v = attrs[:listing_price] || attrs["listing_price"]
      return if v.nil?

      BigDecimal(v.to_s)
    end

    def extract_summary(attrs)
      (attrs[:summary] || attrs["summary"]).to_s
    end

    def extract_niche(attrs)
      case (n = attrs[:niche] || attrs["niche"])
      when String then n.presence
      when Array then n.compact.map(&:to_s).join(" || ").presence
      else n&.to_s&.presence
      end
    end

    def extract_monetization(attrs)
      raw = attrs[:monetizations] || attrs["monetizations"]
      case raw
      when String then raw.presence
      when Array then raw.compact.map(&:to_s).join(" || ").presence
      else
        (attrs[:monetization] || attrs["monetization"]).to_s.presence
      end
    end

    def extract_status(attrs)
      (attrs[:listing_status] || attrs["listing_status"]).to_s.presence || ListingsClient::DEFAULT_LISTING_STATUS
    end

    def stringify_keys(hash)
      hash.deep_stringify_keys
    end
  end
end
