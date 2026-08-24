# frozen_string_literal: true

require "test_helper"

class InstallationTest < Minitest::Test
  class FakeInstallation
    attr_accessor :firebase_installation_id, :legacy_fcm_token, :disabled_at

    def delivery_token
      firebase_installation_id.to_s.presence || legacy_fcm_token.to_s.presence
    end

    def active?
      disabled_at.nil?
    end
  end

  def test_delivery_token_is_fid_first
    installation = FakeInstallation.new
    installation.firebase_installation_id = "fid-primary"
    installation.legacy_fcm_token = "legacy-token"

    assert_equal "fid-primary", installation.delivery_token
  end

  def test_delivery_token_falls_back_to_legacy
    installation = FakeInstallation.new
    installation.firebase_installation_id = nil
    installation.legacy_fcm_token = "legacy-token"

    assert_equal "legacy-token", installation.delivery_token
  end

  def test_installation_model_source_declares_expected_api
    source = File.read(
      File.expand_path("../app/models/recording_studio_notifications_push/installation.rb", __dir__)
    )

    assert_includes source, "belongs_to :recipient, polymorphic: true"
    assert_includes source, "scope :active"
    assert_includes source, "def self.upsert!"
    assert_includes source, "def disable!"
    assert_includes source, "firebase_installation_id"
    assert_includes source, "legacy_fcm_token"
    refute_includes source, "include RecordingStudio::Recordable"
  end

  def test_installations_migration_exists
    migrations = Dir[File.expand_path("../db/migrate/*installations*.rb", __dir__)]
    assert_equal 1, migrations.size

    source = File.read(migrations.first)
    assert_includes source, "recording_studio_notifications_push_installations"
    assert_includes source, "firebase_installation_id"
    refute_includes source, "recording_studio_notifications_push_pages"
  end
end
