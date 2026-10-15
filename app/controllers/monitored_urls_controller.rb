class MonitoredUrlsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_monitored_url, only: %i[destroy update check_now]
  rescue_from ActiveRecord::RecordNotFound do
    render json: { errors: [ "Monitored URL not found." ] }, status: :not_found
  end
  rate_limit to: 30, within: 1.hour, name: "monitor_changes", only: %i[create update check_now], by: -> { current_user.id },
    with: -> { render json: { errors: [ "Too many changes or checks. Please try again later." ] }, status: :too_many_requests }

  def index
    @monitored_urls = current_user.monitored_urls.select(*(MonitoredUrl::PUBLIC_ATTRIBUTES + %i[source_revision release_notified_revision])).includes(:person).order(created_at: :desc)
    respond_to do |format|
      format.html { redirect_to dashboard_path }
      format.json do
        events = NotificationEvent.joins(:monitored_url).where(monitored_urls: { user_id: current_user.id }).order(created_at: :desc).limit(10)
        render json: {
          monitored_urls: @monitored_urls.map(&:public_json),
          recent_events: events.as_json(only: %i[id kind payload created_at delivered_at delivery_attempts last_error])
        }
      end
    end
  end

  def create
    @monitored_url = current_user.monitored_urls.build(monitored_url_params)
    saved = current_user.with_lock { @monitored_url.save }
    if saved
      @monitored_url.request_check!
      respond_to do |format|
        format.html { redirect_to dashboard_path, notice: "URL added. Its first check is queued." }
        format.json { render json: @monitored_url.reload.public_json, status: :created }
      end
    else
      render_errors
    end
  end

  def update
    source_changed = false
    saved = @monitored_url.with_lock do
      result = @monitored_url.update(monitored_url_params)
      source_changed = result && (@monitored_url.saved_change_to_url? || @monitored_url.saved_change_to_tournament_start_date? || @monitored_url.saved_change_to_active?)
      result
    end
    if saved
      @monitored_url.request_check! if source_changed
      respond_to do |format|
        format.html { redirect_to dashboard_path, notice: "URL updated." }
        format.json { render json: @monitored_url.reload.public_json }
      end
    else
      render_errors
    end
  end

  def destroy
    @monitored_url.destroy!
    respond_to do |format|
      format.html { redirect_to dashboard_path, notice: "URL removed." }
      format.json { head :no_content }
    end
  end

  def check_now
    result = @monitored_url.request_check!(manual: true)
    case result
    when :queued, :busy
      render json: @monitored_url.reload.public_json, status: :accepted
    when :cooldown
      render json: { errors: [ "Please wait five minutes between manual checks." ] }, status: :too_many_requests
    else
      render json: { errors: [ "This tournament is inactive or its start date has passed." ] }, status: :unprocessable_entity
    end
  end

  private

  def set_monitored_url
    @monitored_url = current_user.monitored_urls.find(params[:id])
  end

  def monitored_url_params
    params.require(:monitored_url).permit(:url, :name, :notification_email, :active, :tournament_start_date, :sport, :person_id)
  end

  def render_errors
    respond_to do |format|
      format.html { redirect_to dashboard_path, alert: @monitored_url.errors.full_messages.join(", ") }
      format.json { render json: { errors: @monitored_url.errors.full_messages }, status: :unprocessable_entity }
    end
  end
end
