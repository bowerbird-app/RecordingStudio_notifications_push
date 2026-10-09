# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_notifications_push.gemspec
gemspec

# Parent gems are not published to RubyGems; resolve from GitHub.
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.4.0"
gem "recording_studio_notifications",
    github: "bowerbird-app/RecordingStudio_notifications",
    tag: "v0.5.0"

email_path = ENV.fetch("RECORDING_STUDIO_NOTIFICATIONS_EMAIL_PATH", nil)
if email_path && !email_path.strip.empty?
  gem "recording_studio_notifications_email", path: email_path
else
  gem "recording_studio_notifications_email",
      github: "bowerbird-app/RecordingStudio_notifications_email",
      tag: "v0.3.4"
end

gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.198"
gem "recording_studio_accessible",
    github: "bowerbird-app/RecordingStudio_accessible",
    tag: "v0.13.0"
# Branch pin: tag v0.2.3 does not contain the service-worker seam commit.
gem "recording_studio_pwa",
    github: "bowerbird-app/RecordingStudio_PWA",
    branch: "cursor/pwa-service-worker-seam-453c"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
