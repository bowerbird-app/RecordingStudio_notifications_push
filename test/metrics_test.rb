# frozen_string_literal: true

require "test_helper"
require "active_record"
require_relative "../app/models/recording_studio_notifications_push/application_record"
require_relative "../app/models/recording_studio_notifications_push/installation"

class MetricsTest < Minitest::Test
  def setup
    RecordingStudioMetrics.registry.reset!
    RecordingStudioNotificationsPush::Metrics.register!
  end

  def teardown
    RecordingStudioMetrics.registry.reset!
  end

  def test_push_device_metrics_register_on_the_operations_api
    identifiers = %w[push_devices.by_platform push_devices.active push_devices.new_over_time]
    identifiers.each do |identifier|
      definition = RecordingStudioMetrics.find(identifier)
      assert_equal :site, definition.blast_radius
      assert_equal [:operations], definition.exposed_apis
      assert_equal RecordingStudioNotificationsPush::Installation, definition.model
      refute definition.exposed_to_api?(:public)
      assert definition.exposed_to_api?(:operations)
    end

    assert_equal :platform, RecordingStudioMetrics.find("push_devices.by_platform").field
    assert_equal :breakdown, RecordingStudioMetrics.find("push_devices.by_platform").metric_type
    assert_equal :count, RecordingStudioMetrics.find("push_devices.active").metric_type
    assert_equal :created_at, RecordingStudioMetrics.find("push_devices.new_over_time").field
    assert_equal :timeseries, RecordingStudioMetrics.find("push_devices.new_over_time").metric_type
    assert_same RecordingStudioNotificationsPush::Metrics::AUTHORIZE,
                RecordingStudioMetrics.registry.api_authorize_for(:push_devices)
  end

  def test_authorize_hook_follows_can_view
    context = Struct.new(:access_grant).new(Struct.new(:actor).new(Object.new))

    assert_equal RecordingStudioNotificationsPush::Api::Access.can_view?(context),
                 RecordingStudioNotificationsPush::Metrics::AUTHORIZE.call(context)
    refute RecordingStudioNotificationsPush::Metrics::AUTHORIZE.call(context)
  end
end
