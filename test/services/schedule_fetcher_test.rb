require "test_helper"

class ScheduleFetcherTest < ActiveSupport::TestCase
  test "direct PDFs are analyzed from their contents without a browser" do
    response = SafeHttpClient::Response.new(body: File.binread(Rails.root.join("test/fixtures/files/schedule.pdf")), content_type: "application/pdf", url: "https://example.com/schedule.pdf")
    client = Object.new
    client.define_singleton_method(:get) { |_url| response }
    SafeHttpClient.stub(:new, client) do
      Ferrum::Browser.stub(:new, ->(*) { raise "Browser should not launch for a PDF" }) do
        result = ScheduleFetcher.new.fetch("https://example.com/schedule.pdf")
        assert result.complete
        assert_includes result.text, "2026-10-17"
        assert_includes result.text, "10:00 AM"
      end
    end
  end
end
