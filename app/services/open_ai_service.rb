class OpenAiService
  def initialize
    @client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
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
          response_format: {
            type: "json_schema",
            json_schema: {
              name: "schedule_analysis",
              schema: {
                type: "object",
                properties: {
                  schedule_available: { type: "boolean" },
                  schedule_changed: { type: "boolean" },
                  summary: { type: "string" },
                  schedule_data: {
                    type: "array",
                    items: {
                      type: "object",
                      properties: {
                        date: { type: "string" },
                        time: { type: "string" },
                        team1: { type: "string" },
                        team2: { type: "string" },
                        location: { type: "string" }
                      },
                      required: [ "date", "time", "team1", "team2", "location" ],
                      additionalProperties: false
                    }
                  }
                },
                required: [ "schedule_available", "schedule_changed", "summary", "schedule_data" ],
                additionalProperties: false
              },
              strict: true
            }
          },
          temperature: 0.1
        }
      )

      content = response.dig("choices", 0, "message", "content")
      parse_ai_response(content, is_first_check)

    rescue => e
      Rails.logger.error "OpenAI API Error: #{e.message}"
      {
        schedule_available: false,
        schedule_changed: false,
        summary: "Error analyzing schedule: #{e.message}",
        schedule_data: nil
      }
    end
  end

  private

  def build_initial_check_prompt(content)
    <<~PROMPT
      Analyze this web page text to determine if it contains an ACTUAL sports tournament schedule with real game information.

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

      Web page text:
      #{truncate_content(content)}
    PROMPT
  end

  def build_change_detection_prompt(current_content, previous_content)
    <<~PROMPT
      Compare these two versions of a sports tournament schedule web page text to detect meaningful changes.

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
    PROMPT
  end

  def parse_ai_response(content, is_first_check)
    begin
      parsed_json = JSON.parse(content)
      {
        schedule_available: parsed_json["schedule_available"],
        schedule_changed: is_first_check ? false : parsed_json["schedule_changed"],
        summary: parsed_json["summary"],
        schedule_data: parsed_json["schedule_data"]
      }
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse OpenAI JSON response: #{e.message}"
      {
        schedule_available: false,
        schedule_changed: false,
        summary: "Error parsing AI response format.",
        schedule_data: nil
      }
    end
  end

  def truncate_content(content, max_length = 50000)
    # The content is now plain text from Nokogiri, so we just need to ensure it's not too long
    # We still keep the truncation just in case there's massive text content
    if content.length > max_length
      content[0...max_length] + "... [truncated]"
    else
      content
    end
  end
end
