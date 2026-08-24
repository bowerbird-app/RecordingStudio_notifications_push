# frozen_string_literal: true

require "test_helper"

class HooksTest < Minitest::Test
  def test_template_does_not_ship_a_copied_hooks_class
    refute File.exist?(File.expand_path("../lib/recording_studio_notifications_push/hooks.rb", __dir__))
    refute defined?(RecordingStudioNotificationsPush::Hooks)
  end

  def test_configuration_hooks_are_core_recording_studio_hooks
    configuration = RecordingStudioNotificationsPush::Configuration.new

    assert_instance_of RecordingStudio::Hooks, configuration.hooks
  end

  def test_engine_runs_addon_hooks_through_configuration
    called = false
    RecordingStudioNotificationsPush.configuration.hooks.after_initialize { called = true }

    initializer = RecordingStudioNotificationsPush::Engine.initializers.find do |entry|
      entry.name == "recording_studio_notifications_push.after_initialize"
    end
    initializer.block.call(Object.new)

    assert called
  ensure
    RecordingStudioNotificationsPush.configuration.hooks.clear!
  end
end
