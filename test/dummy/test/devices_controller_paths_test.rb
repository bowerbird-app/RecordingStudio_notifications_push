# frozen_string_literal: true

require "test_helper"

class DevicesControllerPathsTest < ActiveSupport::TestCase
  test "a missing settings route raises instead of hiding NoMethodError" do
    controller = RecordingStudioNotificationsPush::DevicesController.new
    notifications = Object.new
    controller.define_singleton_method(:recording_studio_notifications) { notifications }

    assert_raises(NoMethodError) { controller.send(:notifications_settings_path) }
  end

  test "an unknown service worker route argument returns nil" do
    controller = RecordingStudioNotificationsPush::DevicesController.new
    main_app = Object.new
    main_app.define_singleton_method(:pwa_service_worker_path) { raise ArgumentError, "missing route" }
    controller.define_singleton_method(:main_app) { main_app }

    assert_nil controller.send(:service_worker_path)
  end
end
