# frozen_string_literal: true

RecordingStudioNotifications.configure do |config|
  # Keep demo delivery on the request thread.
  config.deliver_later = false
end

Rails.application.config.to_prepare do
  RecordingStudioNotifications.register_notification_type(
    :push_demo,
    label: "Push demo",
    category: :general,
    default_channels: %i[in_app email push],
    available_channels: %i[in_app email push]
  )
rescue ArgumentError
  # Type may already be registered during reload.
end
