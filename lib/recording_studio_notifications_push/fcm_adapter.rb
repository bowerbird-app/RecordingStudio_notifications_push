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

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def deliver(notification:, delivery:)
      event = Event.wrap(notification, delivery: delivery)
      recipient = event.recipient
      raise DeliveryError, "notification recipient is required" if recipient.nil?

      installations = installation_class.active.for_recipient(recipient).to_a
      raise DeliveryError, "no active push installations for recipient" if installations.empty?

      successes = 0
      last_error = nil

      installations.each do |installation|
        outcome = deliver_to_installation(installation, event, delivery)
        if outcome[:ok]
          successes += 1
        else
          last_error = outcome[:error]
        end
      end

      return true if successes.positive?

      raise DeliveryError, last_error.presence || "push delivery failed for all installations"
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    private

    # rubocop:disable Metrics/MethodLength
    def deliver_to_installation(installation, event, delivery)
      token = installation.delivery_token
      if token.blank?
        installation.disable!(reason: "missing_token")
        return { ok: false, error: "missing_token" }
      end

      result = client.send_message(
        token: token,
        title: event.title,
        body: event.body,
        url: event.url,
        data: message_data(event, delivery)
      )

      apply_send_result(installation, result)
    rescue DeliveryError => e
      { ok: false, error: e.message }
    end
    # rubocop:enable Metrics/MethodLength

    def message_data(event, delivery)
      {
        "notification_id" => event.id,
        "delivery_id" => delivery.respond_to?(:id) ? delivery.id : nil
      }.compact
    end

    def apply_send_result(installation, result)
      if result[:ok]
        installation.touch_seen!
        { ok: true }
      else
        error = result[:error_message].presence || "FCM send failed (HTTP #{result[:status]})"
        installation.disable!(reason: error) if result[:disable]
        { ok: false, error: error }
      end
    end

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
