class ScheduleAnalysis < ApplicationRecord
  validates :input_digest, :result, presence: true

  def self.for_content(url:, tournament_date:, content:, purpose: "release")
    key = Digest::SHA256.hexdigest([ OpenAiService.cache_version, purpose, url, tournament_date, content ].join("\0"))
    cached = find_by(input_digest: key)
    return cached.result.deep_symbolize_keys if cached

    result = yield
    transaction(requires_new: true) { create!(input_digest: key, result: result) }
    result
  rescue ActiveRecord::RecordNotUnique
    find_by!(input_digest: key).result.deep_symbolize_keys
  end
end
