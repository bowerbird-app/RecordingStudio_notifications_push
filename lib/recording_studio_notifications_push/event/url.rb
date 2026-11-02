# frozen_string_literal: true

module RecordingStudioNotificationsPush
  class Event
    module Url
      private

      def meta_asset(key)
        value = metadata_string(key)
        return unless value
        return if unsafe_url_characters?(value)
        return value if same_origin_path?(value)
        return value if fallback_url_safe?(value)

        nil
      rescue URI::InvalidURIError
        nil
      end

      def metadata_string(key)
        meta = metadata
        (meta[key] || meta[key.to_s]).to_s.strip.presence
      end

      def same_origin_path?(value)
        value.start_with?("/") && !value.start_with?("//")
      end

      def safe_url(value)
        if defined?(RecordingStudioNotifications::UrlSafety)
          return value if RecordingStudioNotifications::UrlSafety.safe?(value)
        elsif fallback_url_safe?(value)
          return value
        end

        nil
      end

      def fallback_url_safe?(value)
        return !value.start_with?("//") if value.start_with?("/")

        uri = URI.parse(value)
        [URI::HTTP, URI::HTTPS].any? { |type| uri.is_a?(type) } && uri.host.present?
      end

      def unsafe_url_characters?(value)
        value.match?(/[\\\x00-\x1F\x7F]/)
      end
    end
  end
end
