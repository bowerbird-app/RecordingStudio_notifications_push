# frozen_string_literal: true

require "test_helper"

class DevicesControllerPathsTest < ActiveSupport::TestCase
  test "a missing settings route raises instead of hiding NoMethodError" do
    controller = RecordingStudioNotificationsPush::DevicesController.new

    controller.stub(:recording_studio_notifications, Object.new) do
      assert_raises(NoMethodError) do
        controller.instance_exec { notifications_settings_path }
      end
    end
  end

  test "an unknown service worker route argument returns nil" do
    controller = RecordingStudioNotificationsPush::DevicesController.new
    main_app = Struct.new(:label) do
      def pwa_service_worker_path(*)
        raise ArgumentError, "missing route"
      end
    end.new("app")

    controller.stub(:main_app, main_app) do
      assert_nil controller.instance_exec { service_worker_path }
    end
  end
end
