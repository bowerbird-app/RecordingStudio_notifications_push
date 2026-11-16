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

  def test_recording_studio_requires_the_tested_core_7_line
    dependency = runtime_dependency("recording_studio")

    assert_equal Gem::Requirement.new(">= 7.3.0", "< 8.0"), dependency.requirement
    refute dependency.requirement.satisfied_by?(Gem::Version.new("7.2.0"))
    assert dependency.requirement.satisfied_by?(Gem::Version.new("7.3.0"))
    refute dependency.requirement.satisfied_by?(Gem::Version.new("8.0.0"))
  end

  def test_flat_pack_allows_the_tested_minor_through_1_x
    flat_pack = runtime_dependency("flat_pack")

    assert_equal Gem::Requirement.new(">= 0.1.0", "< 2.0"), flat_pack.requirement
    assert flat_pack.requirement.satisfied_by?(Gem::Version.new("0.1.0"))
    assert flat_pack.requirement.satisfied_by?(Gem::Version.new("0.1.357"))
    assert flat_pack.requirement.satisfied_by?(Gem::Version.new("1.9.0"))
    refute flat_pack.requirement.satisfied_by?(Gem::Version.new("2.0.0"))
  end

  def test_notifications_dependency_floor_matches_the_tested_line
    dependency = runtime_dependency("recording_studio_notifications")

    assert_equal Gem::Requirement.new(">= 0.19.0", "< 2.0"), dependency.requirement
    refute dependency.requirement.satisfied_by?(Gem::Version.new("0.18.0"))
    assert dependency.requirement.satisfied_by?(Gem::Version.new("0.19.0"))
    assert dependency.requirement.satisfied_by?(Gem::Version.new("1.0.0"))
    refute dependency.requirement.satisfied_by?(Gem::Version.new("2.0.0"))
  end

  def test_metrics_dependency_floor_matches_the_tested_line
    dependency = runtime_dependency("recording_studio_metrics")

    assert_equal Gem::Requirement.new(">= 0.9.0", "< 2.0"), dependency.requirement
    refute dependency.requirement.satisfied_by?(Gem::Version.new("0.8.0"))
    assert dependency.requirement.satisfied_by?(Gem::Version.new("0.9.0"))
    assert dependency.requirement.satisfied_by?(Gem::Version.new("1.0.0"))
    refute dependency.requirement.satisfied_by?(Gem::Version.new("2.0.0"))
  end

  def test_rails_dependency_matches_the_tested_line
    dependency = runtime_dependency("rails")

    assert_equal Gem::Requirement.new(">= 8.1.0", "< 9.0"), dependency.requirement
    refute dependency.requirement.satisfied_by?(Gem::Version.new("8.0.0"))
    assert dependency.requirement.satisfied_by?(Gem::Version.new("8.1.0"))
    assert dependency.requirement.satisfied_by?(Gem::Version.new("8.1.4.1"))
    refute dependency.requirement.satisfied_by?(Gem::Version.new("9.0.0"))
  end

  def test_runtime_dependencies_have_a_floor_and_a_cap
    dependencies = Gem::Specification.find_by_name("recording_studio_notifications_push").runtime_dependencies

    assert_equal %w[flat_pack rails recording_studio recording_studio_metrics recording_studio_notifications],
                 dependencies.map(&:name).sort
    dependencies.each do |dependency|
      operators = dependency.requirement.requirements.map(&:first)
      assert_includes operators, ">="
      assert_includes operators, "<"
      refute_includes operators, "~>"
    end
    refute_includes dependencies.map(&:name), "recording_studio_internationalization"
  end

  def test_development_admin_dependency_covers_2_16
    dependency = Bundler.definition.dependencies.find { |item| item.name == "recording_studio_admin" }

    assert_equal Gem::Requirement.new(">= 2.16.0", "< 3.0"), dependency.requirement
    refute dependency.requirement.satisfied_by?(Gem::Version.new("2.15.0"))
    assert dependency.requirement.satisfied_by?(Gem::Version.new("2.16.0"))
    assert dependency.requirement.satisfied_by?(Gem::Version.new("2.17.0"))
    refute dependency.requirement.satisfied_by?(Gem::Version.new("3.0.0"))
  end

  private

  def runtime_dependency(name)
    Gem::Specification.find_by_name("recording_studio_notifications_push")
                      .runtime_dependencies
                      .find { |item| item.name == name }
  end
end
