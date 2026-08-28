# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PushDevicesPageTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "push devices page registers the host PWA service worker from the mounted engine" do
    user = User.find_or_create_by!(email: "push-sw-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in user

    get "/notifications/push/devices"

    assert_response :success
    refute_includes response.body, "flat-pack-sidebar-layout"
    assert_includes response.body, "flat-pack-page-nav"
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
end
