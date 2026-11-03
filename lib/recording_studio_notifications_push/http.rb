# frozen_string_literal: true

require "net/http"

module RecordingStudioNotificationsPush
  module Http
    module_function

    def build(uri, open_timeout:, read_timeout:, write_timeout:)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = open_timeout
      http.read_timeout = read_timeout
      http.write_timeout = write_timeout if http.respond_to?(:write_timeout=)
      http
    end

    def absolute_https?(url)
      uri = URI.parse(url.to_s)
      uri.is_a?(URI::HTTPS) && uri.host.present?
    rescue URI::InvalidURIError
      false
    end
  end
end
