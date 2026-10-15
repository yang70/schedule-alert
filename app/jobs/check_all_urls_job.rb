class CheckAllUrlsJob < ApplicationJob
  queue_as :default

  def perform
    MonitoredUrl.due_for_check.find_each do |monitored_url|
      monitored_url.request_check!
    rescue StandardError => error
      Rails.logger.error("Schedule dispatch failed id=#{monitored_url.id} error=#{error.class.name}")
    end
  end
end
