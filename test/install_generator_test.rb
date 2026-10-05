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
end
