class CheckAllUrlsJob < ApplicationJob
  queue_as :default

  def perform
    # Only check URLs that are due for a check based on their schedule
    MonitoredUrl.due_for_check.find_each do |monitored_url|
      UrlCheckJob.perform_later(monitored_url.id)
      # Schedule next check after queuing the job
      monitored_url.schedule_next_check
    end
  end
end
