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
    assert_includes response.body, "recording-studio-notifications--notification-polling"
    assert_includes response.body, "inbox-notifications"
    assert_includes response.body, "In-app inbox"
    assert_includes response.body, "Inbox is empty"
    assert_includes response.body, "dummy-bell-refresh"
    assert_equal :success, ApplicationController.helpers.delivery_badge_style("delivered")
    assert_equal :danger, ApplicationController.helpers.delivery_badge_style("failed")
    assert_equal :default, ApplicationController.helpers.delivery_badge_style("pending")
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
    assert_equal notification.metadata["icon"], notification.metadata["image"]
    assert_predicate notification.deliveries, :any?
    notification.deliveries.each do |delivery|
      assert_includes response.body, badge_background(delivery.status)
    end
    assert_includes response.body, "flat-pack-link"
    assert_includes response.body, "Open details"
  end

  test "home inbox matches the bell: active rows for the current root, plus rootless" do
    source = Workspace.create!(name: "Inbox Source #{SecureRandom.hex(4)}")
    other = Workspace.create!(name: "Inbox Other #{SecureRandom.hex(4)}")
    source_root = RecordingStudio.root_recording_for(source)
    other_root = RecordingStudio.root_recording_for(other)
    grant_owner!(@user, source_root)
    grant_owner!(@user, other_root)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: { root_recording_id: source_root.id, return_to: "/" }
    }
    follow_redirect!

    here = notify_ping("Here root ping", root_recording: source_root)
    elsewhere = notify_ping("Elsewhere root ping", root_recording: other_root)
    rootless = notify_ping("Rootless ping")
    archived = notify_ping("Archived ping")
    archived.archive!

    get root_path

    assert_response :success
    assert_includes response.body, here.title
    assert_includes response.body, rootless.title
    refute_includes response.body, elsewhere.title
    refute_includes response.body, archived.title
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

  private

  def notify_ping(title, root_recording: nil)
    RecordingStudioNotifications.notify(
      notification_type: :push_demo,
      recipient: @user,
      title: title,
      body: "Inbox scope check",
      actor: @user,
      root_recording: root_recording
    )
  end

  def grant_owner!(user, recording)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user).value!
  end

  def badge_background(status)
    style = ApplicationController.helpers.delivery_badge_style(status)
    "bg-[var(--badge-#{style}-background-color)]"
  end
end
