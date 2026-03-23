# frozen_string_literal: true

require "rails_helper"

RSpec.describe ListingExport::GoogleSheetsCredentials do
  describe ".json_string" do
    it "prefers base64 when set" do
      json = { "type" => "service_account" }.to_json
      with_env(
        "GOOGLE_SERVICE_ACCOUNT_JSON_BASE64" => Base64.strict_encode64(json),
        "GOOGLE_SERVICE_ACCOUNT_JSON" => "ignored"
      ) do
        expect(described_class.json_string).to eq(json)
      end
    end

    it "falls back to raw JSON" do
      with_env(
        "GOOGLE_SERVICE_ACCOUNT_JSON_BASE64" => "",
        "GOOGLE_SERVICE_ACCOUNT_JSON" => '{"x":1}'
      ) do
        expect(described_class.json_string).to eq('{"x":1}')
      end
    end
  end
end
