# frozen_string_literal: true

require "test_helper"

class ApiAccessTest < Minitest::Test
  def test_can_view_is_false_without_admin_or_actor
    refute RecordingStudioNotificationsPush::Api::Access.can_view?(nil)
  end

  def test_admin_root_recording_is_nil_without_admin
    refute defined?(RecordingStudioAdmin)
    assert_nil RecordingStudioNotificationsPush::Api::Access.admin_root_recording
  end
end
