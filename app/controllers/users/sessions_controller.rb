# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # GET /users/sign_in
  def new
    # Clear any flash messages when showing the sign in page
    flash.discard(:alert) if flash[:alert] == "You need to sign in or sign up before continuing."
    super
  end
end
