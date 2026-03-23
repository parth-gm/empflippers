# frozen_string_literal: true

module ListingExport
  # Implement: #name, #enabled?, #sync!
  module Connector
    def name
      raise NotImplementedError
    end

    def enabled?
      raise NotImplementedError
    end

    def sync!
      raise NotImplementedError
    end
  end
end
