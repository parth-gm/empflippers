# frozen_string_literal: true

# GET /integration_check — development only. JSON status for EF API, HubSpot, Google Sheets.
class IntegrationChecksController < ActionController::Base
  # No CSRF for JSON GET used with curl; dev-only.
  skip_forgery_protection

  before_action :ensure_development

  def show
    render json: IntegrationCheckService.all, status: :ok
  end

  private

  def ensure_development
    return if Rails.env.development?

    head :not_found
  end
end
