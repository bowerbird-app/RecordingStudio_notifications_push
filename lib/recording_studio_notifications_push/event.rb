# frozen_string_literal: true

require_relative "event/payload"
require_relative "event/url"

module RecordingStudioNotificationsPush
  # Read-only, normalized view of a parent notification for FCM payloads.
  class Event
    include Payload
    include Url

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
      value = resolved_delivery_payload&.title
      value = attribute(:title) if value.blank?
      return sanitize_header_text(value) if value.present?

      Copy.t("payloads.fallback_title")
    end

    def body
      value = resolved_delivery_payload&.body
      value = attribute(:body) if value.blank?
      value.to_s.presence
    end

    def url
      value = resolved_delivery_payload&.url
      value = attribute(:url) if value.blank?
      value = value.to_s.presence
      return unless value

      safe_url(value)
    rescue URI::InvalidURIError
      nil
    end

    def metadata
      @metadata ||= begin
        value = attribute(:metadata)
        value.respond_to?(:to_h) ? deep_freeze(value.to_h.deep_dup) : {}.freeze
      end
    end

    def icon
      meta_asset(:icon)
    end

    def image
      meta_asset(:image) || icon
    end

    def recipient
      attribute(:recipient)
    end
  end
end
