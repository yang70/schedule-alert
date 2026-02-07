class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @monitored_urls = current_user.monitored_urls.includes(:schedule_snapshots).order(created_at: :desc)
    @recent_snapshots = ScheduleSnapshot
                          .joins(:monitored_url)
                          .where(monitored_urls: { user_id: current_user.id })
                          .where(changes_detected: true)
                          .order(checked_at: :desc)
                          .limit(10)
  end
end
