# frozen_string_literal: true

module RecordingStudioNotificationsPush
  class Event
    module Url
      private

      def meta_asset(key)
        value = metadata_string(key)
        return unless value
        return value if RecordingStudioNotifications::UrlSafety.safe?(value)

        nil
      end

      def metadata_string(key)
        meta = metadata
        (meta[key] || meta[key.to_s]).to_s.strip.presence
      end

      def safe_url(value)
        return value if RecordingStudioNotifications::UrlSafety.safe?(value)

        nil
      end
    end
  end
end
