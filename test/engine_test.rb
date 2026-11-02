# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    RecordingStudioNotificationsPush.reset_configuration!
  end

  def teardown
    RecordingStudioNotificationsPush.reset_configuration!
  end

  def test_load_config_merges_config_sources
    xcfg = Struct.new(:recording_studio_notifications_push).new({ firebase_project_id: "from-x" })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { vapid_public_key: "from-yaml" }
      end
    end.new(app_config)

    find_initializer("recording_studio_notifications_push.load_config").block.call(app)

    assert_equal "from-yaml", RecordingStudioNotificationsPush.configuration.vapid_public_key
    assert_equal "from-x", RecordingStudioNotificationsPush.configuration.firebase_project_id
  end

  def test_missing_configuration_file_is_ignored
    app = Struct.new(:config).new(Struct.new(:x).new(nil))
    app.define_singleton_method(:config_for) do |_name|
      raise "Could not load configuration. No such file - recording_studio_notifications_push"
    end

    find_initializer("recording_studio_notifications_push.load_config").block.call(app)

    assert_nil RecordingStudioNotificationsPush.configuration.vapid_public_key
  end

  def test_invalid_configuration_yaml_raises
    app = Struct.new(:config).new(Struct.new(:x).new(nil))
    app.define_singleton_method(:config_for) { |_name| raise Psych::SyntaxError.new("config", 1, 1, 0, "bad", "context") }

    assert_raises(Psych::SyntaxError) do
      find_initializer("recording_studio_notifications_push.load_config").block.call(app)
    end
  end

  def test_other_configuration_runtime_errors_raise
    app = Struct.new(:config).new(Struct.new(:x).new(nil))
    app.define_singleton_method(:config_for) { |_name| raise "yaml permission denied" }

    assert_raises(RuntimeError) do
      find_initializer("recording_studio_notifications_push.load_config").block.call(app)
    end
  end

  def test_register_channel_initializer_exists
    initializer = find_initializer("recording_studio_notifications_push.register_channel")
    refute_nil initializer
  end

  def test_metrics_initializer_registers_definitions
    initializer = find_initializer("recording_studio_notifications_push.metrics")
    refute_nil initializer
  end

  def test_pwa_initializer_exists
    initializer = find_initializer("recording_studio_notifications_push.register_pwa_service_worker")
    refute_nil initializer
  end

  def test_engine_loads_only_english_locale_files
    locale_dir = RecordingStudioNotificationsPush::Engine.root.join("config/locales")
    loaded = I18n.load_path.select { |path| path.to_s.start_with?(locale_dir.to_s) }

    assert(Dir[locale_dir.join("*")].any? { |path| path.end_with?("en.yml") })
    refute(Dir[locale_dir.join("*")].any? { |path| path.end_with?("fr.yml") })
    assert(loaded.any? { |path| path.end_with?("en.yml") }) if loaded.any?
    refute(loaded.any? { |path| path.end_with?("fr.yml") })
  end

  private

  def find_initializer(name)
    RecordingStudioNotificationsPush::Engine.initializers.find { |entry| entry.name == name }
  end
end
