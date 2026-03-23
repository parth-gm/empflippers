# frozen_string_literal: true

require "faraday"
require "google/apis/sheets_v4"

# Read-only checks using credentials from ENV (no secrets in responses).
class IntegrationCheckService
  class << self
    def all
      {
        empire_flippers_api: empire_flippers_api,
        hubspot: hubspot,
        google_sheets: google_sheets
      }
    end

    # Public Marketplace API (no API key).
    def empire_flippers_api
      conn = Faraday.new(url: "https://api.empireflippers.com") do |f|
        f.request :url_encoded
        f.adapter Faraday.default_adapter
        f.headers["Accept"] = "application/json"
        f.headers["User-Agent"] = "EmpflippersIntegrationCheck/1.0"
      end
      resp = conn.get("/api/v1/listings/list") do |req|
        req.params[:page] = 1
        req.params[:limit] = 1
        req.params[:listing_status] = "For Sale"
      end
      unless resp.success?
        return { "status" => "error", "detail" => "HTTP #{resp.status}" }
      end

      payload = JSON.parse(resp.body)
      count = payload.dig("data", "listings")&.size || 0
      { "status" => "ok", "detail" => "Listings API OK (sample page has #{count} row(s))" }
    rescue JSON::ParserError => e
      { "status" => "error", "detail" => "Invalid JSON: #{e.message}" }
    rescue StandardError => e
      { "status" => "error", "detail" => "#{e.class}: #{e.message}" }
    end

    def hubspot
      key = ENV.fetch("HUBSPOT_API_KEY", "").to_s.strip
      return { "status" => "skip", "detail" => "HUBSPOT_API_KEY not set" } if key.blank?

      HubSpot::DealsClient.new.find_deal_by_name("__empflippers_connection_check_nonexistent__")
      { "status" => "ok", "detail" => "HubSpot deals search API responded (no deal expected)" }
    rescue HubSpot::DealsClient::MissingTokenError => e
      { "status" => "error", "detail" => e.message }
    rescue StandardError => e
      { "status" => "error", "detail" => "#{e.class}: #{e.message.to_s.truncate(300)}" }
    end

    def google_sheets
      json = ListingExport::GoogleSheetsCredentials.json_string
      return { "status" => "skip", "detail" => "No GOOGLE_SERVICE_ACCOUNT_JSON* in ENV" } if json.blank?

      auth = ListingExport::GoogleSheetsCredentials.authorization
      auth.fetch_access_token!

      sid = ListingExport::GoogleSheetsConnector.normalize_spreadsheet_id(ENV["GOOGLE_SHEETS_SPREADSHEET_ID"])
      if sid.blank?
        return { "status" => "ok", "detail" => "Service account OK (token issued); set GOOGLE_SHEETS_SPREADSHEET_ID to verify spreadsheet read" }
      end

      service = Google::Apis::SheetsV4::SheetsService.new
      service.authorization = auth
      meta = service.get_spreadsheet(sid, fields: "properties.title")
      title = meta.properties&.title || "(untitled)"
      { "status" => "ok", "detail" => "Spreadsheet readable: #{title.inspect}" }
    rescue ListingExport::GoogleSheetsCredentials::MissingCredentialsError => e
      { "status" => "error", "detail" => e.message }
    rescue StandardError => e
      { "status" => "error", "detail" => "#{e.class}: #{e.message.to_s.truncate(300)}" }
    end
  end
end
