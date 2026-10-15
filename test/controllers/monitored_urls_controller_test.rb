require "test_helper"

class MonitoredUrlsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { Rails.cache.clear }

  test "manual checks return accepted without fetching in the web request" do
    monitored = create_url
    sign_in monitored.user
    assert_enqueued_with(job: UrlCheckJob) { post check_now_monitored_url_path(monitored), as: :json }
    assert_response :accepted
    assert_equal "queued", response.parsed_body["check_status"]
    assert_not response.parsed_body.key?("check_token")
    assert_not response.parsed_body.key?("user_id")
  end

  test "other accounts URLs cannot be checked or updated" do
    monitored = create_url
    sign_in create_user(email: "other@example.com")
    post check_now_monitored_url_path(monitored), as: :json
    assert_response :not_found
    patch monitored_url_path(monitored), params: { monitored_url: { name: "Changed" } }, as: :json
    assert_response :not_found
  end

  test "foreign person assignments fail without exposing their name" do
    monitored = create_url
    person = create_user(email: "other@example.com").people.create!(name: "Secret name", color: "#123456")
    sign_in monitored.user
    patch monitored_url_path(monitored), params: { monitored_url: { person_id: person.id } }, as: :json
    assert_response :unprocessable_entity
    assert_nil monitored.reload.person_id
    assert_not_includes response.body, "Secret name"
  end

  test "ordinary accounts cannot reach admin data or grant themselves a role" do
    user = create_user
    sign_in user
    get admin_users_path
    assert_redirected_to dashboard_path
    patch user_registration_path, params: { user: { admin: true, current_password: "test-password-123" } }
    assert_not user.reload.admin?
  end
end
