# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

require "devise/test/integration_helpers"
require "rails/test_help"

class DocsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TEST_PASSWORD = "DocsTestPassword!2026"

  setup do
    @user = User.find_or_create_by!(email: "docs-test@example.com") do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
    end

    sign_in @user
  end

  test "install page renders successfully" do
    get docs_install_path
    assert_response :success
    assert_select "h1", text: "Install"
    assert_includes response.body, "Required companions"
    assert_includes response.body, "recording_studio_notifications"
    assert_includes response.body, "recording_studio_pwa"
    assert_includes response.body, "recording_studio_notifications_push"
    assert_includes response.body, "1. Add the gems"
    assert_includes response.body, "pwa_service_worker"
    assert_includes response.body, "FIREBASE_SERVICE_ACCOUNT_JSON"
  end

  test "config page renders successfully" do
    get docs_config_path
    assert_response :success
    assert_select "h1", text: "Config"
    assert_includes response.body, "Defaults from ENV"
    assert_includes response.body, "RecordingStudioNotificationsPush.configure"
    assert_includes response.body, "firebase_service_account_json"
    assert_includes response.body, "FIREBASE_SERVICE_ACCOUNT_JSON"
    assert_includes response.body, "vapid_public_key"
    assert_includes response.body, "open_timeout"
    assert_includes response.body, "configuration.to_h"
  end

  test "template docs routes are gone" do
    get "/docs/recordable_types"
    assert_response :not_found

    get "/docs/recordings_tree"
    assert_response :not_found

    get "/docs/gem_views"
    assert_response :not_found

    get "/docs/methods"
    assert_response :not_found
  end

  test "authenticated docs pages use the flatpack sidebar layout" do
    get docs_install_path

    assert_response :success
    assert_includes response.body, "flat-pack-sidebar-layout"
    assert_includes response.body, 'data-theme="rounded"'
    refute_includes response.body, "data-recording-studio-default-layout"
  end
end
