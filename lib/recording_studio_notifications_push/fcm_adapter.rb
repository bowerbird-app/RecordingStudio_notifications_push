# frozen_string_literal: true

module RecordingStudioNotificationsPush
  # Channel adapter for RecordingStudioNotifications. Fans out one notification
  # to every active push installation for the recipient. Success requires at
  # least one successful FCM send. Missing service-account credentials raise
  # DeliveryError at send time. This channel does not implement deliver_rollup.
  class FcmAdapter
    def initialize(configuration: RecordingStudioNotificationsPush.configuration, client: nil,
                   installation_class: nil)
      @configuration = configuration
      @client = client
      @installation_class = installation_class
    end

    def deliver(notification:, delivery:)
      event = Event.wrap(notification, delivery: delivery)
      recipient = event.recipient
      raise DeliveryError, "notification recipient is required" if recipient.nil?

      installations = installation_class.active.for_recipient(recipient).to_a
      if installations.empty?
        raise DeliveryError, "no active push installations for recipient"
      end

      successes = 0
      last_error = nil

      installations.each do |installation|
        token = installation.delivery_token
        if token.blank?
          installation.disable!(reason: "missing_token")
          next
        end

        result = client.send_message(
          token: token,
          title: event.title,
          body: event.body,
          url: event.url,
          data: {
            "notification_id" => event.id,
            "delivery_id" => delivery.respond_to?(:id) ? delivery.id : nil
          }.compact
        )

        if result[:ok]
          successes += 1
          installation.touch_seen!
        else
          last_error = result[:error_message].presence || "FCM send failed (HTTP #{result[:status]})"
          installation.disable!(reason: last_error) if result[:disable]
        end
      rescue DeliveryError => error
        last_error = error.message
      end

      return true if successes.positive?

      raise DeliveryError, last_error.presence || "push delivery failed for all installations"
    end

    private

    def client
      @client ||= FcmClient.new(configuration: @configuration)
    end

    def installation_class
      @installation_class || Installation
    end
  end

  module Adapters
    FcmAdapter = RecordingStudioNotificationsPush::FcmAdapter
  end

  module Channels
    FcmAdapter = RecordingStudioNotificationsPush::FcmAdapter
  end
end
