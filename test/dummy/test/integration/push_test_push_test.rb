# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PushTestPushTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "test-push@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in @user

    @installation = RecordingStudioNotificationsPush::Installation.upsert!(
      recipient: @user,
      firebase_installation_id: "fid-for-test-push",
      label: "Test browser"
    )
  end

  test "devices page focuses on enable and registered devices" do
    get "/notifications/push/devices"

    assert_response :success
    assert_includes response.body, "Enable on this browser"
    assert_includes response.body, "Push devices"
    refute_includes response.body, "Not getting alerts?"
    refute_includes response.body, "Show a local notification"
    refute_includes response.body, "Send a test push"
  end

  test "test push answers with a JSON verdict for this account's device" do
    post "/notifications/push/installations/#{@installation.id}/test_push",
         headers: { "Accept" => "application/json" }

    assert_includes [200, 502], response.status
    payload = JSON.parse(response.body)
    assert_includes payload.keys, "accepted"
    assert_equal response.status == 200, payload["accepted"]
    assert payload["error"].present? unless payload["accepted"]
  end

  test "test push does not reach another account's device" do
    other = User.find_or_create_by!(email: "other-push@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    other_installation = RecordingStudioNotificationsPush::Installation.upsert!(
      recipient: other,
      firebase_installation_id: "fid-other-account",
      label: "Other browser"
    )

    post "/notifications/push/installations/#{other_installation.id}/test_push",
         headers: { "Accept" => "application/json" }

    assert_response :not_found
  end

  test "test push does not reach a disabled device" do
    @installation.disable!(reason: "test")

    post "/notifications/push/installations/#{@installation.id}/test_push",
         headers: { "Accept" => "application/json" }

    assert_response :not_found
  end
end
