# frozen_string_literal: true

require "recording_studio"
require "recording_studio_notifications_push/version"
require "recording_studio_notifications_push/engine"
require "recording_studio_notifications_push/configuration"
require "recording_studio_notifications_push/capabilities/example"

module RecordingStudioNotificationsPush
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end
  end
end
