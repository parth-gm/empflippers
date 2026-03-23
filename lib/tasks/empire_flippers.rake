# frozen_string_literal: true

namespace :empire_flippers do
  desc "Test external credentials (EF API, HubSpot, Google) — no secrets printed"
  task check_credentials: :environment do
    IntegrationCheckService.all.each do |name, result|
      puts "#{name}: [#{result['status']}] #{result['detail']}"
    end
  end

  desc "Fetch For Sale listings from the Marketplace API and upsert into PostgreSQL"
  task fetch_listings: :environment do
    EmpireFlippers::SyncListingsService.call
    puts "Listings total: #{Listing.count}, For Sale: #{Listing.for_sale.count}"
  end

  desc "Push pending For Sale listings to HubSpot as Deals (needs HUBSPOT_API_KEY)"
  task sync_hubspot: :environment do
    HubSpot::SyncHubspotDealsService.call
    puts "Pending without HubSpot deal: #{Listing.pending_hubspot_sync.count}"
  end

  desc "Run enabled listing export connectors (HubSpot, Google Sheets, …)"
  task sync_destinations: :environment do
    ListingExport::Orchestrator.call
    puts "Listing export connectors finished."
  end

  desc "Google Sheets only: write For Sale rows from DB (needs GOOGLE_SHEETS_SYNC_ENABLED + credentials)"
  task sync_google_sheets: :environment do
    connector = ListingExport::GoogleSheetsConnector.new
    unless connector.enabled?
      puts "Google Sheets connector is disabled or missing credentials."
      puts "Set GOOGLE_SHEETS_SYNC_ENABLED=true and GOOGLE_SERVICE_ACCOUNT_JSON or GOOGLE_SERVICE_ACCOUNT_JSON_BASE64."
      exit 1
    end

    for_sale = Listing.for_sale.count
    puts "Syncing #{for_sale} For Sale listing(s) to Google Sheets…"
    connector.sync!
    puts "Google Sheets sync finished."
  end

  desc "Full pipeline: EF → Postgres, then orchestrator (HubSpot + Google Sheets if enabled)"
  task daily_sync: :environment do
    DailySyncJob.new.perform
    puts "Daily sync finished."
  end

  desc "Enqueue DailySyncJob (needs Redis + Sidekiq)"
  task daily_sync_async: :environment do
    DailySyncJob.perform_async
    puts "Enqueued DailySyncJob."
  end
end
