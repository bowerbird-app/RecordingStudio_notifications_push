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
    with_config_root do |root|
      xcfg = Struct.new(:recording_studio_notifications_push).new({ firebase_project_id: "from-x" })
      app_config = Struct.new(:x).new(xcfg)
      app = Struct.new(:config, :paths) do
        def config_for(_name)
          { vapid_public_key: "from-yaml" }
        end
      end.new(app_config, config_paths(root))

      find_initializer("recording_studio_notifications_push.load_config").block.call(app)

      assert_equal "from-yaml", RecordingStudioNotificationsPush.configuration.vapid_public_key
      assert_equal "from-x", RecordingStudioNotificationsPush.configuration.firebase_project_id
    end
  end

  def test_missing_configuration_file_is_ignored
    root = Pathname(Dir.mktmpdir)
    app = Struct.new(:config, :paths).new(Struct.new(:x).new(nil), config_paths(root))
    def app.config_for(_name)
      raise "config_for should not run without a file"
    end

    find_initializer("recording_studio_notifications_push.load_config").block.call(app)

    assert_nil RecordingStudioNotificationsPush.configuration.vapid_public_key
  ensure
    FileUtils.remove_entry(root) if root
  end

  def test_invalid_configuration_yaml_raises
    with_config_root do |root|
      app = Struct.new(:config, :paths).new(Struct.new(:x).new(nil), config_paths(root))
      def app.config_for(_name)
        raise Psych::SyntaxError.new("config", 1, 1, 0, "bad", "context")
      end

      assert_raises(Psych::SyntaxError) do
        find_initializer("recording_studio_notifications_push.load_config").block.call(app)
      end
    end
  end

  def test_other_configuration_runtime_errors_raise
    with_config_root do |root|
      app = Struct.new(:config, :paths).new(Struct.new(:x).new(nil), config_paths(root))
      def app.config_for(_name)
        raise "yaml permission denied"
      end

      assert_raises(RuntimeError) do
        find_initializer("recording_studio_notifications_push.load_config").block.call(app)
      end
    end
  end

  def test_broken_configuration_yaml_raises_from_the_file
    root = Pathname(Dir.mktmpdir)
    previous_application = Rails.application
    previous_app_class = Rails.app_class
    FileUtils.mkdir_p(root.join("config"))
    File.write(root.join("config/recording_studio_notifications_push.yml"), ":\n  - [\n")
    app = Class.new(Rails::Application).instance
    app.config.root = root

    error = assert_raises(RuntimeError) do
      find_initializer("recording_studio_notifications_push.load_config").block.call(app)
    end
    assert_match(/YAML syntax error/, error.message)
  ensure
    Rails.app_class = previous_app_class
    Rails.application = previous_application
    FileUtils.remove_entry(root) if root
  end

  def test_merge_x_configuration_raises
    options = Object.new
    def options.to_h
      raise "bad x config"
    end
    xcfg = Struct.new(:recording_studio_notifications_push).new(options)
    app = Struct.new(:config).new(Struct.new(:x).new(xcfg))

    error = assert_raises(RuntimeError) do
      RecordingStudioNotificationsPush::Engine.merge_x_configuration(app)
    end
    assert_equal "bad x config", error.message
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

  def test_asset_initializer_appends_javascript_when_the_host_has_assets
    paths = []
    assets = Object.new
    assets.define_singleton_method(:paths) { paths }
    config = Object.new
    config.define_singleton_method(:assets) { assets }
    app = Object.new
    app.define_singleton_method(:config) { config }

    find_initializer("recording_studio_notifications_push.assets").block.call(app)

    assert_includes paths.map(&:to_s),
                    RecordingStudioNotificationsPush::Engine.root.join("app/javascript").to_s
  end

  def test_asset_initializer_skips_a_host_without_assets
    app = Struct.new(:config).new(Object.new)

    assert_nil find_initializer("recording_studio_notifications_push.assets").block.call(app)
    refute app.config.respond_to?(:assets)
  end

  def test_importmap_initializer_appends_the_engine_importmap
    paths = []
    importmap = Object.new
    importmap.define_singleton_method(:paths) { paths }
    config = Object.new
    config.define_singleton_method(:importmap) { importmap }
    app = Object.new
    app.define_singleton_method(:config) { config }

    find_initializer("recording_studio_notifications_push.importmap").block.call(app)

    assert_includes paths.map(&:to_s),
                    RecordingStudioNotificationsPush::Engine.root.join("config/importmap.rb").to_s
  end

  def test_importmap_initializer_skips_a_host_without_importmap
    app = Struct.new(:config).new(Object.new)

    assert_nil find_initializer("recording_studio_notifications_push.importmap").block.call(app)
  end

  def test_pwa_registrar_follows_whether_the_pwa_gem_can_register_an_extension
    missing = Module.new
    present = Module.new
    present.define_singleton_method(:register_service_worker_extension) { |*| }

    with_pwa(nil) do
      assert_nil RecordingStudioNotificationsPush::Engine.pwa_registrar
    end
    with_pwa(missing) do
      assert_nil RecordingStudioNotificationsPush::Engine.pwa_registrar
    end
    with_pwa(present) do
      assert_same present, RecordingStudioNotificationsPush::Engine.pwa_registrar
    end
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

  def with_pwa(value)
    had = Object.const_defined?(:RecordingStudioPwa, false)
    saved = Object.send(:remove_const, :RecordingStudioPwa) if had
    Object.const_set(:RecordingStudioPwa, value) if value
    yield
  ensure
    Object.send(:remove_const, :RecordingStudioPwa) if Object.const_defined?(:RecordingStudioPwa, false)
    Object.const_set(:RecordingStudioPwa, saved) if had
  end

  def find_initializer(name)
    RecordingStudioNotificationsPush::Engine.initializers.find { |entry| entry.name == name }
  end

  def with_config_root
    root = Pathname(Dir.mktmpdir)
    FileUtils.mkdir_p(root.join("config"))
    File.write(root.join("config/recording_studio_notifications_push.yml"), "vapid_public_key: present\n")
    yield root
  ensure
    FileUtils.remove_entry(root) if root
  end

  def config_paths(root)
    dir = root.join("config").to_s
    path = Object.new
    path.define_singleton_method(:existent) { File.directory?(dir) ? [dir] : [] }
    { "config" => path }
  end
end
