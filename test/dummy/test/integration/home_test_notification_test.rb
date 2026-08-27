# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class HomeTestNotificationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "test-notify@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in @user
  end

  test "home page includes test notification control" do
    get root_path

    assert_response :success
    assert_includes response.body, "Test notification"
    assert_includes response.body, "test-notifications"
    assert_includes response.body, "In-app inbox"
    assert_includes response.body, "inbox-notifications"
  end

  test "test notification creates inbox row and turbo streams results" do
    assert_difference -> { RecordingStudioNotifications::Notification.count }, 1 do
      post test_notifications_path(format: :turbo_stream),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_includes response.body, "turbo-stream"
    assert_includes response.body, "Test ping"
    assert_includes response.body, "test-notifications"
    assert_includes response.body, "inbox-notifications"
    assert_match(/in_app|push|email/, response.body)

    notification = RecordingStudioNotifications::Notification.order(created_at: :desc).first
    assert_equal @user, notification.recipient
    assert_equal "push_demo", notification.notification_type
    expected_show_path = RecordingStudioNotifications::Engine.routes.url_helpers.notification_path(notification)
    assert_equal expected_show_path, notification.url
  end
end
