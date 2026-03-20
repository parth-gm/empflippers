# frozen_string_literal: true

module HubSpot
  # For Sale listings without hubspot_deal_id → HubSpot deals (dedupe via id + deal name + lock + create rescue).
  class SyncHubspotDealsService
    class << self
      def call(deals_client: nil)
        new(deals_client: deals_client).call
      end
    end

    def initialize(deals_client: nil)
      @deals_client = deals_client || DealsClient.new
    end

    def call
      pending = Listing.pending_hubspot_sync.count
      ProgressLog.info("[HubSpot] start: #{pending} pending")

      linked = 0
      skipped = 0
      Listing.pending_hubspot_sync.find_each do |listing|
        listing.with_lock do
          listing.reload
          if listing.hubspot_deal_id.present?
            skipped += 1
            next
          end

          name = DealsClient.deal_name_for(listing)
          deal_id = @deals_client.find_deal_by_name(name) || @deals_client.create_deal(listing)
          listing.update!(hubspot_deal_id: deal_id)
          linked += 1
          ProgressLog.info("[HubSpot] listing ##{listing.listing_number} → deal #{deal_id}")
        end
      end

      ProgressLog.info("[HubSpot] done: linked #{linked}, skipped #{skipped}, pending #{Listing.pending_hubspot_sync.count}")
    end
  end
end
