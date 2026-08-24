# frozen_string_literal: true

RecordingStudioPwa.configure do |config|
  config.name = "Push notifications demo"
  config.short_name = "Push demo"
  config.description = "Dummy host for Recording Studio push notifications"
  config.public_page_paths = ["/users/sign_in"]
end
