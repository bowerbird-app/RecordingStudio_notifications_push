# frozen_string_literal: true

require "test_helper"

class RecordingStudioNotificationsPushTest < Minitest::Test
  def test_version_matches_the_locked_path_gem
    version = ::RecordingStudioNotificationsPush::VERSION

    assert_match(/\A\d+\.\d+\.\d+\z/, version)
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioNotificationsPush::Engine
  end

  def test_runtime_dependencies_come_from_the_loaded_gem
    names = Gem::Specification.find_by_name("recording_studio_notifications_push").runtime_dependencies.map(&:name)

    assert_includes names, "recording_studio"
    assert_includes names, "recording_studio_metrics"
    assert_includes names, "recording_studio_notifications"
    refute_includes names, "recording_studio_internationalization"
  end

  def test_dummy_pwa_head_resolves_service_worker_via_main_app
    head = File.read(
      File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__)
    )

    assert_includes head, "main_app.pwa_service_worker_path"
    assert_includes head, "main_app.pwa_manifest_path"
    assert_includes head, "RecordingStudioPwa.serviceWorkerReady"
  end
end
