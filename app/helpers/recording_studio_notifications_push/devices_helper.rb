# frozen_string_literal: true

module RecordingStudioNotificationsPush
  module DevicesHelper
    def push_t(key, **)
      Copy.t(key, **)
    end

    def push_copy(override, key, **)
      Copy.value(override, key, **)
    end

    def push_js_copy
      Copy.js_payload
    end
  end
end
