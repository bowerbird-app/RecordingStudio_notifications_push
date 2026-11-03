# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class DocsConfigPageTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "docs-config@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in @user
  end

  test "config docs list Firebase settings and timeouts" do
    get docs_config_path

    assert_response :success
    assert_includes response.body, "Defaults from ENV"
    assert_includes response.body, "recording_studio_notifications_push.rb"
    assert_includes response.body, "channel"
    assert_includes response.body, "firebase_web_config"
    assert_includes response.body, "firebase_project_id"
    assert_includes response.body, "vapid_public_key"
    assert_includes response.body, "firebase_service_account_json"
    assert_includes response.body, "FIREBASE_API_KEY"
    assert_includes response.body, "FIREBASE_SERVICE_ACCOUNT_JSON"
    assert_includes response.body, "fp-table"
    assert_includes response.body, "open_timeout"
    assert_includes response.body, "read_timeout"
    assert_includes response.body, "write_timeout"
    assert_includes response.body, "DeliveryError"
    ruby = css_select("pre").find { |node| node.text.include?("config.channel = :push") }
    assert ruby, "config page should show the Ruby initializer"
    assert_includes ruby["class"].to_s, "whitespace-pre"
    refute_includes ruby["class"].to_s, "break-words"
  end
end
