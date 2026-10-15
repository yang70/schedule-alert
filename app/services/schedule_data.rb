class ScheduleData
  def self.normalize(games)
    Array(games).map do |game|
      game = game.deep_stringify_keys
      {
        "date" => normalize_date(game["date"]), "time" => normalize_time(game["time"]),
        "team1" => normalize_text(game["team1"] || game["home"]),
        "team2" => normalize_text(game["team2"] || game["away"] || game["opponent"]),
        "location" => normalize_text(game["location"]), "status" => normalize_text(game["status"]) || "scheduled"
      }
    end.uniq.sort_by { |game| game.values.map(&:to_s) }
  end

  def self.change_summary(previous, current)
    removed = previous - current
    added = current - previous
    lines = removed.first(10).map { |game| "Removed or rescheduled: #{describe(game)}" }
    lines += added.first(10).map { |game| "Added or updated: #{describe(game)}" }
    lines << "Additional games changed; see the source schedule." if removed.size > 10 || added.size > 10
    lines.join("\n")
  end

  def self.describe(game)
    "#{game['date']} #{game['time']} — #{game['team1'] || 'TBD'} vs #{game['team2'] || 'TBD'}, #{game['location'] || 'venue TBD'} (#{game['status']})"
  end

  def self.normalize_text(value)
    text = value.to_s.squish.downcase
    %w[tbd tba unknown].include?(text) || text.empty? ? nil : text
  end

  def self.normalize_date(value)
    text = value.to_s.squish
    Date.parse(text).iso8601
  rescue Date::Error
    text.downcase
  end

  def self.normalize_time(value)
    text = value.to_s.squish.downcase
    match = text.match(/\A(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\z/)
    return text unless match
    hour = match[1].to_i
    minute = match[2].to_i
    return text unless minute < 60 && (match[3] ? hour.between?(1, 12) : hour.between?(0, 23))
    hour = hour % 12 + (match[3] == "pm" ? 12 : 0) if match[3]
    format("%02d:%02d", hour, minute)
  end
end
