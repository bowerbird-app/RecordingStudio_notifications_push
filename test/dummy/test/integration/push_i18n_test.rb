# frozen_string_literal: true

require "test_helper"
require "cgi"
require "devise/test/integration_helpers"
require "json"
require "yaml"

class PushI18nTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    sign_in @user
  end

  test "language selector sits in the dummy top nav left of the theme selector" do
    get "/"

    assert_response :success
    assert_select "form[action='/recording_studio_internationalization/locale']" do |forms|
      assert_select forms, "button", count: 0
      assert_select forms, "label", count: 0
      assert_select forms, "select[aria-label='Language']" do |selects|
        assert_includes selects.first["class"].to_s, "py-[var(--button-padding-y-sm)]"
      end
      assert_nil forms.first["style"]
    end
    refute_includes response.body, "Change language"
    assert_includes response.body, "English"
    assert_includes response.body, "Français"
    assert_select "html[lang='en']"
    selector_at = response.body.index("dummy-language-selector")
    theme_at = response.body.index("dummy-theme-selector")
    assert selector_at
    assert theme_at
    assert_operator selector_at, :<, theme_at
    inline = css_select("form[data-controller='dummy-language-selector']").find { |form|
      form.ancestors.any? { |ancestor| ancestor["class"].to_s.split.include?("md:block") }
    }
    assert inline, "desktop top bar should keep the language select"
    in_cog = css_select("[data-controller~='flat-pack--theme'] form[data-controller='dummy-language-selector']").find { |form|
      form.ancestors.any? { |ancestor| ancestor["class"].to_s.split.include?("md:hidden") }
    }
    assert in_cog, "phones should keep the language select in the cog menu"

    assert_select "[role='radiogroup'][aria-label='Theme']" do
      assert_select "[data-theme-value='system'][role='radio'][aria-checked='true']" do |items|
        assert_select items, "svg"
        assert_equal "true", items.first["aria-checked"]
      end
      assert_select "[data-theme-value='light'][role='radio'][aria-checked='false']" do |items|
        assert_select items, "svg"
        assert_equal "false", items.first["aria-checked"]
      end
      assert_select "[data-theme-value='dark'][role='radio'][aria-checked='false']" do |items|
        assert_select items, "svg"
        assert_equal "false", items.first["aria-checked"]
      end
    end
    sheet = css_select("link[rel=stylesheet]").map { |node| node["href"].to_s }.find { |href|
      href.include?("application-")
    }
    assert sheet, "the dummy stylesheet should be linked"
    get sheet
    assert_includes response.body, ':where([data-controller~="dummy-theme-menu"] [role=radio][aria-checked=false])'
    refute_includes response.body, ":where([role=radio][aria-checked=false])"
    get "/"

    assert_select "[role='menuitemradio']", count: 0
    assert_select "[data-theme-value='rounded']", count: 0
    assert_includes response.body, ">Theme<"
    refute_includes response.body, ">Shape<"

    language_labels = css_select("[data-controller~='flat-pack--theme'] p").select { |node|
      node.text.strip == "Language"
    }
    assert_equal 1, language_labels.size
    assert language_labels.first.ancestors.any? { |ancestor|
      ancestor["class"].to_s.split.include?("md:hidden")
    }, "the Language heading should sit in the phone-only menu panel"

    cog_select = css_select("[data-controller~='flat-pack--theme'] select[aria-label='Language']").first
    assert cog_select, "the cog menu should include the language select"
    refute_includes cog_select["class"].to_s, "py-[var(--button-padding-y-sm)]"
    assert_includes cog_select["class"].to_s, "border-[var(--surface-border-color)]"
  end

  test "devices page stays English until the host locale changes" do
    get "/notifications/push/devices"

    assert_response :success
    assert_includes response.body, "Connected devices"
    assert_includes response.body, "Your connected devices that can receive notifications"
    assert_includes response.body, "Manage notifications"
    assert_includes unescaped_body, 'document.documentElement.lang = "en"'
    refute_includes response.body, "Appareils connectés"
  end

  test "dummy French locale renders the devices opt-in copy" do
    switch_to_french

    get "/notifications/push/devices"

    assert_response :success
    assert_includes unescaped_body, 'document.documentElement.lang = "fr"'
    assert_includes response.body, "Appareils connectés"
    assert_includes response.body, "Vos appareils connectés qui peuvent recevoir des notifications"
    assert_includes response.body, "Gérer les notifications"
    refute_includes response.body, "Connected devices"
    refute_includes response.body, "Manage notifications"
  end

  test "js copy on the devices page comes from I18n" do
    get "/notifications/push/devices"

    assert_response :success
    payload = copy_payload(response.body)
    assert_equal "Enable on this browser", payload.fetch("enable_browser")
    assert_equal "This browser does not support notifications.", payload.fetch("unsupported_notifications")
    assert_equal "Notifications are blocked for this site. Allow them in your browser settings, then try again.",
                 payload.fetch("permission_denied")

    switch_to_french
    get "/notifications/push/devices"

    french = copy_payload(response.body)
    assert_equal "Activer sur ce navigateur", french.fetch("enable_browser")
    assert_equal "Ce navigateur ne prend pas en charge les notifications.", french.fetch("unsupported_notifications")
    assert_equal "Les notifications sont bloquées pour ce site. Autorisez-les dans les réglages du navigateur, puis réessayez.",
                 french.fetch("permission_denied")
    refute_equal payload.fetch("enable_browser"), french.fetch("enable_browser")
  end

  test "stored installation labels stay as written after a locale switch" do
    stored_label = "Jo test tablet"
    RecordingStudioNotificationsPush::Installation.upsert!(
      recipient: @user,
      firebase_installation_id: "fid-i18n-stored-label",
      label: stored_label
    )

    switch_to_french
    get "/notifications/push/devices"

    assert_response :success
    assert_includes response.body, stored_label
    assert_includes response.body, "Appareils connectés"
  end

  test "copy argument overrides still win" do
    assert_equal "Acme devices",
                 RecordingStudioNotificationsPush::Copy.value("Acme devices", "devices.title")
    assert_nil RecordingStudioNotificationsPush::Copy.value(nil, "devices.title")
  end

  test "dummy french file covers every engine english key" do
    engine_en = File.expand_path("../../../../config/locales/en.yml", __dir__)
    dummy_fr = File.expand_path("../../config/locales/fr.yml", __dir__)
    english = flatten_keys(locale_tree(engine_en, "en"))
    french = flatten_keys(locale_tree(dummy_fr, "fr"))

    assert_empty english - french
  end

  private

  def switch_to_french
    patch "/recording_studio_internationalization/locale", params: { locale: "fr", return_to: "/" }
    follow_redirect!
  end

  def unescaped_body
    CGI.unescapeHTML(response.body)
  end

  def copy_payload(html)
    match = html.match(
      /data-recording-studio-notifications-push--push-devices-copy-value="([^"]+)"/
    )
    assert match, "devices page is missing the Stimulus copy value"
    JSON.parse(CGI.unescapeHTML(match[1]))
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
end
