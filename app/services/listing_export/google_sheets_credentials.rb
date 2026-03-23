# frozen_string_literal: true

require "base64"
require "json"
require "stringio"

module ListingExport
  # Service account JSON from GOOGLE_SERVICE_ACCOUNT_JSON or GOOGLE_SERVICE_ACCOUNT_JSON_BASE64.
  # If both are set, uses the first that decodes to valid JSON (BASE64 tried first, then raw JSON).
  class GoogleSheetsCredentials
    class MissingCredentialsError < StandardError; end

    def self.json_string
      b64 = ENV["GOOGLE_SERVICE_ACCOUNT_JSON_BASE64"].to_s.strip
      if b64.present?
        begin
          decoded = Base64.decode64(b64)
          JSON.parse(decoded)
          return decoded
        rescue JSON::ParserError
          # Bad base64 payload — fall through to raw JSON
        end
      end

      json = ENV["GOOGLE_SERVICE_ACCOUNT_JSON"].to_s.strip
      return json if json.present?

      nil
    end

    def self.authorization
      json = json_string
      raise MissingCredentialsError, "Set GOOGLE_SERVICE_ACCOUNT_JSON or GOOGLE_SERVICE_ACCOUNT_JSON_BASE64" if json.blank?

      Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(json),
        scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS
      )
    end
  end
end
