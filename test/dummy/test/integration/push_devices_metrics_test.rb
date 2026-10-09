# frozen_string_literal: true

require "test_helper"

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
    grant!(@admin_root, @staff, :admin)
    bootstrap_owner!(@root, @staff)
    seed_installations!
    Current.actor = nil
  end

  teardown do
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
    authorize = metrics_authorize

    with_admin_root(@admin_root) do
      assert authorize.call(GrantContext.new(Grant.new(@staff)))
      refute authorize.call(GrantContext.new(Grant.new(@outsider)))
      refute authorize.call(GrantContext.new(Grant.new(nil)))
    end
  end

  test "a granted actor is denied when Admin is absent" do
    refute defined?(RecordingStudioAdmin)
    assert staff_can_view_admin_root?

    refute metrics_authorize.call(staff_context)
  end

  test "a nil admin resolver denies a granted actor" do
    assert staff_can_view_admin_root?

    with_admin_resolvers(access: ->(_resolver_context) {}) do
      refute metrics_authorize.call(staff_context)
    end
  end

  test "a raising admin resolver denies a granted actor" do
    assert staff_can_view_admin_root?
    resolver = ->(resolver_context) { resolver_context.controller.request }

    with_admin_resolvers(access: resolver) do
      refute metrics_authorize.call(staff_context)
    end

    refute defined?(RecordingStudioAdmin)
  end

  test "authorization uses the site admin resolver" do
    other_workspace = Workspace.create!(name: "Other metrics #{SecureRandom.hex(4)}")
    other_root = RecordingStudio.root_recording_for(other_workspace)
    refute RecordingStudioAccessible.authorized?(actor: @staff, recording: other_root, role: :view)

    with_admin_resolvers(access: ->(_resolver_context) { other_root }, site: ->(_resolver_context) { @admin_root }) do
      assert metrics_authorize.call(staff_context)
    end
  end

  private

  def metrics_authorize
    authorize = RecordingStudioMetrics.registry.api_authorize_for(:push_devices)
    assert_equal RecordingStudioNotificationsPush::Metrics::AUTHORIZE, authorize
    authorize
  end

  def staff_context
    GrantContext.new(Grant.new(@staff))
  end

  def with_admin_root(recording)
    access = RecordingStudioNotificationsPush::Api::Access
    singleton = access.singleton_class
    original = access.method(:admin_root_recording)
    singleton.define_method(:admin_root_recording) { recording }
    yield
  ensure
    singleton.define_method(:admin_root_recording, original) if original
  end

  def staff_can_view_admin_root?
    RecordingStudioAccessible.authorized?(actor: @staff, recording: @admin_root, role: :view)
  end

  def with_admin_resolvers(access: nil, site: nil)
    installed = false
    raise "RecordingStudioAdmin is already loaded" if Object.const_defined?(:RecordingStudioAdmin, false)

    configuration = Struct.new(:site_admin_recording_resolver, :access_recording_resolver).new(site, access)
    admin = Module.new
    admin.define_singleton_method(:configuration) { configuration }
    Object.const_set(:RecordingStudioAdmin, admin)
    installed = true
    yield
  ensure
    Object.send(:remove_const, :RecordingStudioAdmin) if installed
  end

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
