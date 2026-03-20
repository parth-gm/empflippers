# frozen_string_literal: true

require "hubspot-api-client"

# Eager-load deal models (gem does not load them all at require time).
require "hubspot/codegen/crm/deals/models/filter"
require "hubspot/codegen/crm/deals/models/filter_group"
require "hubspot/codegen/crm/deals/models/public_object_search_request"
require "hubspot/codegen/crm/deals/models/simple_public_object_input_for_create"

# Module HubSpot avoids clashing with gem module Hubspot.
module HubSpot
  # HTTP/API wrapper for HubSpot CRM deals (no domain logic).
  class DealsClient
    class MissingTokenError < StandardError; end

    def initialize(hubspot_client: nil)
      @hubspot = hubspot_client || self.class.build_default_client
    end

    def self.build_default_client
      token = ENV.fetch("HUBSPOT_API_KEY", "").to_s.strip
      raise MissingTokenError, "Set HUBSPOT_API_KEY in .env" if token.empty?

      ::Hubspot::Client.new(access_token: token)
    end

    def self.deal_name_for(listing)
      "Listing ##{listing.listing_number}"
    end

    def find_deal_by_name(name)
      filter = ::Hubspot::Crm::Deals::Filter.new(
        property_name: "dealname",
        operator: "EQ",
        value: name.to_s
      )
      group = ::Hubspot::Crm::Deals::FilterGroup.new(filters: [ filter ])
      request = ::Hubspot::Crm::Deals::PublicObjectSearchRequest.new(
        filter_groups: [ group ],
        limit: 1,
        properties: [ "dealname" ]
      )
      result = @hubspot.crm.deals.search_api.do_search(public_object_search_request: request)
      result.results&.first&.id
    end

    def create_deal(listing)
      input = build_create_input(listing)
      created = @hubspot.crm.deals.basic_api.create(simple_public_object_input_for_create: input)
      created.id
    rescue ::Hubspot::Crm::Deals::ApiError => e
      raise unless recoverable_duplicate_create?(e)

      existing_id = find_deal_by_name(self.class.deal_name_for(listing))
      raise e if existing_id.blank?

      existing_id
    end

    private

    def build_create_input(listing)
      props = {
        "dealname" => self.class.deal_name_for(listing),
        "amount" => format_amount(listing.listing_price),
        "closedate" => ((Time.current + 30.days).to_i * 1000).to_s,
        "description" => listing.summary.to_s
      }
      props["pipeline"] = ENV["HUBSPOT_DEAL_PIPELINE_ID"] if ENV["HUBSPOT_DEAL_PIPELINE_ID"].present?
      props["dealstage"] = ENV["HUBSPOT_DEAL_STAGE_ID"] if ENV["HUBSPOT_DEAL_STAGE_ID"].present?

      ::Hubspot::Crm::Deals::SimplePublicObjectInputForCreate.new(properties: props.compact)
    end

    def recoverable_duplicate_create?(error)
      code = error.code.to_i
      return true if [ 409, 422 ].include?(code)

      error.response_body.to_s.downcase.match?(/duplicate|already exists|conflict/)
    end

    def format_amount(value)
      return "0" if value.blank?

      value.to_d.to_s("F")
    end
  end
end
