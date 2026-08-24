# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_notifications_push.gemspec
gemspec

# Parent gems are not published to RubyGems; resolve from GitHub.
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_notifications",
    github: "bowerbird-app/RecordingStudio_notifications",
    branch: "main"

# Upstream main still gemspecs recording_studio < 4, which conflicts with this
# stack (recording_studio ~> 4.2 + recording_studio_pwa). Prefer github main once
# that pin is bumped. Until then, set RECORDING_STUDIO_NOTIFICATIONS_EMAIL_PATH
# to a patched checkout (see MIGRATION_NOTES.md).
email_path = ENV["RECORDING_STUDIO_NOTIFICATIONS_EMAIL_PATH"]
if email_path && Dir.exist?(email_path)
  gem "recording_studio_notifications_email", path: email_path
else
  gem "recording_studio_notifications_email",
      github: "bowerbird-app/RecordingStudio_notifications_email",
      branch: "main"
end

gem "recording_studio_pwa",
    github: "bowerbird-app/RecordingStudio_PWA",
    branch: "cursor/pwa-service-worker-seam-453c"
gem "recording_studio_accessible",
    github: "bowerbird-app/RecordingStudio_accessible",
    tag: "v0.7.0"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.133"

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
