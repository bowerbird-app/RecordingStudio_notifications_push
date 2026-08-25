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
    assert_includes response.body, "flat-pack-sidebar-layout"
    assert_includes response.body, "navigator.serviceWorker"
    assert_includes response.body, "/service-worker.js"
    refute_includes response.body, "PWA service worker route is not mounted"
  end
end
