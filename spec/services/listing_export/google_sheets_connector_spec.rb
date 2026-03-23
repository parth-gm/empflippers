# frozen_string_literal: true

require "rails_helper"

RSpec.describe ListingExport::GoogleSheetsConnector do
  describe "HEADERS" do
    it "matches required column titles" do
      expect(described_class::HEADERS).to eq([ "Listing #", "Listing Price", "Summary" ])
    end
  end

  describe "#enabled?" do
    it "is false when GOOGLE_SHEETS_SYNC_ENABLED is not truthy" do
      with_env(
        "GOOGLE_SHEETS_SYNC_ENABLED" => "false",
        "GOOGLE_SERVICE_ACCOUNT_JSON" => '{"a":1}'
      ) do
        expect(described_class.new.enabled?).to be false
      end
    end

    it "is false when credentials JSON is missing" do
      with_env(
        "GOOGLE_SHEETS_SYNC_ENABLED" => "true",
        "GOOGLE_SERVICE_ACCOUNT_JSON" => "",
        "GOOGLE_SERVICE_ACCOUNT_JSON_BASE64" => ""
      ) do
        expect(described_class.new.enabled?).to be false
      end
    end

    it "is true when sync enabled and JSON present" do
      with_env(
        "GOOGLE_SHEETS_SYNC_ENABLED" => "true",
        "GOOGLE_SERVICE_ACCOUNT_JSON" => '{"type":"service_account"}'
      ) do
        expect(described_class.new.enabled?).to be true
      end
    end
  end

  describe "#sync! row building (private)" do
    it "builds header plus one row per For Sale listing" do
      with_env(
        "GOOGLE_SHEETS_SYNC_ENABLED" => "true",
        "GOOGLE_SERVICE_ACCOUNT_JSON" => '{"type":"service_account"}'
      ) do
        create(:listing, listing_number: "100", listing_price: 99.5, summary: "A", status: "For Sale")
        create(:listing, listing_number: "200", listing_price: 200, summary: "B", status: "Sold")

        rows = described_class.new.send(:build_value_rows)

        expect(rows[0]).to eq([ "Listing #", "Listing Price", "Summary" ])
        expect(rows[1]).to eq([ "100", "99.5", "A" ])
        expect(rows.size).to eq(2)
      end
    end
  end

  describe "#sync! with new spreadsheet" do
    it "creates spreadsheet and writes values" do
      with_env(
        "GOOGLE_SHEETS_SYNC_ENABLED" => "true",
        "GOOGLE_SERVICE_ACCOUNT_JSON" => '{"type":"service_account","project_id":"x"}',
        "GOOGLE_SHEETS_SPREADSHEET_ID" => ""
      ) do
        mock_auth = double("auth")
        allow(ListingExport::GoogleSheetsCredentials).to receive(:authorization).and_return(mock_auth)

        mock_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(Google::Apis::SheetsV4::SheetsService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:authorization=)

        created = instance_double(
          Google::Apis::SheetsV4::Spreadsheet,
          spreadsheet_id: "new-id-123",
          sheets: [
            instance_double(
              Google::Apis::SheetsV4::Sheet,
              properties: instance_double(Google::Apis::SheetsV4::SheetProperties, title: "Sheet1")
            )
          ]
        )
        allow(mock_service).to receive(:create_spreadsheet).and_return(created)
        allow(mock_service).to receive(:update_spreadsheet_value)

        described_class.new.sync!

        expect(mock_service).to have_received(:create_spreadsheet).with(
          instance_of(Google::Apis::SheetsV4::Spreadsheet)
        )
        expect(mock_service).to have_received(:update_spreadsheet_value).with(
          "new-id-123",
          "'Sheet1'!A1",
          instance_of(Google::Apis::SheetsV4::ValueRange),
          value_input_option: "USER_ENTERED"
        )
      end
    end
  end

  describe ".normalize_spreadsheet_id" do
    it "extracts ID from a full Google Sheets URL" do
      url = "https://docs.google.com/spreadsheets/d/abc123_XYZ/edit#gid=0"
      expect(described_class.normalize_spreadsheet_id(url)).to eq("abc123_XYZ")
    end

    it "returns stripped value when already a raw ID" do
      expect(described_class.normalize_spreadsheet_id("  raw_id_9  ")).to eq("raw_id_9")
    end
  end

  describe "#sync! with existing spreadsheet" do
    def sheet_named(title)
      instance_double(
        Google::Apis::SheetsV4::Sheet,
        properties: instance_double(Google::Apis::SheetsV4::SheetProperties, title: title)
      )
    end

    it "clears the target tab and writes values (same tab each sync)" do
      with_env(
        "GOOGLE_SHEETS_SYNC_ENABLED" => "true",
        "GOOGLE_SERVICE_ACCOUNT_JSON" => '{"type":"service_account"}',
        "GOOGLE_SHEETS_SPREADSHEET_ID" => "existing-id",
        "GOOGLE_SHEETS_SHEET_NAME_PREFIX" => "Listings"
      ) do
        allow(ListingExport::GoogleSheetsCredentials).to receive(:authorization).and_return(double("auth"))

        mock_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(Google::Apis::SheetsV4::SheetsService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:authorization=)
        meta = instance_double(Google::Apis::SheetsV4::Spreadsheet, sheets: [ sheet_named("Listings") ])
        allow(mock_service).to receive(:get_spreadsheet).with("existing-id", fields: "sheets.properties").and_return(meta)
        allow(mock_service).to receive(:clear_values)
        allow(mock_service).to receive(:update_spreadsheet_value)

        described_class.new.sync!

        expect(mock_service).to have_received(:clear_values).with("existing-id", "'Listings'!A:ZZ")
        expect(mock_service).to have_received(:update_spreadsheet_value).with(
          "existing-id",
          "'Listings'!A1",
          instance_of(Google::Apis::SheetsV4::ValueRange),
          value_input_option: "USER_ENTERED"
        )
      end
    end

    it "adds the tab once if missing, then clears and writes" do
      with_env(
        "GOOGLE_SHEETS_SYNC_ENABLED" => "true",
        "GOOGLE_SERVICE_ACCOUNT_JSON" => '{"type":"service_account"}',
        "GOOGLE_SHEETS_SPREADSHEET_ID" => "existing-id",
        "GOOGLE_SHEETS_TAB_NAME" => "Listings"
      ) do
        allow(ListingExport::GoogleSheetsCredentials).to receive(:authorization).and_return(double("auth"))

        mock_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(Google::Apis::SheetsV4::SheetsService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:authorization=)
        meta = instance_double(Google::Apis::SheetsV4::Spreadsheet, sheets: [ sheet_named("Sheet1") ])
        allow(mock_service).to receive(:get_spreadsheet).with("existing-id", fields: "sheets.properties").and_return(meta)
        allow(mock_service).to receive(:batch_update_spreadsheet)
        allow(mock_service).to receive(:clear_values)
        allow(mock_service).to receive(:update_spreadsheet_value)

        described_class.new.sync!

        expect(mock_service).to have_received(:batch_update_spreadsheet).with(
          "existing-id",
          instance_of(Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest)
        )
        expect(mock_service).to have_received(:clear_values).with("existing-id", "'Listings'!A:ZZ")
      end
    end

    it "normalizes spreadsheet URL from ENV" do
      with_env(
        "GOOGLE_SHEETS_SYNC_ENABLED" => "true",
        "GOOGLE_SERVICE_ACCOUNT_JSON" => '{"type":"service_account"}',
        "GOOGLE_SHEETS_SPREADSHEET_ID" => "https://docs.google.com/spreadsheets/d/extracted-id-99/edit",
        "GOOGLE_SHEETS_TAB_NAME" => "Export"
      ) do
        allow(ListingExport::GoogleSheetsCredentials).to receive(:authorization).and_return(double("auth"))

        mock_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(Google::Apis::SheetsV4::SheetsService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:authorization=)
        meta = instance_double(Google::Apis::SheetsV4::Spreadsheet, sheets: [ sheet_named("Export") ])
        allow(mock_service).to receive(:get_spreadsheet).with("extracted-id-99", fields: "sheets.properties").and_return(meta)
        allow(mock_service).to receive(:clear_values)
        allow(mock_service).to receive(:update_spreadsheet_value)

        described_class.new.sync!

        expect(mock_service).to have_received(:clear_values).with("extracted-id-99", "'Export'!A:ZZ")
      end
    end
  end
end
