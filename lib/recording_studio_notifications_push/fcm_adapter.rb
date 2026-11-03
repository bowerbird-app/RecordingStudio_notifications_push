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
      deliver_each(installations_for(event), build_send_payload(event, delivery))
    end

    def available_for?(recipient:, **)
      return false if recipient.nil?

      installation_class.active.for_recipient(recipient).exists?
    end

    private

    def installations_for(event)
      recipient = event.recipient
      raise DeliveryError, "notification recipient is required" if recipient.nil?

      installations = installation_class.active.for_recipient(recipient).to_a
      raise DeliveryError, "no active push installations for recipient" if installations.empty?

      installations
    end

    def deliver_each(installations, payload)
      outcomes = installations.map { |installation| deliver_to_installation(installation, payload) }
      return true if outcomes.any? { |outcome| outcome[:ok] }

      last_error = outcomes.reverse.find { |outcome| outcome[:error] }&.dig(:error)
      raise DeliveryError, last_error.presence || "push delivery failed for all installations"
    end

    def build_send_payload(event, delivery)
      {
        title: event.title,
        body: event.body,
        url: event.url,
        link: open_link(event),
        data: message_data(event, delivery)
      }
    end

    def open_link(event)
      return if Rails.application.nil?
      return if default_url_host.blank?

      url = RecordingStudioNotifications.notification_url(event.source)
      url if Http.absolute_https?(url)
    end

    def default_url_host
      routes = Rails.application.routes.default_url_options || {}
      mailer = Rails.application.config.action_mailer.default_url_options || {}
      routes.merge(mailer.compact_blank).symbolize_keys[:host]
    end

    def deliver_to_installation(installation, payload)
      token = installation.delivery_token
      if token.blank?
        installation.disable!(reason: "missing_token")
        return { ok: false, error: "missing_token" }
      end

      result = client.send_message(token: token, **payload)

      apply_send_result(installation, result)
    rescue DeliveryError => e
      { ok: false, error: e.message }
    end

    def message_data(event, delivery)
      {
        "notification_id" => event.id,
        "delivery_id" => delivery.respond_to?(:id) ? delivery.id : nil,
        "icon" => event.icon,
        "image" => event.image
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
