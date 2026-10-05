# frozen_string_literal: true

RecordingStudioNotificationsPush.configure do |config|
  # Defaults are Rails credentials under firebase:, then FIREBASE_* ENV.
  # Dummy keeps master.key gitignored and does not assign secrets here.
  config.channel = :push
end
