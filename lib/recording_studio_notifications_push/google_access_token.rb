# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "openssl"
require "uri"

module RecordingStudioNotificationsPush
  # Exchanges a Firebase service-account JSON key for an OAuth access token.
  class GoogleAccessToken
    TOKEN_URI = "https://oauth2.googleapis.com/token"
    SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
    EXPIRY_SKEW = 60

    def initialize(service_account_json:, open_timeout: 5, read_timeout: 15, write_timeout: 15)
      @credentials = parse_credentials(service_account_json)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @write_timeout = write_timeout
      @mutex = Mutex.new
      @cached_token = nil
      @expires_at = Time.at(0)
    end

    def fetch
      @mutex.synchronize do
        return @cached_token if @cached_token.present? && Time.now < (@expires_at - EXPIRY_SKEW)

        response = exchange_jwt!(build_jwt)
        @cached_token = response.fetch("access_token")
        @expires_at = Time.now + Integer(response.fetch("expires_in", 3600))
        @cached_token
      end
    end

    def clear!
      @mutex.synchronize do
        @cached_token = nil
        @expires_at = Time.at(0)
      end
    end

    private

    def parse_credentials(raw)
      payload = raw.is_a?(Hash) ? raw : JSON.parse(raw.to_s)
      credentials_from_payload(payload)
    rescue JSON::ParserError => e
      raise ArgumentError, "service account JSON is invalid: #{e.message}"
    end

    def credentials_from_payload(payload)
      data = payload.respond_to?(:with_indifferent_access) ? payload.with_indifferent_access : payload
      client_email = data["client_email"].to_s.strip
      private_key = data["private_key"].to_s
      raise ArgumentError, "service account JSON must include client_email" if client_email.blank?
      raise ArgumentError, "service account JSON must include private_key" if private_key.blank?

      {
        "client_email" => client_email,
        "private_key" => private_key,
        "token_uri" => data["token_uri"].presence || TOKEN_URI
      }
    end

    def build_jwt
      Assertion.new(@credentials).to_s
    end

    def exchange_jwt!(assertion)
      response = build_http(token_uri).request(token_request(assertion))
      parse_token_response!(response)
    rescue JSON::ParserError
      raise DeliveryError, "Google OAuth token exchange returned invalid JSON"
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
      raise DeliveryError, "Google OAuth token exchange network error: #{e.message}"
    end

    def token_uri
      URI.parse(@credentials.fetch("token_uri"))
    end

    def token_request(assertion)
      request = Net::HTTP::Post.new(token_uri.request_uri)
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request.set_form_data(
        "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion" => assertion
      )
      request
    end

    def build_http(uri)
      Http.build(
        uri,
        open_timeout: @open_timeout,
        read_timeout: @read_timeout,
        write_timeout: @write_timeout
      )
    end

    def http_success?(response)
      response.is_a?(Net::HTTPSuccess)
    end

    def parse_token_response!(response)
      body = JSON.parse(response.body.to_s)
      return body if http_success?(response) && body["access_token"].present?

      message = body["error_description"] || body["error"] || "token exchange failed (HTTP #{response.code})"
      raise DeliveryError, "Google OAuth token exchange failed: #{message}"
    end
  end
end
