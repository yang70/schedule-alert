require "test_helper"

class ScheduleFetcherTest < ActiveSupport::TestCase
  FakeHeaders = Struct.new(:values) do
    def set(values)
      self.values = values
    end
  end
  FakeNetwork = Struct.new(:response, :traffic) do
    def wait_for_idle(**)
      true
    end
  end
  FakeBrowser = Struct.new(:default_user_agent, :headers, :network, :url, :frames) do
    def goto(_url); end
    def quit; end
    def evaluate(_script)
      "<html><body><main><p>October 18, 2026</p><p>10:00 AM Falcons vs TBD</p></main></body></html>"
    end
  end
  FakeProxy = Struct.new(:url) do
    def start
      self
    end
    def stop; end
  end
  FakeResponse = Data.define(:status, :headers)
  FakeRequest = Data.define(:type, :url)
  FakeExchange = Data.define(:request, :response, :error)

  test "browser uses the installed Chrome version without the headless-only user agent" do
    with_browser do |browser|
      result = ScheduleFetcher.new.fetch(browser.url)
      assert result.complete
      assert_includes result.text, "10:00 AM Falcons vs TBD"
      assert_equal "Mozilla/5.0 Chrome/147.0.0.0 Safari/537.36", browser.headers.values.fetch("User-Agent")
    end
  end

  test "provider access rejection includes the HTTP status and does not produce schedule content" do
    with_browser(status: 403) do |browser|
      error = assert_raises(MonitoringError) { ScheduleFetcher.new.fetch(browser.url) }
      assert_includes error.message, "denied access (HTTP 403)"
    end
  end

  test "canceled analytics do not disable full schedule comparison" do
    analytics = FakeExchange.new(request: FakeRequest.new(type: "Fetch", url: "https://analytics.google.com/g/collect"), response: FakeResponse.new(status: 204, headers: {}), error: { canceled: true })
    measurement = FakeExchange.new(request: FakeRequest.new(type: "Fetch", url: "https://www.google.com/measurement/conversion"), response: FakeResponse.new(status: 200, headers: {}), error: { canceled: true })
    with_browser(traffic: [ analytics, measurement ]) do |browser|
      assert ScheduleFetcher.new.fetch(browser.url).complete
    end
  end

  test "failed game API and document requests still make content incomplete" do
    [
      FakeRequest.new(type: "XHR", url: "https://example.com/api/games"),
      FakeRequest.new(type: "Fetch", url: "https://analytics.google.com.example.com/api/games"),
      FakeRequest.new(type: "Document", url: "https://analytics.google.com/schedule")
    ].each do |request|
      exchange = FakeExchange.new(request: request, response: FakeResponse.new(status: 403, headers: {}), error: nil)
      with_browser(traffic: [ exchange ]) do |browser|
        assert_not ScheduleFetcher.new.fetch(browser.url).complete
      end
    end
  end

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

  private

  def with_browser(status: 200, traffic: [])
    response = FakeResponse.new(status: status, headers: {})
    browser = FakeBrowser.new("Mozilla/5.0 HeadlessChrome/147.0.0.0 Safari/537.36", FakeHeaders.new, FakeNetwork.new(response, traffic), "https://example.com/schedule", [])
    SafeFetchProxy.stub(:new, FakeProxy.new("http://127.0.0.1:1234")) do
      Ferrum::Browser.stub(:new, browser) { yield browser }
    end
  end
end
