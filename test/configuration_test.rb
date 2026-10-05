# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  FIREBASE_ENV_KEYS = %w[
    FIREBASE_API_KEY
    FIREBASE_APP_ID
    FIREBASE_AUTH_DOMAIN
    FIREBASE_MESSAGING_SENDER_ID
    FIREBASE_PROJECT_ID
    FIREBASE_STORAGE_BUCKET
    FIREBASE_VAPID_PUBLIC_KEY
    FIREBASE_SERVICE_ACCOUNT_JSON
  ].freeze

  def setup
    @original_env = FIREBASE_ENV_KEYS.index_with { |key| ENV.fetch(key, nil) }
    FIREBASE_ENV_KEYS.each { |key| ENV.delete(key) }
  end

  def teardown
    @original_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def test_defaults_include_push_channel
    configuration = RecordingStudioNotificationsPush::Configuration.new

    assert_equal :push, configuration.channel
    assert_equal 5, configuration.open_timeout
    assert_equal 15, configuration.read_timeout
  end

  def test_loads_firebase_web_config_from_env
    ENV["FIREBASE_API_KEY"] = "api-key"
    ENV["FIREBASE_APP_ID"] = "app-id"
    ENV["FIREBASE_AUTH_DOMAIN"] = "example.firebaseapp.com"
    ENV["FIREBASE_MESSAGING_SENDER_ID"] = "123"
    ENV["FIREBASE_PROJECT_ID"] = "demo-project"
    ENV["FIREBASE_STORAGE_BUCKET"] = "demo-project.appspot.com"
    ENV["FIREBASE_VAPID_PUBLIC_KEY"] = "vapid-public"
    ENV["FIREBASE_SERVICE_ACCOUNT_JSON"] = '{"type":"service_account"}'

    configuration = RecordingStudioNotificationsPush::Configuration.new

    assert_equal "demo-project", configuration.firebase_project_id
    assert_equal "vapid-public", configuration.vapid_public_key
    assert_equal "api-key", configuration.firebase_web_config[:apiKey]
    assert_equal "app-id", configuration.firebase_web_config[:appId]
    assert_equal "123", configuration.firebase_web_config[:messagingSenderId]
    assert_equal "example.firebaseapp.com", configuration.firebase_web_config[:authDomain]
    assert_equal "demo-project.appspot.com", configuration.firebase_web_config[:storageBucket]
    assert configuration.service_account_configured?
  end

  def test_credentials_win_over_env
    ENV["FIREBASE_API_KEY"] = "env-api-key"
    ENV["FIREBASE_APP_ID"] = "env-app-id"
    ENV["FIREBASE_AUTH_DOMAIN"] = "env.firebaseapp.com"
    ENV["FIREBASE_MESSAGING_SENDER_ID"] = "env-sender"
    ENV["FIREBASE_PROJECT_ID"] = "env-project"
    ENV["FIREBASE_STORAGE_BUCKET"] = "env.appspot.com"
    ENV["FIREBASE_VAPID_PUBLIC_KEY"] = "env-vapid"
    ENV["FIREBASE_SERVICE_ACCOUNT_JSON"] = '{"type":"env"}'

    configuration = RecordingStudioNotificationsPush::Configuration.new
    with_firebase_credentials(
      api_key: "cred-api-key",
      app_id: "cred-app-id",
      auth_domain: "cred.firebaseapp.com",
      messaging_sender_id: "cred-sender",
      project_id: "cred-project",
      storage_bucket: "cred.appspot.com",
      vapid_public_key: "cred-vapid",
      service_account_json: '{"type":"credentials"}'
    ) do
      assert_equal "cred-project", configuration.firebase_project_id
      assert_equal "cred-vapid", configuration.vapid_public_key
      assert_equal "cred-api-key", configuration.firebase_web_config[:apiKey]
      assert_equal "cred-app-id", configuration.firebase_web_config[:appId]
      assert_equal "cred.firebaseapp.com", configuration.firebase_web_config[:authDomain]
      assert_equal "cred-sender", configuration.firebase_web_config[:messagingSenderId]
      assert_equal "cred.appspot.com", configuration.firebase_web_config[:storageBucket]
      assert_equal '{"type":"credentials"}', configuration.firebase_service_account_json
    end
  end

  def test_falls_back_to_env_when_credentials_are_blank
    ENV["FIREBASE_PROJECT_ID"] = "env-project"
    ENV["FIREBASE_VAPID_PUBLIC_KEY"] = "env-vapid"
    ENV["FIREBASE_API_KEY"] = "env-api-key"

    configuration = RecordingStudioNotificationsPush::Configuration.new
    with_firebase_credentials({}) do
      assert_equal "env-project", configuration.firebase_project_id
      assert_equal "env-vapid", configuration.vapid_public_key
      assert_equal "env-api-key", configuration.firebase_web_config[:apiKey]
    end
  end

  def test_resolves_firebase_values_lazily
    configuration = RecordingStudioNotificationsPush::Configuration.new

    refute configuration.instance_variable_defined?(:@firebase_project_id)
    refute configuration.instance_variable_defined?(:@vapid_public_key)
    refute configuration.instance_variable_defined?(:@firebase_service_account_json)
    refute configuration.instance_variable_defined?(:@firebase_web_config)

    ENV["FIREBASE_PROJECT_ID"] = "after-init"
    ENV["FIREBASE_VAPID_PUBLIC_KEY"] = "after-vapid"
    ENV["FIREBASE_API_KEY"] = "after-api-key"

    assert_equal "after-init", configuration.firebase_project_id
    assert_equal "after-vapid", configuration.vapid_public_key
    assert_equal "after-api-key", configuration.firebase_web_config[:apiKey]
  end

  def test_explicit_configure_override_wins_over_credentials_and_env
    ENV["FIREBASE_PROJECT_ID"] = "env-project"
    ENV["FIREBASE_VAPID_PUBLIC_KEY"] = "env-vapid"
    ENV["FIREBASE_SERVICE_ACCOUNT_JSON"] = '{"type":"env"}'

    configuration = RecordingStudioNotificationsPush::Configuration.new
    configuration.firebase_project_id = "override-project"
    configuration.vapid_public_key = "override-vapid"
    configuration.firebase_service_account_json = '{"type":"override"}'
    configuration.firebase_web_config = { apiKey: "override-api-key" }

    with_firebase_credentials(
      project_id: "cred-project",
      vapid_public_key: "cred-vapid",
      service_account_json: '{"type":"credentials"}',
      api_key: "cred-api-key"
    ) do
      assert_equal "override-project", configuration.firebase_project_id
      assert_equal "override-vapid", configuration.vapid_public_key
      assert_equal '{"type":"override"}', configuration.firebase_service_account_json
      assert_equal({ apiKey: "override-api-key" }, configuration.firebase_web_config)
    end
  end

  def test_service_account_from_credentials_hash
    configuration = RecordingStudioNotificationsPush::Configuration.new
    account = {
      type: "service_account",
      client_email: "firebase-adminsdk@demo.iam.gserviceaccount.com",
      private_key: "-----BEGIN PRIVATE KEY-----\nDEMO\n-----END PRIVATE KEY-----\n"
    }

    with_firebase_credentials(service_account_json: account) do
      assert_equal account, configuration.firebase_service_account_json
      assert configuration.service_account_configured?
    end
  end

  def test_service_account_from_credentials_string
    configuration = RecordingStudioNotificationsPush::Configuration.new
    json = '{"type":"service_account","client_email":"firebase-adminsdk@demo.iam.gserviceaccount.com"}'

    with_firebase_credentials(service_account_json: json) do
      assert_equal json, configuration.firebase_service_account_json
      assert configuration.service_account_configured?
    end
  end

  def test_merge_updates_known_keys
    configuration = RecordingStudioNotificationsPush::Configuration.new
    configuration.merge!("firebase_project_id" => "merged-project", unknown: true)

    assert_equal "merged-project", configuration.firebase_project_id
    refute_respond_to configuration, :unknown
  end

  def test_to_h_hides_service_account_secret
    configuration = RecordingStudioNotificationsPush::Configuration.new
    configuration.firebase_service_account_json = '{"private_key":"SECRET"}'
    hash = configuration.to_h

    assert_equal true, hash[:firebase_service_account_configured]
    refute_includes hash.values.map(&:to_s).join, "SECRET"
  end

  def test_web_push_client_ready_when_required_firebase_values_present
    configuration = RecordingStudioNotificationsPush::Configuration.new
    configuration.firebase_web_config = {
      apiKey: "key",
      appId: "app",
      projectId: "project",
      messagingSenderId: "123"
    }
    configuration.vapid_public_key = "vapid"

    assert configuration.web_push_client_ready?
  end

  def test_web_push_client_ready_false_when_vapid_missing
    configuration = RecordingStudioNotificationsPush::Configuration.new
    configuration.firebase_web_config = {
      apiKey: "key",
      appId: "app",
      projectId: "project",
      messagingSenderId: "123"
    }
    configuration.vapid_public_key = nil

    refute configuration.web_push_client_ready?
  end

  def test_web_push_client_ready_accepts_string_keys
    configuration = RecordingStudioNotificationsPush::Configuration.new
    configuration.firebase_web_config = {
      "apiKey" => "key",
      "appId" => "app",
      "projectId" => "project",
      "messagingSenderId" => "123"
    }
    configuration.vapid_public_key = "vapid"

    assert configuration.web_push_client_ready?
  end

  private

  def with_firebase_credentials(values, &)
    credentials = Object.new
    credentials.define_singleton_method(:dig) do |namespace, key|
      namespace == :firebase ? values[key] : nil
    end

    application = Object.new
    application.define_singleton_method(:credentials) { credentials }

    Rails.stub(:application, application, &)
  end
end
