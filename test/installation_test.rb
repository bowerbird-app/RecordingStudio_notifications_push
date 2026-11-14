# frozen_string_literal: true

require "test_helper"
require "active_record"
require_relative "../app/models/recording_studio_notifications_push/application_record"
require_relative "../app/models/recording_studio_notifications_push/installation"
require_relative "../app/models/recording_studio_notifications_push/installation/user_agent"

class InstallationTest < Minitest::Test
  class FakeInstallation
    attr_accessor :firebase_installation_id, :legacy_fcm_token, :disabled_at

    def delivery_token
      firebase_installation_id.to_s.presence || legacy_fcm_token.to_s.presence
    end

    def active?
      disabled_at.nil?
    end
  end

  def test_delivery_token_is_fid_first
    installation = FakeInstallation.new
    installation.firebase_installation_id = "fid-primary"
    installation.legacy_fcm_token = "legacy-token"

    assert_equal "fid-primary", installation.delivery_token
  end

  def test_delivery_token_falls_back_to_legacy
    installation = FakeInstallation.new
    installation.firebase_installation_id = nil
    installation.legacy_fcm_token = "legacy-token"

    assert_equal "legacy-token", installation.delivery_token
  end

  def test_label_from_user_agent_builds_short_browser_names
    user_agent = [
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
      "AppleWebKit/537.36 (KHTML, like Gecko)",
      "Chrome/120.0.0.0 Safari/537.36"
    ].join(" ")

    assert_equal "Chrome on Mac",
                 RecordingStudioNotificationsPush::Installation.label_from_user_agent(user_agent)
  end

  def test_display_label_keeps_stored_labels_over_generated_user_agent
    installation = installation_with(
      label: "Jo test tablet",
      user_agent: chrome_mac_user_agent,
      platform: "web"
    )

    assert_equal "Jo test tablet", installation.display_label
  end

  def test_registration_rejects_unknown_attributes
    error = assert_raises(ArgumentError) do
      RecordingStudioNotificationsPush::Installation.upsert!(
        recipient: Object.new,
        firebase_installation_id: "fid-1",
        surprise: 1
      )
    end

    assert_match(/unknown registration attribute: surprise/, error.message)
  end

  def test_display_label_falls_back_to_generated_i18n_label
    installation = installation_with(label: nil, user_agent: chrome_mac_user_agent)

    assert_equal "Chrome on Mac", installation.display_label
  end

  def test_generated_device_labels_follow_the_current_locale
    I18n.available_locales = %i[en fr]
    I18n.backend.store_translations(
      :fr,
      recording_studio: {
        notifications_push: {
          labels: {
            on: "%{browser} sur %{os}", # rubocop:disable Style/FormatStringToken
            browsers: { chrome: "Chrome" },
            os: { mac: "Mac" }
          }
        }
      }
    )

    I18n.with_locale(:en) do
      assert_equal "Chrome on Mac",
                   RecordingStudioNotificationsPush::Installation.label_from_user_agent(chrome_mac_user_agent)
    end
    I18n.with_locale(:fr) do
      assert_equal "Chrome sur Mac",
                   RecordingStudioNotificationsPush::Installation.label_from_user_agent(chrome_mac_user_agent)
    end
  ensure
    I18n.available_locales = %i[en]
    I18n.locale = :en
  end

  def test_user_agent_like_detects_raw_user_agent_labels
    assert RecordingStudioNotificationsPush::Installation.user_agent_like?(
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
    )
    refute RecordingStudioNotificationsPush::Installation.user_agent_like?("Chrome on Mac")
  end

  def test_mobile_device_detects_phones_and_tablets
    assert RecordingStudioNotificationsPush::Installation.mobile_device?(
      user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
    )
    assert RecordingStudioNotificationsPush::Installation.mobile_device?(
      platform: "ios",
      label: "Safari on iPhone"
    )
    assert RecordingStudioNotificationsPush::Installation.mobile_device?(
      user_agent: "Mozilla/5.0 (Linux; Android 14)"
    )
    refute RecordingStudioNotificationsPush::Installation.mobile_device?(
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
      label: "Chrome on Mac"
    )
  end

  def test_registration_requires_a_recipient_and_a_firebase_installation_id
    error = assert_raises(ArgumentError) do
      RecordingStudioNotificationsPush::Installation.upsert!(
        recipient: nil,
        firebase_installation_id: "fid-1"
      )
    end
    assert_match(/recipient is required/, error.message)

    error = assert_raises(ArgumentError) do
      RecordingStudioNotificationsPush::Installation.upsert!(
        recipient: Object.new,
        firebase_installation_id: " "
      )
    end
    assert_match(/firebase_installation_id is required/, error.message)
  end

  def test_label_from_user_agent_names_common_browsers_and_systems
    expectations = {
      edge_on_windows => "Edge on Windows",
      firefox_on_linux => "Firefox on Linux",
      safari_on_ipad => "Safari on iPad",
      safari_on_ipod => "Safari on iPhone",
      chrome_on_android => "Chrome on Android",
      unknown_browser_on_linux => "Browser on Linux",
      chrome_on_chrome_os => "Chrome on device"
    }

    expectations.each do |user_agent, label|
      assert_equal label, RecordingStudioNotificationsPush::Installation.label_from_user_agent(user_agent)
    end
    assert_nil RecordingStudioNotificationsPush::Installation.label_from_user_agent(nil)
    assert_nil RecordingStudioNotificationsPush::Installation.label_from_user_agent("  ")
    assert_equal "Firefox",
                 RecordingStudioNotificationsPush::Installation.browser_name_from_user_agent(firefox_on_linux)
    assert_equal "Linux", RecordingStudioNotificationsPush::Installation.os_name_from_user_agent(firefox_on_linux)
  end

  def test_display_label_ignores_a_raw_user_agent_and_falls_back_to_browser
    raw = installation_with(label: "a" * 49, user_agent: nil, platform: "web")
    unnamed = installation_with(label: nil, user_agent: nil, platform: nil)

    assert_equal "web", raw.display_label
    assert_equal "Browser", unnamed.display_label
  end

  def test_list_icon_follows_the_device
    phone = installation_with(
      label: "Safari on iPhone",
      user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)",
      platform: "ios"
    )
    desktop = installation_with(
      label: "Chrome on Mac",
      user_agent: chrome_mac_user_agent,
      platform: "web"
    )

    assert phone.mobile?
    assert_equal :device_phone_mobile, phone.list_icon
    refute desktop.mobile?
    assert_equal :computer_desktop, desktop.list_icon
  end

  private

  def installation_with(label:, user_agent:, platform: nil)
    recording = RecordingStudioNotificationsPush::Installation.allocate
    recording.define_singleton_method(:label) { label }
    recording.define_singleton_method(:user_agent) { user_agent }
    recording.define_singleton_method(:platform) { platform }
    recording
  end

  def edge_on_windows
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " \
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"
  end

  def firefox_on_linux
    "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0"
  end

  def safari_on_ipad
    "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " \
      "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
  end

  def safari_on_ipod
    "Mozilla/5.0 (iPod touch; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " \
      "Version/17.0 Mobile/15E148 Safari/604.1"
  end

  def chrome_on_android
    "Mozilla/5.0 (Linux; Android 14; Pixel) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36"
  end

  def unknown_browser_on_linux
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
  end

  def chrome_on_chrome_os
    "Mozilla/5.0 (X11; CrOS x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  end

  def chrome_mac_user_agent
    [
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
      "AppleWebKit/537.36 (KHTML, like Gecko)",
      "Chrome/120.0.0.0 Safari/537.36"
    ].join(" ")
  end
end
