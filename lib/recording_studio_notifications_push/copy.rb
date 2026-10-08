# frozen_string_literal: true

require "i18n"

module RecordingStudioNotificationsPush
  # Customer-facing chrome for the push devices screen and default payloads.
  # Keys live under `recording_studio.notifications_push.*`. Hosts override any
  # key in their own locale files. Explicit arguments still win, including nil.
  module Copy
    PREFIX = "recording_studio.notifications_push"
    UNSET = Object.new.freeze

    module_function

    def t(key, **)
      I18n.t("#{PREFIX}.#{key}", **)
    end

    def provided?(value)
      !value.equal?(UNSET)
    end

    def value(override, key, **)
      provided?(override) ? override : t(key, **)
    end

    def js_payload
      flatten_hash(I18n.t("#{PREFIX}.js"))
    end

    def flatten_hash(value, prefix = nil)
      return { prefix => value } unless value.is_a?(Hash)

      value.each_with_object({}) do |(key, nested), payload|
        path = prefix ? "#{prefix}.#{key}" : key.to_s
        payload.merge!(flatten_hash(nested, path))
      end
    end
  end
end
