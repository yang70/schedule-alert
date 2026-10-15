ENV["RAILS_ENV"] = "test"
require "uri"
candidate = ENV["DATABASE_URL"].to_s.match?(%r{/[A-Za-z0-9_-]+_test(?:\?.*)?\z}) ? ENV["DATABASE_URL"] : "postgresql:///schedule_test"
ENV["DATABASE_URL"] = ENV.fetch("TEST_DATABASE_URL", candidate)
ENV["FROM_EMAIL"] = "notifications@example.com"
ENV.delete("ADMIN_EMAIL")
abort "Tests require a dedicated database ending in _test" unless URI.parse(ENV["DATABASE_URL"]).path.end_with?("_test")
require "webmock/minitest"
WebMock.disable_net_connect!(allow_localhost: true)
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

class ActiveSupport::TestCase
  include ActiveJob::TestHelper
  def create_user(email: "owner@example.com", admin: false)
    User.create!(email: email, password: "test-password-123", confirmed_at: Time.current, admin: admin)
  end

  def create_url(user: create_user, **attributes)
    user.monitored_urls.create!({ name: "Fall tournament", url: "https://example.com/schedule", tournament_start_date: Date.current + 4 }.merge(attributes))
  end
end
