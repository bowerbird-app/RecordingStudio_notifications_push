# frozen_string_literal: true

module RecordingStudioNotificationsPush
  class Configuration
    WEB_CLIENT_REQUIRED_KEYS = %i[apiKey appId projectId messagingSenderId].freeze

    WEB_CONFIG_KEYS = {
      apiKey: { credential: :api_key, env: "FIREBASE_API_KEY" },
      appId: { credential: :app_id, env: "FIREBASE_APP_ID" },
      authDomain: { credential: :auth_domain, env: "FIREBASE_AUTH_DOMAIN" },
      messagingSenderId: { credential: :messaging_sender_id, env: "FIREBASE_MESSAGING_SENDER_ID" },
      projectId: { credential: :project_id, env: "FIREBASE_PROJECT_ID" },
      storageBucket: { credential: :storage_bucket, env: "FIREBASE_STORAGE_BUCKET" }
    }.freeze

    attr_accessor :channel, :open_timeout, :read_timeout, :write_timeout
    attr_writer :firebase_project_id, :firebase_web_config, :vapid_public_key,
                :firebase_service_account_json

    def initialize
      @channel = :push
      @open_timeout = 5
      @read_timeout = 15
      @write_timeout = 15
    end

    def merge!(attributes)
      return self unless attributes.respond_to?(:each)

      attributes.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
      self
    end

    def to_h
      {
        channel: channel.to_sym,
        firebase_project_id: firebase_project_id,
        firebase_web_config: firebase_web_config.to_h,
        vapid_public_key: vapid_public_key,
        firebase_service_account_configured: service_account_configured?,
        open_timeout: open_timeout,
        read_timeout: read_timeout,
        write_timeout: write_timeout
      }
    end

    def firebase_project_id
      return @firebase_project_id if instance_variable_defined?(:@firebase_project_id)

      credential_or_env(:project_id, "FIREBASE_PROJECT_ID")
    end

    def vapid_public_key
      return @vapid_public_key if instance_variable_defined?(:@vapid_public_key)

      credential_or_env(:vapid_public_key, "FIREBASE_VAPID_PUBLIC_KEY")
    end

    def firebase_service_account_json
      return @firebase_service_account_json if instance_variable_defined?(:@firebase_service_account_json)

      credential_or_env(:service_account_json, "FIREBASE_SERVICE_ACCOUNT_JSON")
    end

    def firebase_web_config
      return @firebase_web_config if instance_variable_defined?(:@firebase_web_config)

      default_firebase_web_config
    end

    def service_account_configured?
      value = firebase_service_account_json
      return value.present? if value.is_a?(Hash)

      value.to_s.strip.present?
    end

    def web_push_client_ready?
      config = firebase_web_config || {}
      WEB_CLIENT_REQUIRED_KEYS.all? { |key| web_config_value_present?(config, key) } &&
        vapid_public_key.present?
    end

    private

    def web_config_value_present?(config, key)
      config[key].present? || config[key.to_s].present?
    end

    def default_firebase_web_config
      WEB_CONFIG_KEYS.each_with_object({}) do |(key, sources), config|
        value = credential_or_env(sources[:credential], sources[:env])
        config[key] = value if value.present?
      end
    end

    def credential_or_env(credential_key, env_name)
      credential = firebase_credential(credential_key)
      return credential if credential.present?

      ENV.fetch(env_name, nil)
    end

    def firebase_credential(key)
      application = defined?(Rails) ? Rails.application : nil
      return unless application.respond_to?(:credentials)

      credentials = application.credentials
      return unless credentials.respond_to?(:dig)

      credentials.dig(:firebase, key)
    rescue ActiveSupport::EncryptedFile::MissingKeyError
      nil
    end
  end
end
