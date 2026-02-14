class OpenAiService
  def initialize
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  def analyze_schedule(current_content, previous_content = nil)
    is_first_check = previous_content.nil?

    prompt = if is_first_check
      build_initial_check_prompt(current_content)
    else
      build_change_detection_prompt(current_content, previous_content)
    end

    begin
      response = @client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: "You are an expert at analyzing sports tournament schedule web pages." },
            { role: "user", content: prompt }
          ],
          temperature: 0.3,
          max_tokens: 1000
        }
      )

      content = response.dig("choices", 0, "message", "content")
      parse_ai_response(content, is_first_check)

    rescue => e
      Rails.logger.error "OpenAI API Error: #{e.message}"
      {
        schedule_available: false,
        schedule_changed: false,
        summary: "Error analyzing schedule: #{e.message}"
      }
    end
  end

  private

  def build_initial_check_prompt(content)
    <<~PROMPT
      Analyze this web page content to determine if it contains an ACTUAL sports tournament schedule with real game information.

      A schedule is ONLY available if you can see:
      - Specific game times (like "10:00 AM", "2:30 PM")
      - Specific game dates
      - Team matchups (Team A vs Team B)
      - Field/venue assignments

      A schedule is NOT available if:
      - You see messages like "not released yet", "coming soon", "check back later", "tournament director has not released"
      - There are only team lists without game times or matchups
      - The page shows pools/brackets but no actual game schedule
      - Only placeholders or "TBD" entries exist

      Be STRICT: When in doubt, answer NO. Only say YES if you can clearly see actual game times and dates.

      Web page content:
      #{truncate_content(content)}

      Respond in this exact format:
      SCHEDULE_AVAILABLE: [YES or NO]
      SUMMARY: [A brief 2-3 sentence summary. If YES, mention how many games you found. If NO, explain what's missing or what message you see instead (like "schedule not released yet").]

      GAMES_JSON: [If SCHEDULE_AVAILABLE is YES, provide a JSON array of games. Each game should have: "date", "time", "team1" (or "home"), "team2" (or "away" or "opponent"), "location" (field/venue). If NO, return empty array []]

      Example format for GAMES_JSON:
      [{"date": "March 15, 2026", "time": "10:00 AM", "team1": "Hawks", "team2": "Eagles", "location": "Field 3"}, {"date": "March 15, 2026", "time": "12:30 PM", "team1": "Hawks", "team2": "Tigers", "location": "Field 1"}]
    PROMPT
  end

  def build_change_detection_prompt(current_content, previous_content)
    <<~PROMPT
      Compare these two versions of a sports tournament schedule web page to detect meaningful changes.

      IMPORTANT: A schedule is ONLY available if it shows actual game times, dates, and matchups.
      Messages like "not released yet", "coming soon", or "check back later" mean NO schedule.

      Look for changes in:
      - Game times or dates being added, removed, or changed
      - Team matchups being updated
      - Field/venue assignments changing
      - New games appearing in the schedule
      - Schedule going from "not released" to showing actual games

      Ignore minor changes like:
      - Timestamps or "last updated" text
      - Advertisement content
      - Navigation or footer changes
      - Team lists if no game schedules are present

      PREVIOUS VERSION:
      #{truncate_content(previous_content)}

      CURRENT VERSION:
      #{truncate_content(current_content)}

      Respond in this exact format:
      SCHEDULE_AVAILABLE: [YES or NO - can you see actual game times and dates in the CURRENT version?]
      SCHEDULE_CHANGED: [YES or NO - did the actual schedule information change meaningfully?]
      SUMMARY: [A brief 2-3 sentence summary. If schedule appeared, say so. If changed, describe what changed. If still not available, confirm that. Mention how many games are in the current schedule.]

      GAMES_JSON: [If SCHEDULE_AVAILABLE is YES, provide a JSON array of ALL games from the CURRENT version. Each game should have: "date", "time", "team1" (or "home"), "team2" (or "away" or "opponent"), "location" (field/venue). If NO, return empty array []]

      Example format for GAMES_JSON:
      [{"date": "March 15, 2026", "time": "10:00 AM", "team1": "Hawks", "team2": "Eagles", "location": "Field 3"}, {"date": "March 15, 2026", "time": "12:30 PM", "team1": "Hawks", "team2": "Tigers", "location": "Field 1"}]
    PROMPT
  end

  def parse_ai_response(content, is_first_check)
    schedule_available = content.match(/SCHEDULE_AVAILABLE:\s*(YES|NO)/i)&.captures&.first&.upcase == "YES"
    schedule_changed = if is_first_check
      false
    else
      content.match(/SCHEDULE_CHANGED:\s*(YES|NO)/i)&.captures&.first&.upcase == "YES"
    end
    summary = content.match(/SUMMARY:\s*(.+?)(?:\n\n|\z)/m)&.captures&.first&.strip || content

    # Extract GAMES_JSON array
    schedule_data = nil
    if games_match = content.match(/GAMES_JSON:\s*(\[.*?\])/m)
      begin
        schedule_data = JSON.parse(games_match.captures.first)
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse GAMES_JSON: #{e.message}"
        schedule_data = nil
      end
    end

    {
      schedule_available: schedule_available,
      schedule_changed: schedule_changed,
      summary: summary,
      schedule_data: schedule_data
    }
  end

  def truncate_content(content, max_length = 8000)
    # Remove script tags and excessive whitespace
    cleaned = content.gsub(/<script.*?<\/script>/m, '')
                    .gsub(/<style.*?<\/style>/m, '')
                    .gsub(/\s+/, ' ')
                    .strip

    if cleaned.length > max_length
      cleaned[0...max_length] + "... [truncated]"
    else
      cleaned
    end
  end
end
