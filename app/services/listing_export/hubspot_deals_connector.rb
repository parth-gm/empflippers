# frozen_string_literal: true

module ListingExport
  class HubspotDealsConnector
    include Connector

    def name
      "HubSpot"
    end

    def enabled?
      ENV.fetch("HUBSPOT_API_KEY", "").to_s.strip.present?
    end

    def sync!
      HubSpot::SyncHubspotDealsService.call
    end
  end
end
