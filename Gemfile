# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_notifications_push.gemspec
gemspec

# Parent gems are not published to RubyGems; resolve from GitHub.
gem "recording_studio", "~> 7.8", github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"
gem "recording_studio_metrics", "~> 0.10", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.10.0"
gem "recording_studio_notifications", "~> 0.21",
    github: "bowerbird-app/RecordingStudio_notifications",
    tag: "v0.21.0"

email_path = ENV.fetch("RECORDING_STUDIO_NOTIFICATIONS_EMAIL_PATH", nil)
if email_path && !email_path.strip.empty?
  gem "recording_studio_notifications_email", path: email_path
else
  gem "recording_studio_notifications_email",
      github: "bowerbird-app/RecordingStudio_notifications_email",
      tag: "v0.5.3"
end

gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"
gem "recording_studio_accessible", "~> 0.58",
    github: "bowerbird-app/RecordingStudio_accessible",
    tag: "v0.58.0"
gem "recording_studio_admin", "~> 2.20",
    github: "bowerbird-app/RecordingStudio_admin",
    tag: "v2.20.0",
    require: false
gem "recording_studio_logs", "~> 0.9",
    github: "bowerbird-app/RecordingStudio_logs",
    tag: "v0.9.0",
    require: false
gem "recording_studio_pwa", "~> 0.10",
    github: "bowerbird-app/RecordingStudio_PWA",
    tag: "v0.10.0"
# Accessible needs trashable query helpers only (not the full engine).
gem "recording_studio_trashable", "~> 1.3",
    github: "bowerbird-app/RecordingStudio_trashable",
    tag: "v1.3.0",
    require: false
# Notifications 0.21 needs API. API needs Moveable, and Moveable needs Icons.
# require: false keeps those engines off this bundle, matching the dummy.
gem "recording_studio_api", "~> 1.21",
    github: "bowerbird-app/RecordingStudio_api",
    tag: "v1.21.2",
    require: false
gem "recording_studio_moveable", "~> 6.1",
    github: "bowerbird-app/RecordingStudio_moveable",
    tag: "v6.1.0",
    require: false
gem "recording_studio_icons", "~> 0.5",
    github: "bowerbird-app/RecordingStudio_icons",
    tag: "v0.5.0",
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
