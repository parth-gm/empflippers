# frozen_string_literal: true

module EnvHelpers
  def with_env(overrides)
    saved = ENV.to_h
    overrides.each { |k, v| ENV[k] = v }
    yield
  ensure
    ENV.replace(saved)
  end
end

RSpec.configure do |config|
  config.include EnvHelpers
end
