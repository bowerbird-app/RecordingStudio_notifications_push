# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.engine_layout = "recording_studio/default_layout"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user

  config.access_recording_resolver = ->(_context) { nil }
  config.site_admin_recording_resolver = ->(_context) { nil }
end
