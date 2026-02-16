class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :suppress_auth_alert_on_root

  private

  def suppress_auth_alert_on_root
    # Remove the "You need to sign in" flash when accessing root path
    if request.path == "/" && !user_signed_in? && flash[:alert] == "You need to sign in or sign up before continuing."
      flash.delete(:alert)
    end
  end
end
