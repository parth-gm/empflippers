# frozen_string_literal: true

require "rails_helper"

RSpec.describe "IntegrationChecks", type: :request do
  describe "GET /integration_check" do
    it "returns 404 when not development" do
      allow(Rails.env).to receive(:development?).and_return(false)
      get "/integration_check"
      expect(response).to have_http_status(:not_found)
    end

    it "returns JSON when development" do
      allow(Rails.env).to receive(:development?).and_return(true)
      allow(IntegrationCheckService).to receive(:all).and_return(
        "empire_flippers_api" => { "status" => "ok", "detail" => "x" }
      )
      get "/integration_check"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["empire_flippers_api"]["status"]).to eq("ok")
    end
  end
end
