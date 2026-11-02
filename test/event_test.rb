# frozen_string_literal: true

require "test_helper"

class EventTest < Minitest::Test
  Notification = Struct.new(:id, :title, :body, :url, :recipient, :metadata, keyword_init: true)

  def test_wrap_normalizes_title_body_and_url
    event = RecordingStudioNotificationsPush::Event.wrap(
      Notification.new(
        id: "1",
        title: "Hi\nthere",
        body: "Body",
        url: "/safe",
        recipient: Object.new,
        metadata: { a: 1, icon: "/push-icon-coral.png" }
      )
    )

    assert_equal "1", event.id
    assert_equal "Hi there", event.title
    assert_equal "Body", event.body
    assert_equal "/safe", event.url
    assert_equal({ a: 1, icon: "/push-icon-coral.png" }, event.metadata)
    assert_equal "/push-icon-coral.png", event.icon
  end

  def test_blank_title_falls_back_to_locale_default
    event = RecordingStudioNotificationsPush::Event.wrap(
      Notification.new(id: "1", title: "  ")
    )

    assert_equal "Notification", event.title
  end

  def test_stored_title_is_not_replaced_by_locale
    event = RecordingStudioNotificationsPush::Event.wrap(
      Notification.new(id: "1", title: "Jo likes the new heading")
    )

    assert_equal "Jo likes the new heading", event.title
  end

  def test_drops_protocol_relative_and_javascript_urls
    javascript = RecordingStudioNotificationsPush::Event.wrap(
      Notification.new(id: "1", title: "T", url: "javascript:alert(1)", metadata: { icon: "javascript:alert(1)" })
    )
    protocol_relative = RecordingStudioNotificationsPush::Event.wrap(
      Notification.new(id: "1", title: "T", url: "//evil.example/x", metadata: { icon: "//evil.example/x" })
    )

    assert_nil javascript.url
    assert_nil javascript.icon
    assert_nil protocol_relative.url
    assert_nil protocol_relative.icon
  end

  def test_rejects_unsafe_urls
    event = RecordingStudioNotificationsPush::Event.wrap(
      Notification.new(id: "1", title: "T", url: "javascript:alert(1)")
    )

    assert_nil event.url
  end

  def test_rejects_unsafe_icons
    event = RecordingStudioNotificationsPush::Event.wrap(
      Notification.new(id: "1", title: "T", metadata: { icon: "javascript:alert(1)" })
    )

    assert_nil event.icon
  end

  def test_metadata_is_memoized
    notification = Notification.new(
      id: "1",
      title: "T",
      metadata: { icon: "/push-icon-coral.png" }
    )
    event = RecordingStudioNotificationsPush::Event.wrap(notification)

    assert_same event.metadata, event.metadata
    assert_equal "/push-icon-coral.png", event.icon
  end

  def test_drops_icons_on_hosts_outside_the_allowlist
    with_allowed_hosts(["cdn.example.com"]) do
      event = RecordingStudioNotificationsPush::Event.wrap(
        Notification.new(
          id: "1",
          title: "T",
          metadata: {
            icon: "https://127.0.0.1/push-icon-teal.png",
            image: "https://127.0.0.1/push-icon-teal.png"
          }
        )
      )

      assert_nil event.icon
      assert_nil event.image
    end
  end

  def test_allows_icons_on_allowlisted_https_hosts
    with_allowed_hosts(["cdn.example.com"]) do
      event = RecordingStudioNotificationsPush::Event.wrap(
        Notification.new(
          id: "1",
          title: "T",
          url: "https://cdn.example.com/open",
          metadata: {
            icon: "https://cdn.example.com/push-icon-teal.png",
            image: "https://cdn.example.com/wide.png"
          }
        )
      )

      assert_equal "https://cdn.example.com/open", event.url
      assert_equal "https://cdn.example.com/push-icon-teal.png", event.icon
      assert_equal "https://cdn.example.com/wide.png", event.image
    end
  end

  def test_drops_urls_with_control_characters
    event = RecordingStudioNotificationsPush::Event.wrap(
      Notification.new(id: "1", title: "T", url: "/safe\n", metadata: { icon: "/icon\u0000.png" })
    )

    assert_nil event.url
    assert_nil event.icon
  end

  private

  def with_allowed_hosts(hosts)
    configuration = RecordingStudioNotifications.configuration
    original = configuration.allowed_url_hosts
    configuration.allowed_url_hosts = hosts
    yield
  ensure
    configuration.allowed_url_hosts = original
  end
end
