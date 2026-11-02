# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module RecordingStudioNotificationsPush
  class FcmClient
    FCM_SCOPE_HOST = "https://fcm.googleapis.com"

    def initialize(configuration: RecordingStudioNotificationsPush.configuration,
                   access_token_provider: nil)
      @configuration = configuration
      @access_token_provider = access_token_provider
    end

    # Sends one FCM HTTP v1 message. Result keys: ok, status, body, disable.
    # link: nil stays an explicit keyword so a missing open URL is not omitted.
    def send_message(token:, title: nil, body: nil, url: nil, link: nil, data: nil) # rubocop:disable Metrics/ParameterLists
      raise DeliveryError, "FCM token is required" if token.to_s.strip.blank?
      raise DeliveryError, "FIREBASE_PROJECT_ID is required to send push notifications" if project_id.blank?

      message = { title: title, body: body, url: url, link: link, data: data }
      response = post_json(messages_uri, Payload.body(token, message))
      parse_response(response)
    end

    private

    def project_id
      @configuration.firebase_project_id.to_s.strip.presence ||
        @configuration.firebase_web_config[:projectId].to_s.strip.presence ||
        @configuration.firebase_web_config["projectId"].to_s.strip.presence
    end

    def messages_uri
      URI.parse("#{FCM_SCOPE_HOST}/v1/projects/#{project_id}/messages:send")
    end

    def access_token
      (@access_token_provider || default_access_token_provider).fetch
    end

    def default_access_token_provider
      json = @configuration.firebase_service_account_json
      if json.to_s.strip.blank?
        raise DeliveryError, "FIREBASE_SERVICE_ACCOUNT_JSON is required to send push notifications"
      end

      @default_access_token_provider ||= GoogleAccessToken.new(
        service_account_json: json,
        open_timeout: @configuration.open_timeout,
        read_timeout: @configuration.read_timeout,
        write_timeout: @configuration.write_timeout
      )
    end

    def post_json(uri, payload)
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json; charset=utf-8"
      request.body = JSON.generate(payload)
      build_http(uri).request(request)
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
      raise DeliveryError, "FCM network error: #{e.message}"
    end

    def build_http(uri)
      Http.build(
        uri,
        open_timeout: @configuration.open_timeout,
        read_timeout: @configuration.read_timeout,
        write_timeout: @configuration.write_timeout
      )
    end

    def http_success?(response)
      response.is_a?(Net::HTTPSuccess)
    end

    def parse_response(response)
      body = parse_json_body(response.body)
      {
        ok: http_success?(response),
        status: response.code.to_i,
        body: body,
        disable: disable_token?(body),
        error_message: body.dig("error", "message")
      }
    end

    def disable_token?(body)
      error_status = body.dig("error", "status").to_s
      error_code = Array(body.dig("error", "details")).filter_map { |detail| detail["errorCode"] }.first.to_s
      error_message = body.dig("error", "message").to_s
      %w[UNREGISTERED NOT_FOUND].include?(error_status) || %w[UNREGISTERED NOT_FOUND].include?(error_code) ||
        (error_status == "INVALID_ARGUMENT" && /not a valid fcm registration token/i.match?(error_message))
    end

    def parse_json_body(raw)
      JSON.parse(raw.to_s.presence || "{}")
    rescue JSON::ParserError
      { "raw" => raw.to_s }
    end
  end
end

require_relative "fcm_client/payload"
