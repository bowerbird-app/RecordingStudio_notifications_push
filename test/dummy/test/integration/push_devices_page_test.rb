# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PushDevicesPageTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "devices controller uses core default layout and installations stay off it" do
    assert_includes RecordingStudioNotificationsPush::DevicesController.ancestors,
                    RecordingStudio::UsesDefaultLayout
    refute_includes RecordingStudioNotificationsPush::InstallationsController.ancestors,
                    RecordingStudio::UsesDefaultLayout
  end

  test "push devices page registers the host PWA service worker from the mounted engine" do
    user = User.find_or_create_by!(email: "push-sw-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in user

    get "/notifications/push/devices"

    assert_response :success
    assert_includes response.body, 'data-recording-studio-default-layout="true"'
    refute_includes response.body, "flat-pack-sidebar-layout"
    assert_includes response.body, "flat-pack-page-nav"
    assert_equal 1, response.body.scan("flat-pack-page-nav").length
    refute_includes response.body, "recording_studio_notifications_push/blank"
    assert_includes response.body, "Push Notifications"
    assert_includes response.body, "navigator.serviceWorker"
    assert_includes response.body, "/service-worker.js"
    refute_includes response.body, "PWA service worker route is not mounted"
  end

  test "push devices page includes notification help modal for browser and OS steps" do
    user = User.find_or_create_by!(email: "push-help-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in user

    get "/notifications/push/devices"

    assert_response :success
    assert_includes response.body, "Not getting alerts?"
    assert_includes response.body, "push-notification-help-modal"
    assert_includes response.body, "Not receiving push notifications?"
    assert_includes response.body, "helpOsSteps"
    refute_includes response.body, "helpDetected"
  end

  test "unconfigured devices page warns without a Firebase installation id field" do
    user = User.find_or_create_by!(email: "push-unconfigured-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in user

    get "/notifications/push/devices"

    assert_response :success
    assert_includes response.body, "Not getting alerts?"
    assert_includes response.body, "Manage notifications"
    refute_includes response.body, "Register this id"
    refute_includes response.body, "Paste a FID"
    refute_includes response.body, "paste a Firebase installation id"
    refute_includes response.body, 'data-recording-studio-notifications-push--push-devices-target="manualFid"'
    refute_includes response.body, "registerManualFid"

    config = RecordingStudioNotificationsPush.configuration
    web = config.firebase_web_config || {}
    required = %i[apiKey appId projectId messagingSenderId]
    firebase_ready = required.all? { |key| web[key].present? || web[key.to_s].present? } &&
      config.vapid_public_key.present?

    if firebase_ready
      assert_includes response.body, "Enable on this browser"
    else
      assert_includes response.body, "Firebase is not configured yet"
      assert_includes response.body, "bg-[var(--alert-warning-background-color)]"
      refute_includes response.body, "bg-[var(--alert-info-background-color)]"
    end
  end
end

