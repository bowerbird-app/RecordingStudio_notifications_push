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

  def test_recording_studio_stays_below_7
    dependency = Gem::Specification.find_by_name("recording_studio_notifications_push")
                                   .runtime_dependencies
                                   .find { |item| item.name == "recording_studio" }

    assert dependency.requirement.satisfied_by?(Gem::Version.new("6.3.0"))
    refute dependency.requirement.satisfied_by?(Gem::Version.new("7.0.0"))
    assert_equal Gem::Version.new("4.20.0"), Gem.loaded_specs.fetch("view_component").version
    assert_equal Gem::Version.new("0.1.332"), Gem.loaded_specs.fetch("flat_pack").version
    assert_equal Gem::Version.new("0.6.1"), Gem.loaded_specs.fetch("recording_studio_pwa").version
  end

  def test_notifications_dependency_floor_matches_the_tested_line
    dependency = Gem::Specification.find_by_name("recording_studio_notifications_push")
                                   .runtime_dependencies
                                   .find { |item| item.name == "recording_studio_notifications" }

    assert_equal Gem::Requirement.new(">= 0.14.7", "< 1"), dependency.requirement
  end

  def test_runtime_dependencies_come_from_the_loaded_gem
    names = Gem::Specification.find_by_name("recording_studio_notifications_push").runtime_dependencies.map(&:name)

    assert_includes names, "recording_studio"
    assert_includes names, "recording_studio_metrics"
    assert_includes names, "recording_studio_notifications"
    refute_includes names, "recording_studio_internationalization"
  end
end
