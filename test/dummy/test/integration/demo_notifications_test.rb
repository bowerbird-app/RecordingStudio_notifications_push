# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class DemoNotificationsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "demo-notify@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in @user

    @notification = RecordingStudioNotifications.notify(
      notification_type: :push_demo,
      recipient: @user,
      title: "Demo detail ping",
      body: "Open me from a push click.",
      url: demo_latest_notification_path,
      actor: @user
    )
  end

  test "latest demo route redirects to the newest notification" do
    get demo_latest_notification_path

    assert_redirected_to demo_notification_path(@notification)
  end

  test "demo notification page shows full notification and delivery details" do
    get demo_notification_path(@notification)

    assert_response :success
    assert_includes response.body, "Demo detail ping"
    assert_includes response.body, "Open me from a push click."
    assert_includes response.body, @notification.id
    assert_includes response.body, "push_demo"
    assert_includes response.body, "Notification details"
    assert_includes response.body, "Channel deliveries"
    assert_includes response.body, "Push devices for this recipient"
    assert_includes response.body, demo_latest_notification_path
  end

  test "demo notification page marks the notice read" do
    assert @notification.unread?

    get demo_notification_path(@notification)

    assert_response :success
    assert @notification.reload.read?
  end

  test "demo notification page does not leak another account's notice" do
    other = User.find_or_create_by!(email: "other-demo@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    other_notification = RecordingStudioNotifications.notify(
      notification_type: :push_demo,
      recipient: other,
      title: "Private ping",
      body: "Not yours.",
      actor: other,
      deliver_later: true
    )

    get demo_notification_path(other_notification)

    assert_redirected_to root_path
  end
end
