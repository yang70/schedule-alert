class ScheduleFetcher
  Result = Data.define(:text, :complete)
  TELEMETRY_DOMAINS = %w[google-analytics.com analytics.google.com googleadservices.com].freeze

  def fetch(url)
    uri = PublicUrl.parse!(url)
    return Result.new(text: pdf_content(url), complete: true) if uri.path.match?(/\.pdf\z/i)

    proxy = SafeFetchProxy.new.start
    browser = nil
    begin
      browser = Ferrum::Browser.new(
        browser_path: ENV["CHROME_PATH"].presence,
        timeout: 30, process_timeout: 30,
        browser_options: {
          "proxy-server" => proxy.url, "proxy-bypass-list" => "<-loopback>",
          "disable-quic" => nil, "disable-gpu" => nil, "disable-dev-shm-usage" => nil,
          "force-webrtc-ip-handling-policy" => "disable_non_proxied_udp",
          "host-resolver-rules" => "MAP * ~NOTFOUND, EXCLUDE 127.0.0.1"
        }
      )
      # Some public providers reject Chrome's headless-specific user agent.
      # Keep the installed browser's version rather than freezing a fake version.
      browser.headers.set("User-Agent" => browser.default_user_agent.sub("HeadlessChrome/", "Chrome/"))
      browser.goto(url)
      idle = browser.network.wait_for_idle(connections: 2, duration: 0.5, timeout: 8)
      response = browser.network.response
      validate_response!(response)
      PublicUrl.parse!(browser.url)
      if response.headers.any? { |name, value| name.downcase == "content-type" && value.include?("application/pdf") }
        return Result.new(text: pdf_content(browser.url), complete: true)
      end

      page = PageContentExtractor.new.extract(visible_html(browser), browser.url)
      pieces = [ page[:text] ]
      failed_data_request = browser.network.traffic.any? do |exchange|
        failed_data_request?(exchange)
      end
      complete = page[:complete] && idle && !failed_data_request
      page[:frame_urls].each do |frame_url|
        frame = browser.frames.find { |item| !item.main? && item.url == frame_url }
        unless frame
          complete = false
          next
        end
        begin
          frame_page = PageContentExtractor.new.extract(visible_html(frame), frame_url == "about:blank" ? browser.url : frame_url)
          pieces << frame_page[:text]
          complete &&= frame_page[:complete] && frame_page[:frame_urls].empty?
          page[:pdf_links].concat(frame_page[:pdf_links])
        rescue MonitoringError, Ferrum::Error
          complete = false
        end
      end
      pdf_links = page[:pdf_links].uniq { |link| link[:url] }
      complete = false if pdf_links.size > PageContentExtractor::MAX_DOCUMENTS
      pdf_links.first(PageContentExtractor::MAX_DOCUMENTS).each do |link|
        begin
          pieces << "Linked PDF: #{link[:label]}\n#{pdf_content(link[:url])}"
        rescue MonitoringError
          complete = false
        end
      end
      content = pieces.join("\n\n")
      raise MonitoringError, "Combined schedule text exceeds the analysis limit" if content.length > PageContentExtractor::MAX_CHARACTERS
      raise MonitoringError, "No readable schedule content was found" if content.blank?
      Result.new(text: content, complete: !!complete)
    rescue Ferrum::Error => error
      raise MonitoringError, "Unable to render the schedule page (#{error.class.name})"
    ensure
      begin
        browser&.quit
      ensure
        proxy.stop
      end
    end
  end

  private

  def validate_response!(response)
    raise MonitoringError, "The schedule page did not return a response" unless response
    return if response.status.between?(200, 299)

    message = case response.status
    when 401, 403
      "The schedule provider denied access (HTTP #{response.status}). It may require a login or block automated checks."
    when 429
      "The schedule provider is rate limiting checks (HTTP 429). Try again later."
    else
      "The schedule page returned HTTP #{response.status}. It may be temporarily unavailable."
    end
    raise MonitoringError, message
  end

  def failed_data_request?(exchange)
    request = exchange.request
    return false unless request && %w[Document XHR Fetch].include?(request.type)
    # Analytics beacons can be canceled after a successful response. Their
    # delivery does not affect whether the timetable was completely loaded.
    if request.type != "Document"
      return false if exchange.response && [ 204, 205 ].include?(exchange.response.status)
      uri = URI.parse(request.url)
      host = uri.hostname.to_s.downcase
      return false if TELEMETRY_DOMAINS.any? { |domain| host == domain || host.end_with?(".#{domain}") }
      return false if host == "www.google.com" && uri.path.start_with?("/measurement/")
    end
    exchange.error || (exchange.response && exchange.response.status >= 400)
  rescue URI::InvalidURIError
    true
  end

  def visible_html(frame)
    frame.evaluate(<<~JAVASCRIPT)
      (() => {
        const clone = document.documentElement.cloneNode(true);
        const original = document.documentElement.querySelectorAll('*');
        const copies = clone.querySelectorAll('*');
        original.forEach((element, index) => {
          const style = getComputedStyle(element);
          if (style.display === 'none' || style.visibility === 'hidden') copies[index].remove();
        });
        return clone.outerHTML;
      })()
    JAVASCRIPT
  end

  def pdf_content(url)
    response = SafeHttpClient.new.get(url)
    PdfTextExtractor.new.extract(response.body)
  end
end
