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

<<<<<<< HEAD
  def test_runtime_dependencies_come_from_the_loaded_gem
    names = Gem::Specification.find_by_name("recording_studio_notifications_push").runtime_dependencies.map(&:name)
=======
  def test_notifications_dependency_floor_matches_the_tested_line
    gemspec = File.read(File.expand_path("../recording_studio_notifications_push.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio_notifications", ">= 0.14.0", "< 1"'
  end

  def test_gemspec_names_runtime_dependencies
    gemspec = File.read(File.expand_path("../recording_studio_notifications_push.gemspec", __dir__))
>>>>>>> d03bdb1 (Send click and icon URLs through UrlSafety (0.5.11))

    assert_includes names, "recording_studio"
    assert_includes names, "recording_studio_metrics"
    assert_includes names, "recording_studio_notifications"
    refute_includes names, "recording_studio_internationalization"
  end
end
