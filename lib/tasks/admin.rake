namespace :admin do
  desc "Grant admin access to an explicitly selected trusted account"
  task grant: :environment do
    email = ENV.fetch("ADMIN_USER_EMAIL").downcase.strip
    user = User.find_by!(email: email)
    abort "Confirm this account's email before granting access" unless user.confirmed?
    user.update!(admin: true)
    puts "Admin role granted to account #{user.id}"
  end
end
