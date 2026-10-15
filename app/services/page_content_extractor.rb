class PageContentExtractor
  MAX_CHARACTERS = 50_000
  MAX_DOCUMENTS = 3

  def extract(html, url)
    raise MonitoringError, "Page exceeds the size limit" if html.bytesize > 5.megabytes
    doc = Nokogiri::HTML(html)
    doc.css("script, style, noscript, template, nav, header, footer, [hidden], [aria-hidden='true']").remove
    doc.css("[style]").each do |node|
      node.remove if node["style"].match?(/(?:display\s*:\s*none|visibility\s*:\s*hidden)/i)
    end
    links = doc.css("a[href], iframe[src], embed[src], object[data]").filter_map do |node|
      href = node["href"] || node["src"] || node["data"]
      uri = PublicUrl.parse!(URI.join(url, href).to_s)
      label = node.text.squish
      if uri.path.match?(/\.pdf\z/i) || node["type"] == "application/pdf"
        { url: uri.to_s, label: label }
      end
    rescue URI::InvalidURIError, PublicUrl::UnsafeUrl
      nil
    end.uniq { |link| link[:url] }
    frames = doc.css("iframe").filter_map do |node|
      src = node["src"]
      next "about:blank" if src.blank? || src == "about:blank"
      uri = PublicUrl.parse!(URI.join(url, src).to_s)
      uri.to_s unless uri.path.match?(/\.pdf\z/i)
    rescue URI::InvalidURIError, PublicUrl::UnsafeUrl
      nil
    end

    root = doc.at_css("main") || doc.at_css("body") || doc
    root.css("td, th, [role='cell'], [role='columnheader']").each { |node| node.add_next_sibling(Nokogiri::XML::Text.new("\t", doc)) }
    root.css("tr, p, div, li, h1, h2, h3, h4, section, br").each { |node| node.add_next_sibling(Nokogiri::XML::Text.new("\n", doc)) }
    text = root.text.lines.map(&:squish).reject(&:empty?).join("\n")
    raise MonitoringError, "The page contains no readable schedule content" if text.blank? && links.empty? && frames.empty?
    raise MonitoringError, "Page text exceeds the analysis limit" if text.length > MAX_CHARACTERS
    { text: text, pdf_links: links.first(MAX_DOCUMENTS), frame_urls: frames.first(MAX_DOCUMENTS), complete: links.size <= MAX_DOCUMENTS && frames.size <= MAX_DOCUMENTS }
  end
end
