# frozen_string_literal: true

namespace :empire_flippers do
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

  desc "Full pipeline: EF → Postgres, then HubSpot (same as DailySyncJob#perform)"
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
