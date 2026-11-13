# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_notifications_push.gemspec
gemspec

# Parent gems are not published to RubyGems; resolve from GitHub.
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.7.0"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.8.0"
gem "recording_studio_notifications",
    github: "bowerbird-app/RecordingStudio_notifications",
    tag: "v0.15.0"

email_path = ENV.fetch("RECORDING_STUDIO_NOTIFICATIONS_EMAIL_PATH", nil)
if email_path && !email_path.strip.empty?
  gem "recording_studio_notifications_email", path: email_path
else
  gem "recording_studio_notifications_email",
      github: "bowerbird-app/RecordingStudio_notifications_email",
      tag: "v0.5.2"
end

gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.357"
gem "recording_studio_accessible",
    github: "bowerbird-app/RecordingStudio_accessible",
    tag: "v0.32.0"
gem "recording_studio_pwa", ">= 0.8.0", "< 1.0",
    github: "bowerbird-app/RecordingStudio_PWA",
    tag: "v0.8.2"
# Accessible needs trashable query helpers only (not the full engine).
gem "recording_studio_trashable",
    github: "bowerbird-app/RecordingStudio_trashable",
    tag: "v0.14.0",
    require: false

gem "view_component", "4.20.0"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
