# frozen_string_literal: true

module RecordingStudioNotificationsPush
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioNotificationsPush

    def self.load_host_configuration(app)
      merge_yaml_configuration(app)
      merge_x_configuration(app)
    end

    def self.merge_yaml_configuration(app)
      return unless app.respond_to?(:config_for)

      yaml = app.config_for(:recording_studio_notifications_push)
      RecordingStudioNotificationsPush.configuration.merge!(yaml) if yaml.respond_to?(:each)
    rescue RuntimeError => e
      raise unless e.message.match?(/Could not load configuration\. No such file/i)
    end

    def self.merge_x_configuration(app)
      return unless app.config.respond_to?(:x)

      x_config = app.config.x
      return unless x_config.respond_to?(:recording_studio_notifications_push)

      options = x_config.recording_studio_notifications_push
      RecordingStudioNotificationsPush.configuration.merge!(options.to_h) if options.respond_to?(:to_h)
    end

    # @api private
    def self.pwa_registrar
      return unless defined?(RecordingStudioPwa)
      return unless RecordingStudioPwa.respond_to?(:register_service_worker_extension)

      RecordingStudioPwa
    end

    initializer "recording_studio_notifications_push.assets" do |app|
      app.config.assets.paths << root.join("app/javascript") if app.config.respond_to?(:assets)
    end

    initializer "recording_studio_notifications_push.importmap", before: "importmap" do |app|
      next unless app.config.respond_to?(:importmap)

      app.config.importmap.paths << root.join("config/importmap.rb")
    end

    initializer "recording_studio_notifications_push.load_config" do |app|
      Engine.load_host_configuration(app)
    end

    initializer "recording_studio_notifications_push.register_channel",
                after: "recording_studio_notifications_push.load_config" do
      config.to_prepare { RecordingStudioNotificationsPush.register! }
    end

    initializer "recording_studio_notifications_push.metrics" do
      config.to_prepare { RecordingStudioNotificationsPush::Metrics.register! }
    end

    initializer "recording_studio_notifications_push.register_pwa_service_worker",
                after: "recording_studio_notifications_push.register_channel" do
      config.to_prepare do
        registrar = Engine.pwa_registrar
        next unless registrar

        registrar.register_service_worker_extension(
          "recording_studio_notifications_push/service_worker_push"
        )
      end
    end
  end
end
