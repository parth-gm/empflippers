# frozen_string_literal: true

# One place for sync progress: Rails log + stdout in development (Sidekiq terminal).
class ProgressLog
  def self.info(message)
    Rails.logger.info(message)
    $stdout.puts(message) if Rails.env.development?
  end
end
