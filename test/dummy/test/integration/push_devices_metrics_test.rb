# frozen_string_literal: true

require "test_helper"

unless defined?(RecordingStudioAdmin)
  module RecordingStudioAdmin
    class Configuration
      attr_accessor :access_recording_resolver, :site_admin_recording_resolver
    end

    def self.configuration
      @configuration ||= Configuration.new
    end
  end
end

class PushDevicesMetricsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  GrantContext = Struct.new(:access_grant)
  Grant = Struct.new(:actor)

  setup do
    @staff = User.create!(
      email: "metrics-staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    @outsider = User.create!(
      email: "metrics-outsider-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @staff
    @workspace = Workspace.create!(name: "Metrics #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @admin_workspace = Workspace.create!(name: "Admin metrics #{SecureRandom.hex(4)}")
    @admin_root = RecordingStudio.root_recording_for(@admin_workspace)
    @original_access_resolver = RecordingStudioAdmin.configuration.access_recording_resolver
    admin_recording = @admin_root
    RecordingStudioAdmin.configuration.access_recording_resolver = ->(_context) { admin_recording }
    grant!(@admin_root, @staff, :admin)
    bootstrap_owner!(@root, @staff)
    seed_installations!
    Current.actor = nil
  end

  teardown do
    RecordingStudioAdmin.configuration.access_recording_resolver = @original_access_resolver
    Current.actor = nil
  end

  test "registered push device metrics return seeded platform, active, and series values" do
    identifiers = RecordingStudioMetrics.definitions.map(&:identifier)
    %w[
      push_devices.by_platform
      push_devices.active
      push_devices.new_over_time
    ].each { |identifier| assert_includes identifiers, identifier }

    platform_counts = breakdown_counts(execute("push_devices.by_platform"))
    RecordingStudioNotificationsPush::Installation.distinct.pluck(:platform).compact.each do |platform|
      assert_equal RecordingStudioNotificationsPush::Installation.where(platform: platform).count,
                   platform_counts[platform].to_i
    end

    assert_equal RecordingStudioNotificationsPush::Installation.active.count,
                 execute("push_devices.active").value
    assert_operator RecordingStudioNotificationsPush::Installation.where.not(disabled_at: nil).count, :>=, 1

    opened = timeseries_counts(
      execute(
        "push_devices.new_over_time",
        interval: "day",
        start_at: Time.utc(2026, 10, 6),
        end_at: Time.utc(2026, 10, 10)
      )
    )
    assert_equal installations_created_between(Time.utc(2026, 10, 7), Time.utc(2026, 10, 8)), opened["2026-10-07"]
    assert_equal installations_created_between(Time.utc(2026, 10, 8), Time.utc(2026, 10, 9)), opened["2026-10-08"]
    assert_operator opened["2026-10-07"], :>=, 1
    assert_operator opened["2026-10-08"], :>=, 2
  end

  test "api_authorize allows AdminRoot staff and denies non-admins" do
    authorize = RecordingStudioMetrics.registry.api_authorize_for(:push_devices)
    assert_equal RecordingStudioNotificationsPush::Metrics::AUTHORIZE, authorize

    assert authorize.call(GrantContext.new(Grant.new(@staff)))
    refute authorize.call(GrantContext.new(Grant.new(@outsider)))
    refute authorize.call(GrantContext.new(Grant.new(nil)))
  end

  private

  def execute(identifier, **params)
    RecordingStudioMetrics.execute(
      identifier,
      context: site_context,
      cache: false,
      **params
    )
  end

  def site_context
    RecordingStudioMetrics::Context.new(
      scope: :site,
      actor: @staff,
      site_authorized: true,
      timezone: "UTC"
    )
  end

  def seed_installations!
    travel_to Time.utc(2026, 10, 7, 12) do
      RecordingStudioNotificationsPush::Installation.upsert!(
        recipient: @staff,
        firebase_installation_id: "metrics-web-#{SecureRandom.hex(4)}",
        platform: "web"
      )
    end
    travel_to Time.utc(2026, 10, 8, 12) do
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

  def installations_created_between(start_at, end_at)
    RecordingStudioNotificationsPush::Installation.where(created_at: start_at...end_at).count
  end

  def breakdown_counts(result)
    result.data.to_h { |row| [ row[:key].to_s, row[:value] || row["value"] ] }
  end

  def timeseries_counts(result)
    result.data.to_h { |row| [ (row[:date] || row["date"]).to_s, row[:value] || row["value"] ] }
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
