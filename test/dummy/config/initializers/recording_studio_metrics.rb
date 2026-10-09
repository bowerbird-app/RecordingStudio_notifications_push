# frozen_string_literal: true

# Host-owned. This gem registers metric definitions; it does not expose endpoints.
RecordingStudioMetrics::Api.register!(api: :operations)
