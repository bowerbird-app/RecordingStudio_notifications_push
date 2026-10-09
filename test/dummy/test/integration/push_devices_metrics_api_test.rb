# frozen_string_literal: true

require "test_helper"

class PushDevicesMetricsApiTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  OPERATIONS_ROOT = "/recording_studio_api/apis/operations/v1"
  PUBLIC_ROOT = "/recording_studio_api/api/v1"

  setup do
    @staff = User.create!(
      email: "metrics-staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @staff
    @workspace = Workspace.create!(name: "Metrics #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @admin_workspace = Workspace.create!(name: "Admin metrics #{SecureRandom.hex(4)}")
    @admin_root = RecordingStudio.root_recording_for(@admin_workspace)
    @original_access_resolver = RecordingStudioAdmin.configuration.access_recording_resolver
    @original_site_resolver = RecordingStudioAdmin.configuration.site_admin_recording_resolver
    admin_recording = @admin_root
    RecordingStudioAdmin.configuration.access_recording_resolver = ->(_context) { admin_recording }
    RecordingStudioAdmin.configuration.site_admin_recording_resolver = ->(_context) { admin_recording }
    grant!(@admin_root, @staff, :admin)
    bootstrap_owner!(@root, @staff)

    seed_installations!

    @staff_operations_token = provision_token(
      access_point: @admin_root,
      actor: @staff,
      role: :edit,
      name: "Staff operations metrics #{SecureRandom.hex(4)}",
      api: :operations
    )
    @workspace_operations_token = provision_token(
      access_point: @root,
      actor: @staff,
      role: :edit,
      name: "Workspace operations metrics #{SecureRandom.hex(4)}",
      api: :operations
    )
    @public_token = provision_token(
      access_point: @root,
      actor: @staff,
      role: :view,
      name: "Public metrics #{SecureRandom.hex(4)}"
    )
    Current.actor = nil
  end

  teardown do
    RecordingStudioAdmin.configuration.access_recording_resolver = @original_access_resolver
    RecordingStudioAdmin.configuration.site_admin_recording_resolver = @original_site_resolver
    Current.actor = nil
  end

  test "operations staff token reads push device metrics" do
    get "#{OPERATIONS_ROOT}/metrics/push_devices/by_platform",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    platform_counts = breakdown_counts(response.parsed_body)
    RecordingStudioNotificationsPush::Installation.distinct.pluck(:platform).compact.each do |platform|
      assert_equal RecordingStudioNotificationsPush::Installation.where(platform: platform).count,
                   platform_counts[platform].to_i
    end

    get "#{OPERATIONS_ROOT}/metrics/push_devices/active",
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    assert_equal RecordingStudioNotificationsPush::Installation.active.count, response.parsed_body.fetch("value")
    assert_operator RecordingStudioNotificationsPush::Installation.where.not(disabled_at: nil).count, :>=, 1

    get "#{OPERATIONS_ROOT}/metrics/push_devices/new_over_time",
        params: { interval: "day" },
        headers: auth(@staff_operations_token),
        as: :json
    assert_response :success
    opened = timeseries_counts(response.parsed_body)
    first_key = @first_day.strftime("%Y-%m-%d")
    second_key = @second_day.strftime("%Y-%m-%d")
    assert_equal installations_created_between(Time.utc(2026, 10, 7), Time.utc(2026, 10, 8)), opened[first_key]
    assert_equal installations_created_between(Time.utc(2026, 10, 8), Time.utc(2026, 10, 9)), opened[second_key]
    assert_operator opened[first_key], :>=, 1
    assert_operator opened[second_key], :>=, 2
  end

  test "metrics index lists push device metrics" do
    get "#{OPERATIONS_ROOT}/metrics", headers: auth(@staff_operations_token), as: :json

    assert_response :success
    identifiers = response.parsed_body.fetch("metrics").map { |row| row.fetch("identifier") }
    %w[
      push_devices.by_platform
      push_devices.active
      push_devices.new_over_time
    ].each { |identifier| assert_includes identifiers, identifier }
  end

  test "non-admin operations token is denied push device metrics" do
    get "#{OPERATIONS_ROOT}/metrics/push_devices/active",
        headers: auth(@workspace_operations_token),
        as: :json
    assert_response :forbidden

    get "#{OPERATIONS_ROOT}/metrics", headers: auth(@workspace_operations_token), as: :json
    assert_response :success
    identifiers = response.parsed_body.fetch("metrics").map { |row| row.fetch("identifier") }
    refute_includes identifiers, "push_devices.active"
    refute_includes identifiers, "push_devices.by_platform"
    refute_includes identifiers, "push_devices.new_over_time"
  end

  test "public API token is denied operations push device metrics" do
    get "#{OPERATIONS_ROOT}/metrics/push_devices/active",
        headers: auth(@public_token),
        as: :json
    assert_response :unauthorized

    get "#{PUBLIC_ROOT}/metrics/push_devices/active",
        headers: auth(@public_token),
        as: :json
    assert_includes [ 404, 401, 403 ], response.status
  end

  private

  def seed_installations!
    @first_day = Time.utc(2026, 10, 7, 12)
    @second_day = Time.utc(2026, 10, 8, 12)

    travel_to @first_day do
      RecordingStudioNotificationsPush::Installation.upsert!(
        recipient: @staff,
        firebase_installation_id: "metrics-web-#{SecureRandom.hex(4)}",
        platform: "web"
      )
    end
    travel_to @second_day do
      RecordingStudioNotificationsPush::Installation.upsert!(
        recipient: @staff,
        firebase_installation_id: "metrics-ios-#{SecureRandom.hex(4)}",
        platform: "ios"
      )
      disabled = RecordingStudioNotificationsPush::Installation.upsert!(
        recipient: @staff,
        firebase_installation_id: "metrics-android-#{SecureRandom.hex(4)}",
        platform: "android"
      )
      disabled.disable!
    end
  end

  def breakdown_counts(payload)
    payload.fetch("data").to_h { |row| [ row.fetch("key").to_s, row.fetch("value") ] }
  end

  def installations_created_between(start_at, end_at)
    RecordingStudioNotificationsPush::Installation.where(created_at: start_at...end_at).count
  end

  def timeseries_counts(payload)
    payload.fetch("data").to_h { |row| [ row.fetch("date").to_s, row.fetch("value") ] }
  end

  def auth(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def provision_token(access_point:, actor:, role:, name:, api: :public)
    result = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_point,
      manager_actor: actor,
      role: role,
      name: name,
      api: api
    )
    raise result.error unless result.success?

    payload = result.value
    token_result = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: payload.fetch(:credential).oauth_client_id,
      client_secret: payload.fetch(:token),
      api: api
    )
    raise token_result.error unless token_result.success?

    token_result.value.fetch(:access_token)
  end

  def bootstrap_owner!(recording, actor)
    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: recording,
      actor: actor
    )
    raise result.error if result.failure?
  end

  def grant!(recording, actor, role)
    return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role)

    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: @staff
    )
    raise result.error if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end
end
