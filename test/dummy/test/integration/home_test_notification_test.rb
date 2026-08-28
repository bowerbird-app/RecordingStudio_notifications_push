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

  test "home page includes coral and teal icon test controls" do
    get root_path

    assert_response :success
    assert_includes response.body, "Test coral icon"
    assert_includes response.body, "Test teal icon"
    assert_includes response.body, 'name="icon"'
    assert_includes response.body, 'value="coral"'
    assert_includes response.body, 'value="teal"'
    assert_includes response.body, "/push-icon-coral.png"
    assert_includes response.body, "/push-icon-teal.png"
    assert_includes response.body, "test-notifications"
    assert_includes response.body, "In-app inbox"
    assert_includes response.body, "inbox-notifications"
  end

  test "coral icon notification stores metadata icon and turbo streams results" do
    assert_difference -> { RecordingStudioNotifications::Notification.count }, 1 do
      post test_notifications_path(format: :turbo_stream),
           params: { icon: "coral" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_includes response.body, "turbo-stream"
    assert_includes response.body, "Coral icon ping"
    assert_includes response.body, "test-notifications"
    assert_includes response.body, "inbox-notifications"
    assert_match(/in_app|push|email/, response.body)

    notification = RecordingStudioNotifications::Notification.order(created_at: :desc).first
    assert_equal @user, notification.recipient
    assert_equal "push_demo", notification.notification_type
    assert_equal demo_latest_notification_path, notification.url
    assert_equal "/push-icon-coral.png", notification.metadata["icon"]
  end

  test "teal icon notification stores the teal thumbnail path" do
    post test_notifications_path(format: :turbo_stream),
         params: { icon: "teal" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    notification = RecordingStudioNotifications::Notification.order(created_at: :desc).first
    assert_equal "Teal icon ping", notification.title
    assert_equal "/push-icon-teal.png", notification.metadata["icon"]
  end
end
