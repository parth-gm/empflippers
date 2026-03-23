# frozen_string_literal: true

# Scheduled via sidekiq-scheduler (see config/sidekiq.yml + cron expression).
class DailySyncJob
  include Sidekiq::Job

  sidekiq_options queue: "default", retry: 3

  def perform
    EmpireFlippers::SyncListingsService.new.call
    ListingExport::Orchestrator.call
  end
end
