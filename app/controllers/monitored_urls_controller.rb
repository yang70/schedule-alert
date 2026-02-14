class MonitoredUrlsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_monitored_url, only: [:destroy, :update, :check_now]

  def index
    @monitored_urls = current_user.monitored_urls.order(created_at: :desc)
    @monitored_url = MonitoredUrl.new

    respond_to do |format|
      format.html
      format.json do
        @recent_snapshots = ScheduleSnapshot
                              .joins(:monitored_url)
                              .where(monitored_urls: { user_id: current_user.id })
                              .where(changes_detected: true)
                              .order(checked_at: :desc)
                              .limit(10)

        render json: {
          monitored_urls: @monitored_urls.as_json(only: [:id, :name, :url, :notification_email, :schedule_available, :last_checked_at, :active, :tournament_start_date, :next_check_at]),
          recent_snapshots: @recent_snapshots.as_json(only: [:id, :ai_summary, :checked_at])
        }
      end
    end
  end

  def create
    @monitored_url = current_user.monitored_urls.build(monitored_url_params)

    if @monitored_url.save
      # Queue a job to check this URL immediately
      UrlCheckJob.perform_later(@monitored_url.id)

      respond_to do |format|
        format.html { redirect_to dashboard_path, notice: "URL added successfully and checking now." }
        format.json { render json: @monitored_url, status: :created }
      end
    else
      respond_to do |format|
        format.html do
          @monitored_urls = current_user.monitored_urls.order(created_at: :desc)
          render :index, status: :unprocessable_entity
        end
        format.json { render json: { errors: @monitored_url.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @monitored_url.update(monitored_url_params)
      redirect_to monitored_urls_path, notice: "URL updated successfully."
    else
      redirect_to monitored_urls_path, alert: "Failed to update URL."
    end
  end

  def destroy
    @monitored_url.destroy

    respond_to do |format|
      format.html { redirect_to monitored_urls_path, notice: "URL removed successfully." }
      format.json { head :ok }
    end
  end

  def check_now
    UrlCheckJob.perform_later(@monitored_url.id)

    respond_to do |format|
      format.html { redirect_to monitored_urls_path, notice: "Checking URL now..." }
      format.json { head :ok }
    end
  end

  private

  def set_monitored_url
    @monitored_url = current_user.monitored_urls.find(params[:id])
  end

  def monitored_url_params
    params.require(:monitored_url).permit(:url, :name, :notification_email, :active, :tournament_start_date)
  end
end
