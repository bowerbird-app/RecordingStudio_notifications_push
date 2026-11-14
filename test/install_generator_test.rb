# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_notifications_push/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  def with_temp_app
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config/initializers"))
      yield dir
    end
  end

  def build_generator(destination_root)
    RecordingStudioNotificationsPush::Generators::InstallGenerator.new(
      [],
      {},
      destination_root: destination_root
    )
  end

  def test_copy_initializer_writes_env_documented_file
    with_temp_app do |dir|
      generator = build_generator(dir)
      generator.copy_initializer

      path = File.join(dir, "config/initializers/recording_studio_notifications_push.rb")
      assert File.exist?(path)
      source = File.read(path)
      assert_includes source, "RecordingStudioNotificationsPush.configure"
      assert_includes source, "credentials.dig(:firebase, :project_id)"
      assert_includes source, 'ENV.fetch("FIREBASE_PROJECT_ID", nil)'
      assert_includes source, "credentials.dig(:firebase, :vapid_public_key)"
      assert_includes source, 'ENV.fetch("FIREBASE_VAPID_PUBLIC_KEY", nil)'
      assert_includes source, "credentials.dig(:firebase, :service_account_json)"
      assert_includes source, 'ENV.fetch("FIREBASE_SERVICE_ACCOUNT_JSON", nil)'
      assert_includes source, "credentials.dig(:firebase, :api_key)"
      assert_includes source, 'ENV.fetch("FIREBASE_API_KEY", nil)'
    end
  end

  def test_generated_initializer_prefers_firebase_credentials
    with_generated_template do |template|
      with_firebase_env(ENV_FIREBASE) do
        with_credentials(CREDENTIAL_FIREBASE) do
          RecordingStudioNotificationsPush.reset_configuration!
          load template
        end
      end

      config = RecordingStudioNotificationsPush.configuration
      assert_equal "cred-project", config.firebase_project_id
      assert_equal "cred-vapid", config.vapid_public_key
      assert_equal '{"type":"credentials"}', config.firebase_service_account_json
      assert_equal "cred-api-key", config.firebase_web_config.fetch(:apiKey)
      assert_equal "cred-app", config.firebase_web_config.fetch(:appId)
      assert_equal "cred.firebaseapp.com", config.firebase_web_config.fetch(:authDomain)
      assert_equal "cred-sender", config.firebase_web_config.fetch(:messagingSenderId)
      assert_equal "cred-project", config.firebase_web_config.fetch(:projectId)
      assert_equal "cred.appspot.com", config.firebase_web_config.fetch(:storageBucket)
    end
  ensure
    RecordingStudioNotificationsPush.reset_configuration!
  end

  def test_generated_initializer_falls_back_to_env_when_credentials_are_blank
    with_generated_template do |template|
      with_firebase_env(ENV_FIREBASE) do
        with_credentials({}) do
          RecordingStudioNotificationsPush.reset_configuration!
          load template
        end
      end

      config = RecordingStudioNotificationsPush.configuration
      assert_equal "env-project", config.firebase_project_id
      assert_equal "env-vapid", config.vapid_public_key
      assert_equal '{"type":"env"}', config.firebase_service_account_json
      assert_equal "env-api-key", config.firebase_web_config.fetch(:apiKey)
    end
  ensure
    RecordingStudioNotificationsPush.reset_configuration!
  end

  ENV_FIREBASE = {
    "FIREBASE_PROJECT_ID" => "env-project",
    "FIREBASE_VAPID_PUBLIC_KEY" => "env-vapid",
    "FIREBASE_SERVICE_ACCOUNT_JSON" => '{"type":"env"}',
    "FIREBASE_API_KEY" => "env-api-key",
    "FIREBASE_APP_ID" => "env-app",
    "FIREBASE_AUTH_DOMAIN" => "env.firebaseapp.com",
    "FIREBASE_MESSAGING_SENDER_ID" => "env-sender",
    "FIREBASE_STORAGE_BUCKET" => "env.appspot.com"
  }.freeze

  CREDENTIAL_FIREBASE = {
    project_id: "cred-project",
    vapid_public_key: "cred-vapid",
    service_account_json: '{"type":"credentials"}',
    api_key: "cred-api-key",
    app_id: "cred-app",
    auth_domain: "cred.firebaseapp.com",
    messaging_sender_id: "cred-sender",
    storage_bucket: "cred.appspot.com"
  }.freeze

  private

  def with_generated_template
    with_temp_app do |dir|
      build_generator(dir).copy_initializer
      generated = File.join(dir, "config/initializers/recording_studio_notifications_push.rb")
      template = File.expand_path(
        "../lib/generators/recording_studio_notifications_push/install/templates/" \
        "recording_studio_notifications_push.rb",
        __dir__
      )
      assert_equal File.read(template), File.read(generated)
      yield template
    end
  end

  def with_firebase_env(values)
    original = values.keys.index_with { |key| ENV.fetch(key, nil) }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def with_credentials(values, &)
    credentials = Object.new
    credentials.define_singleton_method(:dig) do |namespace, key|
      namespace == :firebase ? values[key] : nil
    end
    application = Object.new
    application.define_singleton_method(:credentials) { credentials }
    Rails.stub(:application, application, &)
  end
end
