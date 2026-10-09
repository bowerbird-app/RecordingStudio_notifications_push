# frozen_string_literal: true

require_relative "api/access"
require "recording_studio_metrics"

module RecordingStudioNotificationsPush
  module Metrics
    RESOURCE = :push_devices
    API = :operations
    EXPOSE = { api: [API] }.freeze
    AUTHORIZE = ->(context) { RecordingStudioNotificationsPush::Api::Access.can_view?(context) }
    ACTIVE = ->(relation) { relation.merge(RecordingStudioNotificationsPush::Installation.active) }

    module_function

    def register!
      RecordingStudioMetrics.register(
        RESOURCE,
        model: RecordingStudioNotificationsPush::Installation,
        blast_radius: :site,
        api_authorize: AUTHORIZE
      ) { RecordingStudioNotificationsPush::Metrics.define_devices(self) }
    end

    def define_devices(dsl)
      dsl.breakdown :by_platform, title: "Push devices by platform", field: :platform, expose: EXPOSE
      dsl.count :active, title: "Active push devices", expose: EXPOSE, scope: ACTIVE
      dsl.timeseries :new_over_time, title: "New push devices", field: :created_at, expose: EXPOSE
    end
  end
end
