# frozen_string_literal: true

RecordingStudioNotificationsPush.configure do |config|
  # Channel key registered with RecordingStudioNotifications (default :push).
  # config.channel = :push

  # Browser registration uses the web keys. service_account_json is required
  # only to send. Delivery raises DeliveryError when it is missing at send time.
  config.firebase_project_id =
    Rails.application.credentials.dig(:firebase, :project_id) || ENV.fetch("FIREBASE_PROJECT_ID", nil)
  config.vapid_public_key =
    Rails.application.credentials.dig(:firebase, :vapid_public_key) || ENV.fetch("FIREBASE_VAPID_PUBLIC_KEY", nil)
  config.firebase_service_account_json =
    Rails.application.credentials.dig(:firebase, :service_account_json) ||
    ENV.fetch("FIREBASE_SERVICE_ACCOUNT_JSON", nil)
  config.firebase_web_config = {
    apiKey: Rails.application.credentials.dig(:firebase, :api_key) || ENV.fetch("FIREBASE_API_KEY", nil),
    appId: Rails.application.credentials.dig(:firebase, :app_id) || ENV.fetch("FIREBASE_APP_ID", nil),
    authDomain: Rails.application.credentials.dig(:firebase, :auth_domain) || ENV.fetch("FIREBASE_AUTH_DOMAIN", nil),
    messagingSenderId: Rails.application.credentials.dig(:firebase, :messaging_sender_id) ||
                       ENV.fetch("FIREBASE_MESSAGING_SENDER_ID", nil),
    projectId: Rails.application.credentials.dig(:firebase, :project_id) || ENV.fetch("FIREBASE_PROJECT_ID", nil),
    storageBucket: Rails.application.credentials.dig(:firebase, :storage_bucket) ||
                   ENV.fetch("FIREBASE_STORAGE_BUCKET", nil)
  }
end
