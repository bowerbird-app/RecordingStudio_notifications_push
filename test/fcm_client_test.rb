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
    assert_nil payload.dig("message", "webpush", "fcm_options")
    assert_equal "high", payload.dig("message", "webpush", "headers", "Urgency")
  end

  def test_https_open_link_is_the_only_fcm_link
    captured = nil
    fake_http = http_double
    response = fake_http_message(code: "200", body: "{}", success: true)
    fake_http.define_singleton_method(:request) do |request|
      captured = request
      response
    end

    Net::HTTP.stub(:new, ->(*) { fake_http }) do
      @client.send_message(
        token: "fid-1",
        title: "Hello",
        url: "/pages/1",
        link: "https://push.example/notifications/n1/open"
      )
    end

    payload = JSON.parse(captured.body)
    assert_equal "/pages/1", payload.dig("message", "data", "url")
    assert_equal "https://push.example/notifications/n1/open", payload.dig("message", "webpush", "fcm_options", "link")
  end

  def test_http_open_link_is_left_out_of_fcm_options
    captured = nil
    fake_http = http_double
    response = fake_http_message(code: "200", body: "{}", success: true)
    fake_http.define_singleton_method(:request) do |request|
      captured = request
      response
    end

    Net::HTTP.stub(:new, ->(*) { fake_http }) do
      @client.send_message(token: "fid-1", title: "Hello", url: "/pages/1", link: "http://push.example/notifications/n1/open")
    end

    payload = JSON.parse(captured.body)
    assert_nil payload.dig("message", "webpush", "fcm_options")
  end

  def http_double
    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:open_timeout=) { |_| }
    fake_http.define_singleton_method(:read_timeout=) { |_| }
    fake_http.define_singleton_method(:write_timeout=) { |_| }
    fake_http
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

  def test_requires_a_token
    error = assert_raises(RecordingStudioNotificationsPush::DeliveryError) do
      @client.send_message(token: "  ", title: "Hello")
    end
    assert_match(/FCM token is required/, error.message)
  end

  def test_project_id_can_come_from_the_web_config
    @configuration.firebase_project_id = nil
    @configuration.firebase_web_config = { "projectId" => "from-web-config" }
    captured = nil
    fake_http = http_double
    response = fake_http_message(code: "200", body: "{}", success: true)
    fake_http.define_singleton_method(:request) do |request|
      captured = request
      response
    end

    Net::HTTP.stub(:new, ->(*) { fake_http }) do
      assert @client.send_message(token: "fid-1", title: "Hello")[:ok]
    end

    assert_includes captured.path, "/v1/projects/from-web-config/messages:send"
  end

  def test_unregistered_error_code_marks_the_token_disabled
    fake_http = http_double
    response = fake_http_message(
      code: "403",
      success: false,
      body: JSON.generate(
        "error" => {
          "status" => "PERMISSION_DENIED",
          "message" => "permission denied",
          "details" => [{ "errorCode" => "UNREGISTERED" }]
        }
      )
    )
    fake_http.define_singleton_method(:request) { |_request| response }

    Net::HTTP.stub(:new, ->(*) { fake_http }) do
      result = @client.send_message(token: "fid-gone", title: "Hello")
      refute result[:ok]
      assert result[:disable]
      assert_equal "permission denied", result[:error_message]
    end
  end

  def test_non_json_response_is_returned_as_raw_text
    fake_http = http_double
    response = fake_http_message(code: "502", success: false, body: "<html>bad gateway</html>")
    fake_http.define_singleton_method(:request) { |_request| response }

    Net::HTTP.stub(:new, ->(*) { fake_http }) do
      result = @client.send_message(token: "fid-1", title: "Hello")
      refute result[:ok]
      refute result[:disable]
      assert_equal "<html>bad gateway</html>", result[:body]["raw"]
    end
  end

  def test_network_errors_are_delivery_errors
    fake_http = http_double
    fake_http.define_singleton_method(:request) { |_request| raise Errno::ECONNREFUSED }

    Net::HTTP.stub(:new, ->(*) { fake_http }) do
      error = assert_raises(RecordingStudioNotificationsPush::DeliveryError) do
        @client.send_message(token: "fid-1", title: "Hello")
      end
      assert_match(/FCM network error/, error.message)
    end
  end

  def test_send_message_exchanges_a_service_account_when_no_token_provider_is_injected
    rsa = OpenSSL::PKey::RSA.new(2048)
    configuration = RecordingStudioNotificationsPush::Configuration.new
    configuration.firebase_project_id = "demo-project"
    configuration.firebase_service_account_json = {
      "client_email" => "push-tests@example.iam.gserviceaccount.com",
      "private_key" => rsa.to_pem,
      "token_uri" => "https://oauth2.googleapis.com/token"
    }
    client = RecordingStudioNotificationsPush::FcmClient.new(configuration: configuration)
    token_requests = []
    fcm_requests = []

    Net::HTTP.stub(:new, lambda { |host, _port|
      fake = http_double
      if host == "oauth2.googleapis.com"
        response = fake_http_message(
          code: "200",
          success: true,
          body: JSON.generate("access_token" => "ya29.from-exchange", "expires_in" => 3600)
        )
        fake.define_singleton_method(:request) do |request|
          token_requests << request
          response
        end
      else
        body = JSON.generate("name" => "projects/demo/messages/1")
        response = fake_http_message(code: "200", success: true, body: body)
        fake.define_singleton_method(:request) do |request|
          fcm_requests << request
          response
        end
      end
      fake
    }) do
      assert client.send_message(token: "fid-from-test", title: "Hello")[:ok]
      assert client.send_message(token: "fid-from-test", title: "Hello again")[:ok]
    end

    assert_equal 1, token_requests.size
    assert_equal "Bearer ya29.from-exchange", fcm_requests.first["Authorization"]
    assert_includes fcm_requests.first.path, "/v1/projects/demo-project/messages:send"
    assert_equal 2, fcm_requests.size
  end
end
