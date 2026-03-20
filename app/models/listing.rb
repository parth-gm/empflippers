# frozen_string_literal: true

class Listing < ApplicationRecord
  validates :listing_number, presence: true, uniqueness: true

  scope :for_sale, -> { where(status: "For Sale") }
  scope :pending_hubspot_sync, -> { for_sale.where(hubspot_deal_id: [ nil, "" ]) }
end
