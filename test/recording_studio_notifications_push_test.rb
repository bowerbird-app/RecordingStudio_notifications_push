# frozen_string_literal: true

require "test_helper"

class RecordingStudioNotificationsPushTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.1.0", ::RecordingStudioNotificationsPush::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioNotificationsPush::Engine
  end

  def test_gemspec_pins_dependencies
    gemspec = File.read(File.expand_path("../recording_studio_notifications_push.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_notifications", ">= 0.2", "< 1"'
    assert_includes gemspec, "RecordingStudio_notifications_push"
    assert_includes gemspec, "CHANGELOG.md"
  end

  def test_dummy_gemfile_pins_verified_github_sources
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.7.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_notifications"'
    assert_includes gemfile, "vendor/recording_studio_notifications_email"
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_PWA"'
    assert_includes gemfile, "cursor/pwa-service-worker-seam-453c"
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.133"'
  end

  def test_does_not_ship_template_capabilities_or_pages
    refute File.exist?(File.expand_path("../lib/recording_studio_notifications_push/capabilities/example.rb", __dir__))
    refute File.exist?(File.expand_path("../app/controllers/recording_studio_notifications_push/home_controller.rb",
                                        __dir__))
    pages = Dir[File.expand_path("../db/migrate/*pages*.rb", __dir__)]
    assert_empty pages
  end

  def test_dummy_app_uses_flatpack_sidebar_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "flat_pack_sidebar"
    refute_includes controller_source, "UsesDefaultLayout"
    assert File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    assert File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))
  end

  def test_product_readme_describes_push_channel
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "RecordingStudioNotificationsPush"
    assert_includes readme, ":push"
    assert_includes readme, "FIREBASE_SERVICE_ACCOUNT_JSON"
    assert_includes readme, "deliver_rollup"
    refute_includes readme, "ExampleService"
    refute_includes readme, "addon template"
  end

  def test_devices_view_and_service_worker_partial_exist
    assert File.exist?(
      File.expand_path("../app/views/recording_studio_notifications_push/devices/show.html.erb", __dir__)
    )
    assert File.exist?(
      File.expand_path("../app/views/recording_studio_notifications_push/_service_worker_push.js.erb", __dir__)
    )
    push_devices_js = File.read(
      File.expand_path(
        "../app/javascript/recording_studio_notifications_push/controllers/push_devices_controller.js",
        __dir__
      )
    )
    assert_includes push_devices_js, "serviceWorkerRegistration"
    assert_includes push_devices_js, "resolveServiceWorkerRegistration"
    assert_includes push_devices_js, "not mounted"
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
