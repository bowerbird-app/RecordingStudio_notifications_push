# frozen_string_literal: true

require "test_helper"

class TestPushTest < Minitest::Test
  class FakeInstallation
    attr_reader :seen_count

    def initialize(token:)
      @token = token
      @seen_count = 0
    end

    def delivery_token
      @token
    end

    def touch_seen!
      @seen_count += 1
    end
  end

  class FakeClient
    attr_reader :calls

    def initialize(result)
      @result = result
      @calls = []
    end

    def send_message(**keywords)
      @calls << keywords
      raise @result if @result.is_a?(StandardError)

      @result
    end
  end

  def test_reports_acceptance_and_touches_last_seen
    installation = FakeInstallation.new(token: "fid-1")
    client = FakeClient.new({ ok: true, status: 200, error_message: nil })

    result = RecordingStudioNotificationsPush::TestPush.new(client: client).call(installation: installation)

    assert result.accepted?
    assert_equal 200, result.status
    assert_nil result.error
    assert_equal 1, installation.seen_count
    assert_equal "fid-1", client.calls.first[:token]
    assert_equal RecordingStudioNotificationsPush::Copy.t("payloads.test_title"), client.calls.first[:title]
    assert_equal RecordingStudioNotificationsPush::Copy.t("payloads.test_body"), client.calls.first[:body]
  end

  def test_reports_refusal_with_the_fcm_message
    installation = FakeInstallation.new(token: "fid-bad")
    client = FakeClient.new(
      { ok: false, status: 400, error_message: "not a valid FCM registration token" }
    )

    result = RecordingStudioNotificationsPush::TestPush.new(client: client).call(installation: installation)

    refute result.accepted?
    assert_equal 400, result.status
    assert_match(/not a valid FCM registration token/, result.error)
    assert_equal 0, installation.seen_count
  end

  def test_falls_back_to_a_status_message_when_fcm_gives_none
    installation = FakeInstallation.new(token: "fid-1")
    client = FakeClient.new({ ok: false, status: 503, error_message: nil })

    result = RecordingStudioNotificationsPush::TestPush.new(client: client).call(installation: installation)

    refute result.accepted?
    assert_match(/HTTP 503/, result.error)
  end

  def test_reports_missing_token_without_calling_fcm
    installation = FakeInstallation.new(token: "  ")
    client = FakeClient.new({ ok: true, status: 200 })

    result = RecordingStudioNotificationsPush::TestPush.new(client: client).call(installation: installation)

    refute result.accepted?
    assert_match(/no push token/, result.error)
    assert_empty client.calls
  end

  def test_surfaces_delivery_errors_as_a_refusal
    installation = FakeInstallation.new(token: "fid-1")
    client = FakeClient.new(
      RecordingStudioNotificationsPush::DeliveryError.new("FIREBASE_SERVICE_ACCOUNT_JSON is required")
    )

    result = RecordingStudioNotificationsPush::TestPush.new(client: client).call(installation: installation)

    refute result.accepted?
    assert_match(/FIREBASE_SERVICE_ACCOUNT_JSON/, result.error)
  end

  def test_surfaces_invalid_service_account_json_as_a_refusal
    installation = FakeInstallation.new(token: "fid-1")
    client = FakeClient.new(ArgumentError.new("service account JSON is invalid: unexpected character"))

    result = RecordingStudioNotificationsPush::TestPush.new(client: client).call(installation: installation)

    refute result.accepted?
    assert_match(/service account JSON is invalid/, result.error)
  end

  def test_title_and_body_arguments_override_locale_defaults
    installation = FakeInstallation.new(token: "fid-1")
    client = FakeClient.new({ ok: true, status: 200, error_message: nil })

    RecordingStudioNotificationsPush::TestPush.new(
      client: client,
      title: "Acme ping",
      body: "Host body"
    ).call(installation: installation)

    assert_equal "Acme ping", client.calls.first[:title]
    assert_equal "Host body", client.calls.first[:body]
  end

  def test_result_hash_drops_blank_values
    result = RecordingStudioNotificationsPush::TestPush::Result.new(accepted: true, status: 200)

    assert_equal({ accepted: true, status: 200 }, result.to_h)
  end
end
