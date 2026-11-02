# frozen_string_literal: true

require "test_helper"

class HttpTest < Minitest::Test
  def test_build_uses_ssl_only_for_https
    https = RecordingStudioNotificationsPush::Http.build(
      URI("https://fcm.googleapis.com/v1"),
      open_timeout: 1,
      read_timeout: 2,
      write_timeout: 3
    )
    http = RecordingStudioNotificationsPush::Http.build(
      URI("http://127.0.0.1/token"),
      open_timeout: 1,
      read_timeout: 2,
      write_timeout: 3
    )

    assert https.use_ssl?
    refute http.use_ssl?
    assert_equal 1, https.open_timeout
    assert_equal 2, https.read_timeout
  end
end
