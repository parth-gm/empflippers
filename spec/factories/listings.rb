# frozen_string_literal: true

# Matches Listing columns: listing_number, listing_price, summary, niche, monetization, status,
# hubspot_deal_id, raw_data (jsonb), timestamps.
FactoryBot.define do
  factory :listing do
    sequence(:listing_number) { |n| "TEST#{n}" }
    listing_price { 99_999.99 }
    summary { "A sample listing summary for tests." }
    niche { "Health & Fitness" }
    monetization { "Amazon FBA" }
    status { "For Sale" }
    hubspot_deal_id { nil }
    raw_data { {} }
  end
end
