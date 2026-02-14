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
      Analyze this web page content to determine if it contains an actual sports tournament schedule.

      A schedule should include:
      - Dates and/or times of games/matches
      - Team names or participant names
      - Locations or venues
      - Matchups or game details

      If the page is mostly blank, contains "coming soon", "check back later", or doesn't have actual schedule information, it's NOT available.

      Web page content:
      #{truncate_content(content)}

      Respond in this exact format:
      SCHEDULE_AVAILABLE: [YES or NO]
      SUMMARY: [A brief 2-3 sentence summary of what you found. If a schedule is available, summarize the key details like dates, teams, and format. If not available, explain why.]
    PROMPT
  end

  def build_change_detection_prompt(current_content, previous_content)
    <<~PROMPT
      Compare these two versions of a sports tournament schedule web page to detect meaningful changes.

      Look for changes in:
      - Game times or dates
      - Team matchups
      - Locations or venues
      - New games added or games removed
      - Any schedule-related updates

      Ignore minor changes like:
      - Timestamps or "last updated" text
      - Advertisement content
      - Navigation or footer changes

      PREVIOUS VERSION:
      #{truncate_content(previous_content)}

      CURRENT VERSION:
      #{truncate_content(current_content)}

      Respond in this exact format:
      SCHEDULE_AVAILABLE: [YES or NO - is there an actual schedule present?]
      SCHEDULE_CHANGED: [YES or NO - did the schedule information change meaningfully?]
      SUMMARY: [A brief 2-3 sentence summary. If changed, describe what changed. If unchanged, confirm no changes. If schedule appeared for the first time, note that.]
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

    {
      schedule_available: schedule_available,
      schedule_changed: schedule_changed,
      summary: summary
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
