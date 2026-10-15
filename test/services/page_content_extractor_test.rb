require "test_helper"

class PageContentExtractorTest < ActiveSupport::TestCase
  test "keeps table structure and PDF links while removing hidden and layout text" do
    html = '<body><nav>Advertising</nav><main><h1>October 17, 2026</h1><table><tr><td>10:00 AM</td><td>Falcons vs TBD</td></tr><tr><td>11:00 AM</td><td>Owls vs Bears</td></tr></table><div hidden>Old games</div><a href="/games.pdf">Published schedule</a></main></body>'
    result = PageContentExtractor.new.extract(html, "https://example.com/tournament")
    assert_includes result[:text], "10:00 AM Falcons vs TBD"
    assert_includes result[:text], "\n"
    assert_not_includes result[:text], "Old games"
    assert_not_includes result[:text], "Advertising"
    assert_equal "https://example.com/games.pdf", result[:pdf_links].first[:url]
  end

  test "large pages fail instead of silently truncating schedule evidence" do
    assert_raises(MonitoringError) { PageContentExtractor.new.extract("<body>#{'x' * 50_001}</body>", "https://example.com") }
  end

  test "a PDF must contain readable scheduling evidence, not just a link" do
    text = PdfTextExtractor.new.extract(File.binread(Rails.root.join("test/fixtures/files/schedule.pdf")))
    assert_includes text, "2026-10-17"
    assert_includes text, "10:00 AM"
    assert_raises(MonitoringError) { PdfTextExtractor.new.extract("This is not a PDF") }
  end
end
