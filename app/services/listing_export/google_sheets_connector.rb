# frozen_string_literal: true

require "google/apis/sheets_v4"
require "googleauth"

module ListingExport
  # DB → Google Sheets. With GOOGLE_SHEETS_SPREADSHEET_ID: clears a fixed tab and rewrites rows each sync.
  # Without ID: creates a new spreadsheet each run (writes to its first tab).
  class GoogleSheetsConnector
    include Connector

    HEADERS = [ "Listing #", "Listing Price", "Summary" ].freeze
    BAD_TAB_CHARS = %r{[/\\?*\[\]]}

    def self.normalize_spreadsheet_id(raw)
      s = raw.to_s.strip
      return "" if s.blank?
      m = s.match(%r{/spreadsheets/d/([a-zA-Z0-9_\-]+)})
      return m[1] if m

      s.split(/[?#]/, 2).first.to_s.strip.sub(%r{/edit.*\z}i, "").strip
    end

    def name
      "Google Sheets"
    end

    def enabled?
      sync_flag? && ListingExport::GoogleSheetsCredentials.json_string.present?
    end

    def sync!
      service = sheets_service
      rows = build_value_rows
      id = self.class.normalize_spreadsheet_id(ENV["GOOGLE_SHEETS_SPREADSHEET_ID"])
      if id.blank?
        create_and_write(service, rows)
      else
        overwrite_tab(service, id, rows)
      end
    rescue Google::Apis::ClientError => e
      msg = [ e.message, e.body ].map(&:presence).compact.join(" — ")
      raise Google::Apis::ClientError.new(msg, status_code: e.status_code, header: e.header, body: e.body)
    end

    private

    def sync_flag?
      ActiveModel::Type::Boolean.new.cast(ENV["GOOGLE_SHEETS_SYNC_ENABLED"])
    end

    def sheets_service
      Google::Apis::SheetsV4::SheetsService.new.tap do |s|
        s.authorization = ListingExport::GoogleSheetsCredentials.authorization
      end
    end

    def build_value_rows
      data = Listing.for_sale.order(:listing_number).map do |listing|
        [ listing.listing_number.to_s, listing.listing_price&.to_s("F") || "", listing.summary.to_s ]
      end
      [ HEADERS, *data ]
    end

    def create_and_write(service, rows)
      title = env_title("GOOGLE_SHEETS_NEW_SPREADSHEET_TITLE", "Empire Flippers Listings", 200)
      body = Google::Apis::SheetsV4::Spreadsheet.new(
        properties: Google::Apis::SheetsV4::SpreadsheetProperties.new(title: title)
      )
      created = service.create_spreadsheet(body)
      sid = created.spreadsheet_id
      tab = created.sheets&.first&.properties&.title.presence || "Sheet1"
      write_values(service, sid, a1(tab), rows)
      ProgressLog.info("[ListingExport] Google Sheets: created https://docs.google.com/spreadsheets/d/#{sid}/edit")
    end

    def overwrite_tab(service, spreadsheet_id, rows)
      tab = target_tab_title
      ensure_tab!(service, spreadsheet_id, tab)
      q = quoted_tab(tab)
      service.clear_values(spreadsheet_id, "#{q}!A:ZZ")
      write_values(service, spreadsheet_id, a1(tab), rows)
      ProgressLog.info("[ListingExport] Google Sheets: overwrote tab #{tab.inspect} in #{spreadsheet_id}")
    end

    def ensure_tab!(service, spreadsheet_id, title)
      meta = service.get_spreadsheet(spreadsheet_id, fields: "sheets.properties")
      exists = meta.sheets.to_a.any? { |sh| sh.properties&.title == title }
      return if exists

      req = Google::Apis::SheetsV4::Request.new(
        add_sheet: Google::Apis::SheetsV4::AddSheetRequest.new(
          properties: Google::Apis::SheetsV4::SheetProperties.new(title: title)
        )
      )
      batch = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new(requests: [ req ])
      service.batch_update_spreadsheet(spreadsheet_id, batch)
    end

    def target_tab_title
      raw = ENV["GOOGLE_SHEETS_TAB_NAME"].to_s.sub(/\s+#.*/, "").strip
      raw = ENV["GOOGLE_SHEETS_SHEET_NAME_PREFIX"].to_s.sub(/\s+#.*/, "").strip if raw.blank?
      raw = "Listings" if raw.blank?
      raw.gsub(BAD_TAB_CHARS, "_").strip[0, 100].presence || "Listings"
    end

    def write_values(service, spreadsheet_id, range_a1, rows)
      vr = Google::Apis::SheetsV4::ValueRange.new(values: rows)
      service.update_spreadsheet_value(spreadsheet_id, range_a1, vr, value_input_option: "USER_ENTERED")
    end

    def quoted_tab(sheet_title)
      "'#{sheet_title.gsub("'", "''")}'"
    end

    def a1(sheet_title)
      "#{quoted_tab(sheet_title)}!A1"
    end

    def env_title(key, default, max)
      t = ENV.fetch(key, default).to_s.sub(/\s+#.*/, "").gsub(/\s+/, " ").strip[0, max]
      t.presence || default
    end
  end
end
