class CheckAllUrlsJob < ApplicationJob
  queue_as :default

  def perform
    MonitoredUrl.active.find_each do |monitored_url|
      UrlCheckJob.perform_later(monitored_url.id)
    end
  end
end
