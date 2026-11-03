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
  end

  def test_development_gemfiles_pin_flatpack_and_pwa_by_tag
    [File.expand_path("../Gemfile", __dir__), File.expand_path("../test/dummy/Gemfile", __dir__)].each do |path|
      source = File.read(path)

      assert_includes source, 'gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.335"'
      assert_includes source, 'github: "bowerbird-app/RecordingStudio_PWA"'
      assert_includes source, 'tag: "v0.7.0"'
      refute_includes source, "ref:"
    end
  end

  def test_flat_pack_requirement_stays_on_0_1
    flat_pack = Gem::Specification.find_by_name("recording_studio_notifications_push")
                                  .runtime_dependencies
                                  .find { |item| item.name == "flat_pack" }

    assert_equal Gem::Requirement.new(">= 0.1.335", "< 0.2"), flat_pack.requirement
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
    assert_includes names, "flat_pack"
    assert_includes names, "recording_studio_metrics"
    assert_includes names, "recording_studio_notifications"
    refute_includes names, "recording_studio_internationalization"
  end
end
