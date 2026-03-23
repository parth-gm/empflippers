# frozen_string_literal: true

module ListingExport
  # Runs all registered connectors that are enabled (env-driven). Fail-fast on first error.
  class Orchestrator
    class << self
      def call(connectors: nil)
        new(connectors: connectors).call
      end
    end

    def initialize(connectors: nil)
      @connectors = connectors || default_connectors
    end

    def call
      @connectors.select(&:enabled?).each do |connector|
        ProgressLog.info("[ListingExport] #{connector.name} starting")
        connector.sync!
        ProgressLog.info("[ListingExport] #{connector.name} finished")
      end
    end

    def default_connectors
      [
        ListingExport::HubspotDealsConnector.new,
        ListingExport::GoogleSheetsConnector.new
      ]
    end
  end
end
