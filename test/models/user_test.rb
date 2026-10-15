require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email equality cannot grant the admin role" do
    user = create_user(email: "admin@example.com")
    original = ENV["ADMIN_EMAIL"]
    ENV["ADMIN_EMAIL"] = user.email
    assert_not user.admin?
    user.update!(admin: true)
    assert user.admin?
  ensure
    ENV["ADMIN_EMAIL"] = original
  end

  test "new accounts must confirm their account email" do
    user = User.create!(email: "new@example.com", password: "test-password-123")
    assert_not user.confirmed?
    assert_not user.active_for_authentication?
  end
end
