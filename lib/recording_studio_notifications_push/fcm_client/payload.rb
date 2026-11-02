# frozen_string_literal: true

module RecordingStudioNotificationsPush
  class FcmClient
    # Data-only web payloads. When a service worker handles `push`, Chrome does
    # not auto-display an FCM `notification` block — the worker must call
    # showNotification. Including both blocks duplicated banners before dedupe.
    module Payload
      module_function

      def body(token, message)
        {
          message: {
            token: token.to_s,
            data: stringify(fields(message)),
            webpush: webpush(message[:link])
          }.compact
        }
      end

      def fields(message)
        (message[:data] || {}).merge(
          "title" => message[:title],
          "body" => message[:body],
          "url" => message[:url]
        ).compact
      end

      def stringify(hash)
        hash.each_with_object({}) do |(key, value), result|
          next if value.nil?

          result[key.to_s] = value.is_a?(String) ? value : value.to_s
        end
      end

      def webpush(link)
        options = {
          # Urgency helps some browsers deliver while a tab is focused.
          headers: { Urgency: "high" }
        }
        options[:fcm_options] = { link: link.to_s } if Http.absolute_https?(link)
        options
      end
    end
  end
end
