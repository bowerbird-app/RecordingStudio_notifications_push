# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < Minitest::Test
  Copy = RecordingStudioNotificationsPush::Copy

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_dummy_french_covers_every_engine_english_key
    english = flatten_keys(locale_tree(File.join(engine_locales_dir, "en.yml"), "en"))
    french = flatten_keys(locale_tree(File.join(dummy_locales_dir, "fr.yml"), "fr"))
    missing = english - french

    assert_empty missing, "dummy fr.yml is missing keys present in engine en.yml: #{missing.join(', ')}"
  end

  def test_english_default_copy_is_unchanged
    I18n.with_locale(:en) do
      assert_equal "Connected devices", Copy.t("devices.title")
      assert_equal "Your connected devices that can receive notifications", Copy.t("devices.subtitle")
      assert_equal "Enable on this browser", Copy.t("devices.enable_browser")
      assert_equal "Enable on this device", Copy.t("devices.enable_device")
      assert_equal "Manage notifications", Copy.t("devices.manage")
      assert_equal "That device will stay quiet now.", Copy.t("flashes.removed")
      assert_equal "We could not find that device.", Copy.t("flashes.not_found")
      assert_equal "Notification", Copy.t("payloads.fallback_title")
      assert_equal "Push test", Copy.t("payloads.test_title")
      assert_equal "This browser does not support notifications.", Copy.t("js.unsupported_notifications")
      assert_equal "Notifications are blocked for this site. Allow them in your browser settings, then try again.",
                   Copy.t("js.permission_denied")
    end
  end

  def test_argument_overrides_win_including_nil
    assert_equal "Connected devices", Copy.value(Copy::UNSET, "devices.title")
    assert_equal "Acme devices", Copy.value("Acme devices", "devices.title")
    assert_nil Copy.value(nil, "devices.title")
  end

  def test_host_translation_overrides_english
    I18n.backend.store_translations(:en, acme_title)
    assert_equal "Acme devices", Copy.t("devices.title")
  ensure
    I18n.backend.store_translations(:en, default_title)
  end

  def test_js_payload_comes_from_i18n
    payload = Copy.js_payload

    assert_equal "Enable on this browser", payload["enable_browser"]
    assert_equal "Enable on this device", payload["enable_device"]
    assert_equal "This browser does not support notifications.", payload["unsupported_notifications"]
    assert_equal "Notifications are blocked for this site. Allow them in your browser settings, then try again.",
                 payload["permission_denied"]
    assert_equal "Chrome on Mac", Copy.t("labels.on", browser: "Chrome", os: "Mac")
    assert_equal "Chrome", payload["browsers.chrome"]
    assert_includes payload.fetch("label_on"), "browser"
    assert_includes payload.fetch("label_on"), "os"
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def dummy_locales_dir
    File.expand_path("dummy/config/locales", __dir__)
  end

  def locale_tree(path, locale)
    yaml = YAML.safe_load_file(path, aliases: true)
    yaml.fetch(locale).fetch("recording_studio").fetch("notifications_push")
  end

  def flatten_keys(hash, prefix = [])
    hash.flat_map do |key, value|
      path = prefix + [key.to_s]
      value.is_a?(Hash) ? flatten_keys(value, path) : [path.join(".")]
    end
  end

  def acme_title
    { recording_studio: { notifications_push: { devices: { title: "Acme devices" } } } }
  end

  def default_title
    { recording_studio: { notifications_push: { devices: { title: "Connected devices" } } } }
  end
end
