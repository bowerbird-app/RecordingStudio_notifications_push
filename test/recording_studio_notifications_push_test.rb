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
    assert dependency.requirement.satisfied_by?(Gem::Version.new("7.8.0"))
    refute dependency.requirement.satisfied_by?(Gem::Version.new("8.0.0"))
  end

  def test_flat_pack_allows_the_tested_minor_through_1_x
    flat_pack = runtime_dependency("flat_pack")

    assert_equal Gem::Requirement.new(">= 0.1.0", "< 2.0"), flat_pack.requirement
    assert flat_pack.requirement.satisfied_by?(Gem::Version.new("0.1.0"))
    assert flat_pack.requirement.satisfied_by?(Gem::Version.new("0.1.357"))
    assert flat_pack.requirement.satisfied_by?(Gem::Version.new("0.2.0"))
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

  def test_development_gemfiles_pin_the_swept_minors
    root = File.read(File.expand_path("../Gemfile", __dir__))
    dummy = File.read(File.expand_path("dummy/Gemfile", __dir__))

    {
      "recording_studio" => "~> 7.8",
      "flat_pack" => "~> 0.2",
      "recording_studio_accessible" => "~> 0.58",
      "recording_studio_admin" => "~> 2.20",
      "recording_studio_logs" => "~> 0.9",
      "recording_studio_metrics" => "~> 0.10",
      "recording_studio_notifications" => "~> 0.21",
      "recording_studio_pwa" => "~> 0.10",
      "recording_studio_trashable" => "~> 1.3",
      "recording_studio_api" => "~> 1.21",
      "recording_studio_moveable" => "~> 6.1",
      "recording_studio_icons" => "~> 0.5"
    }.each do |name, requirement|
      line = %(gem "#{name}", "#{requirement}")
      assert_includes root, line, line
      assert_includes dummy, line, line
    end

    assert_includes dummy, 'gem "recording_studio_cache", "~> 0.8"'
    assert_includes dummy, 'gem "recording_studio_root_switchable", "~> 0.17"'
    assert_includes root, 'gem "view_component", "4.20.0"'
    assert_includes dummy, 'gem "view_component", "4.20.0"'
    assert_includes root, 'tag: "v0.5.3"'
    assert_includes dummy, 'tag: "v0.5.4"'
    assert_includes dummy, 'tag: "v0.3.0"'

    admin = Bundler.definition.dependencies.find { |item| item.name == "recording_studio_admin" }
    assert_equal Gem::Requirement.new("~> 2.20"), admin.requirement
  end

  def test_dummy_importmap_does_not_pin_flat_pack_heroicons
    importmap = File.read(File.expand_path("dummy/config/importmap.rb", __dir__))

    refute_includes importmap, "flat_pack/heroicons"
    refute_includes importmap, "flat-pack--icon"
  end

  private

  def runtime_dependency(name)
    Gem::Specification.find_by_name("recording_studio_notifications_push")
                      .runtime_dependencies
                      .find { |item| item.name == name }
  end
end
