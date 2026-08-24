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

    # Sends one FCM HTTP v1 message. Returns a result hash:
    #   { ok: true/false, status: Integer, body: Hash, disable: Boolean }
    def send_message(token:, title:, body: nil, url: nil, data: {})
      raise DeliveryError, "FCM token is required" if token.to_s.strip.blank?
      raise DeliveryError, "FIREBASE_PROJECT_ID is required to send push notifications" if project_id.blank?

      payload = {
        message: {
          token: token.to_s,
          notification: {
            title: title.to_s,
            body: body.to_s
          }.compact,
          data: stringify_data(data.merge("title" => title, "body" => body, "url" => url).compact),
          webpush: webpush_options(url)
        }.compact
      }

      response = post_json(messages_uri, payload)
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
      provider = @access_token_provider || default_access_token_provider
      provider.fetch
    end

    def default_access_token_provider
      json = @configuration.firebase_service_account_json
      if json.to_s.strip.blank?
        raise DeliveryError,
              "FIREBASE_SERVICE_ACCOUNT_JSON is required to send push notifications"
      end

      @default_access_token_provider ||= GoogleAccessToken.new(
        service_account_json: json,
        open_timeout: @configuration.open_timeout,
        read_timeout: @configuration.read_timeout,
        write_timeout: @configuration.write_timeout
      )
    end

    def post_json(uri, payload)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = @configuration.open_timeout
      http.read_timeout = @configuration.read_timeout
      http.write_timeout = @configuration.write_timeout if http.respond_to?(:write_timeout=)

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json; charset=utf-8"
      request.body = JSON.generate(payload)

      http.request(request)
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => error
      raise DeliveryError, "FCM network error: #{error.message}"
    end

    def parse_response(response)
      body = parse_json_body(response.body)
      ok = response.is_a?(Net::HTTPSuccess)
      error_status = body.dig("error", "status").to_s
      error_code = Array(body.dig("error", "details")).filter_map { |detail| detail["errorCode"] }.first
      disable = %w[UNREGISTERED NOT_FOUND].include?(error_status) ||
                %w[UNREGISTERED NOT_FOUND].include?(error_code.to_s)

      {
        ok: ok,
        status: response.code.to_i,
        body: body,
        disable: disable,
        error_message: body.dig("error", "message")
      }
    end

    def parse_json_body(raw)
      JSON.parse(raw.to_s.presence || "{}")
    rescue JSON::ParserError
      { "raw" => raw.to_s }
    end

    def stringify_data(hash)
      hash.each_with_object({}) do |(key, value), result|
        next if value.nil?

        result[key.to_s] = value.is_a?(String) ? value : value.to_s
      end
    end

    def webpush_options(url)
      return if url.blank?

      {
        fcm_options: { link: url.to_s }
      }
    end
  end
end
