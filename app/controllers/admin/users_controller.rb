class Admin::UsersController < Admin::BaseController
  def index
    @page = params[:page].to_i.clamp(1, 10_000)
    @user_count = User.count
    @users = User.select(:id, :email, :admin, :created_at, :monitored_urls_count, :people_count).order(created_at: :desc).limit(50).offset((@page - 1) * 50)
  end

  def show
    @user = User.find(params[:id])
    @monitored_urls = @user.monitored_urls.includes(:person).left_joins(:schedule_snapshots)
      .select("monitored_urls.*, COUNT(schedule_snapshots.id) AS snapshots_count")
      .group("monitored_urls.id").order(created_at: :desc)
    @people = @user.people.order(:name)
  end

  def destroy
    @user = User.find(params[:id])

    if @user.admin?
      return redirect_to admin_users_path, alert: "Revoke the admin role before deleting an admin account."
    end

    email = @user.email
    @user.destroy
    redirect_to admin_users_path, notice: "Deleted #{email} and all associated data."
  end
end
