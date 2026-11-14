# frozen_string_literal: true

require "test_helper"
require "json"
require "openssl"
require "base64"

class GoogleAccessTokenTest < Minitest::Test
  include HttpResponseDouble

  def setup
    @rsa = OpenSSL::PKey::RSA.new(2048)
    @service_account = {
      "type" => "service_account",
      "project_id" => "demo-project",
      "private_key_id" => "key-id",
      "private_key" => @rsa.to_pem,
      "client_email" => "firebase-adminsdk@demo-project.iam.gserviceaccount.com",
      "client_id" => "123456789",
      "token_uri" => "https://oauth2.googleapis.com/token"
    }
  end

  def test_builds_and_exchanges_jwt_for_access_token
    provider = RecordingStudioNotificationsPush::GoogleAccessToken.new(
      service_account_json: JSON.generate(@service_account)
    )

    captured_assertion = nil
    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:open_timeout=) { |_| }
    fake_http.define_singleton_method(:read_timeout=) { |_| }
    fake_http.define_singleton_method(:write_timeout=) { |_| }
    response = fake_http_message(
      code: "200",
      success: true,
      body: JSON.generate("access_token" => "ya29.test-token", "expires_in" => 3600, "token_type" => "Bearer")
    )
    fake_http.define_singleton_method(:request) do |request|
      captured_assertion = request.body[/assertion=([^&]+)/, 1]
      response
    end

    Net::HTTP.stub(:new, ->(*) { fake_http }) do
      token = provider.fetch
      assert_equal "ya29.test-token", token
    end

    assert captured_assertion
    decoded_assertion = URI.decode_www_form_component(captured_assertion)
    header_b64, claims_b64, signature_b64 = decoded_assertion.split(".")
    claims = JSON.parse(Base64.urlsafe_decode64(claims_b64))
    assert_equal @service_account.fetch("client_email"), claims.fetch("iss")
    assert_equal "https://www.googleapis.com/auth/firebase.messaging", claims.fetch("scope")

    signing_input = "#{header_b64}.#{claims_b64}"
    signature = Base64.urlsafe_decode64(signature_b64)
    assert @rsa.verify(OpenSSL::Digest.new("SHA256"), signature, signing_input)
  end

  def test_rejects_invalid_service_account_json
    assert_raises(ArgumentError) do
      RecordingStudioNotificationsPush::GoogleAccessToken.new(service_account_json: "{not-json")
    end
  end

  def test_caches_token_until_expiry
    provider = RecordingStudioNotificationsPush::GoogleAccessToken.new(
      service_account_json: @service_account
    )

    calls = 0
    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:open_timeout=) { |_| }
    fake_http.define_singleton_method(:read_timeout=) { |_| }
    fake_http.define_singleton_method(:write_timeout=) { |_| }
    response = fake_http_message(
      code: "200",
      success: true,
      body: JSON.generate("access_token" => "cached-token", "expires_in" => 3600)
    )
    fake_http.define_singleton_method(:request) do |_request|
      calls += 1
      response
    end

    Net::HTTP.stub(:new, ->(*) { fake_http }) do
      assert_equal "cached-token", provider.fetch
      assert_equal "cached-token", provider.fetch
    end

    assert_equal 1, calls
  end

  def test_accepts_service_account_hash_with_symbol_keys
    with_token_response(service_account: {
                          client_email: @service_account.fetch("client_email"),
                          private_key: @service_account.fetch("private_key")
                        }) do |provider, _requests, endpoints|
      assert_equal "ya29.fake", provider.fetch
      assert_equal ["oauth2.googleapis.com", 443], endpoints.first
    end
  end

  def test_clear_exchanges_the_token_again
    with_token_response do |provider, requests|
      assert_equal "ya29.fake", provider.fetch
      assert_equal "ya29.fake", provider.fetch
      provider.clear!
      assert_equal "ya29.fake", provider.fetch
      assert_equal 2, requests.size
    end
  end

  def test_a_short_lived_token_is_exchanged_again
    body = JSON.generate("access_token" => "ya29.short", "expires_in" => 30)

    with_token_response(body: body) do |provider, requests|
      assert_equal "ya29.short", provider.fetch
      assert_equal "ya29.short", provider.fetch
      assert_equal 2, requests.size
    end
  end

  def test_caches_when_the_response_omits_expires_in
    body = JSON.generate("access_token" => "ya29.default-ttl")

    with_token_response(body: body) do |provider, requests|
      assert_equal "ya29.default-ttl", provider.fetch
      assert_equal "ya29.default-ttl", provider.fetch
      assert_equal 1, requests.size
    end
  end

  def test_rejects_a_token_response_without_an_access_token
    body = JSON.generate("token_type" => "Bearer")

    with_token_response(body: body) do |provider|
      error = assert_raises(RecordingStudioNotificationsPush::DeliveryError) { provider.fetch }
      assert_match(/token exchange failed/, error.message)
    end
  end

  def test_reports_the_oauth_error_description
    body = JSON.generate("error" => "invalid_grant", "error_description" => "bad assertion")

    with_token_response(code: "400", body: body) do |provider|
      error = assert_raises(RecordingStudioNotificationsPush::DeliveryError) { provider.fetch }
      assert_match(/bad assertion/, error.message)
    end
  end

  def test_reports_the_oauth_error_when_there_is_no_description
    body = JSON.generate("error" => "invalid_client")

    with_token_response(code: "401", body: body) do |provider|
      error = assert_raises(RecordingStudioNotificationsPush::DeliveryError) { provider.fetch }
      assert_match(/invalid_client/, error.message)
    end
  end

  def test_reports_the_http_status_when_the_oauth_body_has_no_error
    with_token_response(code: "503", body: "{}") do |provider|
      error = assert_raises(RecordingStudioNotificationsPush::DeliveryError) { provider.fetch }
      assert_match(/HTTP 503/, error.message)
    end
  end

  def test_reports_invalid_json_from_the_token_endpoint
    with_token_response(body: "not-json") do |provider|
      error = assert_raises(RecordingStudioNotificationsPush::DeliveryError) { provider.fetch }
      assert_match(/invalid JSON/, error.message)
    end
  end

  def test_reports_a_network_failure_without_calling_google
    with_token_response(error: SocketError.new("getaddrinfo: name resolution failed")) do |provider|
      error = assert_raises(RecordingStudioNotificationsPush::DeliveryError) { provider.fetch }
      assert_match(/network error: getaddrinfo: name resolution failed/, error.message)
    end
  end

  def test_refuses_a_service_account_without_an_email_or_key
    error = assert_raises(ArgumentError) do
      RecordingStudioNotificationsPush::GoogleAccessToken.new(
        service_account_json: { "private_key" => @rsa.to_pem }
      )
    end
    assert_match(/client_email/, error.message)

    error = assert_raises(ArgumentError) do
      RecordingStudioNotificationsPush::GoogleAccessToken.new(
        service_account_json: { "client_email" => "push-tests@example.iam.gserviceaccount.com" }
      )
    end
    assert_match(/private_key/, error.message)

    error = assert_raises(ArgumentError) do
      RecordingStudioNotificationsPush::GoogleAccessToken.new(
        service_account_json: { "client_email" => "  ", "private_key" => @rsa.to_pem }
      )
    end
    assert_match(/client_email/, error.message)
  end

  def test_refuses_an_unreadable_private_key
    provider = RecordingStudioNotificationsPush::GoogleAccessToken.new(
      service_account_json: @service_account.merge("private_key" => "not-a-pem")
    )

    error = assert_raises(ArgumentError) { provider.fetch }
    assert_match(/private_key is invalid/, error.message)
  end

  def test_posts_the_assertion_to_the_service_account_token_uri
    account = @service_account.merge("token_uri" => "https://oauth.example.test/token")

    with_token_response(service_account: account) do |provider, requests, endpoints|
      provider.fetch

      assert_equal [["oauth.example.test", 443]], endpoints
      form = URI.decode_www_form(requests.first.body).to_h
      assert_equal "urn:ietf:params:oauth:grant-type:jwt-bearer", form.fetch("grant_type")
      claims = JSON.parse(Base64.urlsafe_decode64(form.fetch("assertion").split(".")[1]))
      assert_equal "https://oauth.example.test/token", claims.fetch("aud")
    end
  end

  def test_uses_the_google_token_endpoint_when_the_account_omits_one
    account = @service_account.except("token_uri")

    with_token_response(service_account: account) do |provider, _requests, endpoints|
      provider.fetch
      assert_equal [["oauth2.googleapis.com", 443]], endpoints
    end
  end

  private

  def with_token_response(service_account: @service_account, code: "200", body: nil, error: nil)
    payload = body || JSON.generate("access_token" => "ya29.fake", "expires_in" => 3600)
    requests = []
    endpoints = []
    fake = Object.new
    %i[use_ssl= open_timeout= read_timeout= write_timeout=].each do |setter|
      fake.define_singleton_method(setter) { |_| }
    end
    response = fake_http_message(code: code, success: code.start_with?("2"), body: payload)
    fake.define_singleton_method(:request) do |request|
      requests << request
      raise error if error

      response
    end

    provider = RecordingStudioNotificationsPush::GoogleAccessToken.new(service_account_json: service_account)
    Net::HTTP.stub(:new, lambda { |host, port|
      endpoints << [host, port]
      fake
    }) do
      yield provider, requests, endpoints
    end
  end
end
