# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class InstallationRegistrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "push-registration@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in @user
  end

  test "registering a device stores it and returns the installation" do
    user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                 "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    post "/notifications/push/installations",
         params: {
           installation: {
             firebase_installation_id: "fid-api-1",
             platform: "web",
             label: "API browser",
             legacy_fcm_token: "legacy-token-1",
             user_agent: user_agent
           }
         },
         headers: { "Accept" => "application/json" }

    assert_response :created
    body = JSON.parse(response.body)
    record = RecordingStudioNotificationsPush::Installation.find(body.fetch("id"))

    assert_equal "fid-api-1", body.fetch("firebase_installation_id")
    assert_equal "API browser", body.fetch("label")
    assert_equal "web", record.platform
    assert_equal "legacy-token-1", record.legacy_fcm_token
    assert_equal user_agent, record.user_agent
    assert_equal @user, record.recipient
    assert_equal "fid-api-1", record.delivery_token
    assert record.active?
    assert_nil record.disabled_at
  end

  test "registration uses the request user agent when the client does not send one" do
    user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                 "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    post "/notifications/push/installations",
         params: { installation: { firebase_installation_id: "fid-api-ua", platform: "web" } },
         headers: { "Accept" => "application/json", "User-Agent" => user_agent }

    assert_response :created
    record = RecordingStudioNotificationsPush::Installation.find(JSON.parse(response.body).fetch("id"))
    assert_equal user_agent, record.user_agent
  end

  test "registration rejects a missing firebase installation id" do
    post "/notifications/push/installations",
         params: { installation: { label: "No id" } },
         headers: { "Accept" => "application/json" }

    assert_response :unprocessable_entity
    assert_match(/firebase_installation_id is required/, JSON.parse(response.body).fetch("error"))
  end

  test "registering the same device again updates it and turns push back on" do
    post "/notifications/push/installations",
         params: {
           installation: {
             firebase_installation_id: "fid-api-again",
             label: "First",
             platform: "web",
             legacy_fcm_token: "legacy-keep"
           }
         },
         headers: { "Accept" => "application/json" }
    assert_response :created
    id = JSON.parse(response.body).fetch("id")

    delete "/notifications/push/installations/#{id}", headers: { "Accept" => "application/json" }
    assert_response :no_content
    refute RecordingStudioNotificationsPush::Installation.find(id).active?

    post "/notifications/push/installations",
         params: {
           installation: {
             firebase_installation_id: "fid-api-again",
             label: "Second",
             platform: "ios"
           }
         },
         headers: { "Accept" => "application/json" }

    assert_response :created
    record = RecordingStudioNotificationsPush::Installation.find(id)
    assert_equal "Second", record.label
    assert_equal "ios", record.platform
    assert_equal "legacy-keep", record.legacy_fcm_token
    assert record.active?
  end

  test "a blank registration field clears it and a null field leaves it alone" do
    record = RecordingStudioNotificationsPush::Installation.upsert!(
      recipient: @user,
      firebase_installation_id: "fid-fields",
      label: "Keep me",
      platform: "web",
      legacy_fcm_token: "legacy-1",
      user_agent: "Mozilla/5.0"
    )

    updated = RecordingStudioNotificationsPush::Installation.upsert!(
      recipient: @user,
      firebase_installation_id: "fid-fields",
      label: nil,
      platform: "ios"
    )
    assert_equal record.id, updated.id
    assert_equal "Keep me", updated.label
    assert_equal "ios", updated.platform
    assert_equal "legacy-1", updated.legacy_fcm_token
    assert_equal "Mozilla/5.0", updated.user_agent

    cleared = RecordingStudioNotificationsPush::Installation.upsert!(
      recipient: @user,
      firebase_installation_id: "fid-fields",
      label: ""
    )
    assert_nil cleared.label
    assert_equal "legacy-1", cleared.legacy_fcm_token
  end

  test "removing an installation disables it and a second remove leaves the time alone" do
    record = RecordingStudioNotificationsPush::Installation.upsert!(
      recipient: @user,
      firebase_installation_id: "fid-disable"
    )
    earlier = 3.days.ago.change(usec: 0)
    record.update!(last_seen_at: earlier)

    record.touch_seen!
    assert record.reload.last_seen_at > earlier

    unsaved = RecordingStudioNotificationsPush::Installation.new(legacy_fcm_token: "legacy-only")
    assert_equal "legacy-only", unsaved.delivery_token

    delete "/notifications/push/installations/#{record.id}"
    assert_response :no_content
    disabled_at = record.reload.disabled_at
    assert disabled_at.present?

    travel 1.minute do
      assert_same record, record.disable!(reason: "again")
    end
    assert_equal disabled_at, record.reload.disabled_at
  end

  test "unregistering a missing installation is not found" do
    delete "/notifications/push/installations/#{SecureRandom.uuid}"

    assert_response :not_found
  end

  test "removing a missing device from the page explains that it is gone" do
    delete "/notifications/push/devices/#{SecureRandom.uuid}"

    assert_redirected_to "/notifications/push/devices"
    assert_equal "We could not find that device.", flash[:alert]
  end

  test "the devices page sends a signed out person to sign in" do
    sign_out @user

    get "/notifications/push/devices"

    assert_response :redirect
    assert_match(%r{/users/sign_in}, response.location)
  end
end
