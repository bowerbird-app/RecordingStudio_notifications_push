# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class DocsInstallPageTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "docs-install@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in @user
  end

  test "install docs name the required companion gems and setup steps" do
    get docs_install_path

    assert_response :success
    assert_includes response.body, "Required companions"
    assert_includes response.body, "recording_studio_notifications"
    assert_includes response.body, "recording_studio_pwa"
    assert_includes response.body, "recording_studio_notifications_push"
    assert_includes response.body, "recording_studio_notifications:install"
    assert_includes response.body, "recording_studio_notifications_push:install"
    assert_includes response.body, "recording_studio_notifications_push:migrations"
    assert_includes response.body, 'mount RecordingStudioNotifications::Engine'
    assert_includes response.body, 'mount RecordingStudioNotificationsPush::Engine'
    assert_includes response.body, "pwa_service_worker"
    assert_includes response.body, "FIREBASE_SERVICE_ACCOUNT_JSON"
    assert_includes response.body, "/notifications/push/devices"
  end
end
