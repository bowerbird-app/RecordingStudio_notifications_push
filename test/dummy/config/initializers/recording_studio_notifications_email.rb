# frozen_string_literal: true

RecordingStudioNotificationsEmail.configure do |config|
  config.from = ENV.fetch("RECORDING_STUDIO_NOTIFICATIONS_EMAIL_FROM", "notifications@example.test")
end
