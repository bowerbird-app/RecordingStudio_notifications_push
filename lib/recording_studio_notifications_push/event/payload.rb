# frozen_string_literal: true

module RecordingStudioNotificationsPush
  class Event
    module Payload
      private

      def resolved_delivery_payload
        return @resolved_delivery_payload if defined?(@resolved_delivery_payload)
        return @resolved_delivery_payload = nil unless delivery
        return @resolved_delivery_payload = nil unless defined?(RecordingStudioNotifications)

        @resolved_delivery_payload = RecordingStudioNotifications.delivery_payload_for(
          notification: source,
          delivery: delivery
        )
      end

      def attribute(name)
        return source.public_send(name) if source.respond_to?(name)

        hash_attribute(name)
      end

      def hash_attribute(name)
        return source[name] if source.respond_to?(:key?) && source.key?(name)

        string_name = name.to_s
        source[string_name] if source.respond_to?(:key?) && source.key?(string_name)
      end

      def sanitize_header_text(value)
        value.to_s.gsub(/[\r\n]+/, " ").strip
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each do |key, nested|
            deep_freeze(key)
            deep_freeze(nested)
          end
        when Array
          value.each { |nested| deep_freeze(nested) }
        end
        value.freeze
      end
    end
  end
end
