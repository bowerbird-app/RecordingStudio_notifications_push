# frozen_string_literal: true

module RecordingStudioNotificationsPush
  # Read-only, normalized view of a parent notification for FCM payloads.
  class Event
    attr_reader :source, :delivery

    def self.wrap(source, delivery: nil)
      return source if source.is_a?(self) && delivery.nil?

      new(source, delivery: delivery)
    end

    def initialize(source, delivery: nil)
      raise ArgumentError, "notification is required" if source.nil?

      @source = source
      @delivery = delivery
    end

    def id
      attribute(:id)
    end

    def title
      value = attribute(:title)
      return sanitize_header_text(value) if value.present?

      "Notification"
    end

    def body
      attribute(:body).to_s.presence
    end

    def url
      value = attribute(:url).to_s.presence
      return unless value
      return if unsafe_url_characters?(value)

      safe_url(value)
    rescue URI::InvalidURIError
      nil
    end

    def metadata
      value = attribute(:metadata)
      value.respond_to?(:to_h) ? deep_freeze(value.to_h.deep_dup) : {}.freeze
    end

    def recipient
      attribute(:recipient)
    end

    private

    def safe_url(value)
      if defined?(RecordingStudioNotifications::UrlSafety)
        return value if RecordingStudioNotifications::UrlSafety.safe?(value)
      elsif fallback_url_safe?(value)
        return value
      end

      nil
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

    def fallback_url_safe?(value)
      return !value.start_with?("//") if value.start_with?("/")

      uri = URI.parse(value)
      [URI::HTTP, URI::HTTPS].any? { |type| uri.is_a?(type) } && uri.host.present?
    end

    def unsafe_url_characters?(value)
      value.match?(/[\\\x00-\x1F\x7F]/)
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
