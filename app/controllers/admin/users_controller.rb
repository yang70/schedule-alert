class Admin::UsersController < Admin::BaseController
  def index
    @users = User.includes(:monitored_urls, :people).order(created_at: :desc)
  end

  def show
    @user = User.find(params[:id])
    @monitored_urls = @user.monitored_urls.includes(:person, :schedule_snapshots).order(created_at: :desc)
    @people = @user.people.order(:name)
  end

  def destroy
    @user = User.find(params[:id])

    if @user == current_user
      return redirect_to admin_users_path, alert: "You can't delete your own account."
    end

    email = @user.email
    @user.destroy
    redirect_to admin_users_path, notice: "Deleted #{email} and all associated data."
  end
end
