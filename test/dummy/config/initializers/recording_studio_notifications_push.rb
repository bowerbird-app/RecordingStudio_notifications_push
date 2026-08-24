# frozen_string_literal: true

RecordingStudioNotificationsPush.configure do |config|
  # Defaults come from FIREBASE_* ENVs. Override here when needed.
  config.channel = :push
end
