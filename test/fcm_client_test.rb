# frozen_string_literal: true

require "test_helper"
require "json"

class FcmClientTest < Minitest::Test
  include HttpResponseDouble
  class FakeAccessToken
    def fetch
      "ya29.test"
    end
  end

  def setup
    @configuration = RecordingStudioNotificationsPush::Configuration.new
    @configuration.firebase_project_id = "demo-project"
    @configuration.firebase_service_account_json = '{"type":"service_account"}'
    @client = RecordingStudioNotificationsPush::FcmClient.new(
      configuration: @configuration,
      access_token_provider: FakeAccessToken.new
    )
  end

  def test_send_message_posts_fcm_v1_payload
    captured = nil
    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:open_timeout=) { |_| }
    fake_http.define_singleton_method(:read_timeout=) { |_| }
    fake_http.define_singleton_method(:write_timeout=) { |_| }
    response = fake_http_message(code: "200", body: JSON.generate("name" => "projects/demo/messages/1"), success: true)
    fake_http.define_singleton_method(:request) do |request|
      captured = request
      response
    end

    Net::HTTP.stub(:new, ->(*) { fake_http }) do
      result = @client.send_message(token: "fid-1", title: "Hello", body: "World", url: "/x")
      assert result[:ok]
      assert_equal 200, result[:status]
    end

    assert_equal "Bearer ya29.test", captured["Authorization"]
    payload = JSON.parse(captured.body)
    assert_equal "fid-1", payload.dig("message", "token")
    refute payload.dig("message", "notification")
    assert_equal "Hello", payload.dig("message", "data", "title")
    assert_equal "World", payload.dig("message", "data", "body")
    assert_equal "/x", payload.dig("message", "data", "url")
    assert_equal "/x", payload.dig("message", "webpush", "fcm_options", "link")
    assert_equal "high", payload.dig("message", "webpush", "headers", "Urgency")
  end

  def test_invalid_registration_token_marks_disable
    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:open_timeout=) { |_| }
    fake_http.define_singleton_method(:read_timeout=) { |_| }
    fake_http.define_singleton_method(:write_timeout=) { |_| }
    response = fake_http_message(
      code: "400",
      success: false,
      body: JSON.generate(
        "error" => {
          "status" => "INVALID_ARGUMENT",
          "message" => "The registration token is not a valid FCM registration token"
        }
      )
    )
    fake_http.define_singleton_method(:request) { |_request| response }

    Net::HTTP.stub(:new, ->(*) { fake_http }) do
      result = @client.send_message(token: "test-fid-home-demo", title: "Hello")
      refute result[:ok]
      assert result[:disable]
    end
  end

  def test_unregistered_marks_disable
    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:open_timeout=) { |_| }
    fake_http.define_singleton_method(:read_timeout=) { |_| }
    fake_http.define_singleton_method(:write_timeout=) { |_| }
    response = fake_http_message(
      code: "404",
      success: false,
      body: JSON.generate("error" => { "status" => "NOT_FOUND", "message" => "Requested entity was not found." })
    )
    fake_http.define_singleton_method(:request) { |_request| response }

    Net::HTTP.stub(:new, ->(*) { fake_http }) do
      result = @client.send_message(token: "fid-gone", title: "Hello")
      refute result[:ok]
      assert result[:disable]
    end
  end

  def test_requires_project_id
    @configuration.firebase_project_id = nil
    @configuration.firebase_web_config = {}

    error = assert_raises(RecordingStudioNotificationsPush::DeliveryError) do
      @client.send_message(token: "fid-1", title: "Hello")
    end
    assert_match(/FIREBASE_PROJECT_ID/, error.message)
  end
end
