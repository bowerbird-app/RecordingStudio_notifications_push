# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class DummyPushWiringTest < ActiveSupport::TestCase
  test "dummy app loads root switchable config and controller support" do
    assert_equal [ "all_workspaces" ], RecordingStudioRootSwitchable.configuration.scopes.keys
    assert_equal "flat_pack_sidebar", RecordingStudioRootSwitchable.configuration.layout
    assert_equal "flat_pack_sidebar", RecordingStudio.configuration.layout
    assert_includes ApplicationController.ancestors, RecordingStudio::RootSwitchable::ControllerSupport
  end

  test "dummy app validates recordable declarations" do
    assert RecordingStudio.validate_recordable_declarations!
    assert_equal [ "Workspace" ], RecordingStudio.root_recordable_types
    assert_equal [ "Workspace", "Folder" ], RecordingStudio.allowed_parent_types_for("Page")
  end

  test "dummy app schema keeps accessible grants and excludes removed core tables" do
    connection = ActiveRecord::Base.connection

    assert connection.column_exists?(:recording_studio_recordings, :root_recording_id)
    assert connection.table_exists?(:recording_studio_accesses)
    assert connection.table_exists?(:recording_studio_access_invitations)
    assert connection.table_exists?(:recording_studio_access_constraints)
    assert connection.table_exists?(:recording_studio_access_rules)
    assert connection.table_exists?(:recording_studio_access_requests)
    assert connection.table_exists?(:recording_studio_access_request_intents)
    role_column = connection.columns(:recording_studio_accesses).find { |column| column.name == "role" }
    assert_equal :string, role_column.type
    refute connection.table_exists?(:recording_studio_access_boundaries)
    refute connection.table_exists?(:recording_studio_device_sessions)
  end

  test "dummy seeds use hierarchy idempotently and restore current actor" do
    Current.actor = nil

    load Rails.root.join("db/seeds.rb").to_s

    workspace = Workspace.find_by!(name: "Studio Workspace")
    accessible_workspace = Workspace.find_by!(name: "Client Workspace")
    private_workspace = Workspace.find_by!(name: "Private Workspace")
    folder = Folder.find_by!(name: "Product Docs")
    page = Page.find_by!(title: "Getting Started")
    root_recording = RecordingStudio::Recording.find_by!(recordable: workspace)
    accessible_root_recording = RecordingStudio::Recording.find_by!(recordable: accessible_workspace)
    private_root_recording = RecordingStudio::Recording.find_by!(recordable: private_workspace)
    folder_recording = RecordingStudio::Recording.find_by!(recordable: folder)
    page_recording = RecordingStudio::Recording.find_by!(recordable: page)

    assert_nil Current.actor
    assert_nil root_recording.parent_recording_id
    assert_nil accessible_root_recording.parent_recording_id
    assert_nil private_root_recording.parent_recording_id
    assert_equal root_recording, folder_recording.parent_recording
    assert_equal root_recording, folder_recording.root_recording
    assert_equal folder_recording, page_recording.parent_recording
    assert_equal root_recording, page_recording.root_recording
    assert_equal 3, Workspace.count
    assert RecordingStudioAccessible.authorized?(
      actor: User.find_by!(email: "admin@admin.com"),
      recording: root_recording,
      role: "admin"
    )

    assert_no_difference -> { User.count } do
      assert_no_difference -> { RecordingStudio::Recording.count } do
        load Rails.root.join("db/seeds.rb").to_s
      end
    end
    assert_nil Current.actor
  ensure
    Current.actor = nil
  end

  test "workspace opts into accessible without inventing custom access" do
    assert RecordingStudio.capability_enabled?(:accessible, for: Workspace)
    refute RecordingStudio.capability_enabled?(:example, for: Workspace)
    refute RecordingStudio.capability_enabled?(:accessible, for: Folder)
    refute RecordingStudio.capability_enabled?(:accessible, for: Page)
  end

  test "push channel and installations table are wired" do
    assert RecordingStudioNotifications.channels.registered?(:push)
    assert ActiveRecord::Base.connection.table_exists?(:recording_studio_notifications_push_installations)
    assert ActiveRecord::Base.connection.table_exists?(:recording_studio_notifications_email_suppressions)
    assert ActiveRecord::Base.connection.column_exists?(:recording_studio_notifications_notifications, :inbox)
    assert_equal :push, RecordingStudioNotificationsPush.configuration.channel
  end

  test "push devices route is mounted" do
    assert_equal "/notifications/push/devices",
                 RecordingStudioNotificationsPush::Engine.routes.url_helpers.devices_path
  end
end

class DummyPushChromeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "home chrome shows the notifications bell and the sidebar" do
    user = User.find_or_create_by!(email: "chrome-bell@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in user

    get root_path

    assert_response :success
    assert_includes response.body, "flat-pack-sidebar-layout"
    assert_includes response.body, "recording-studio-notifications--notification-polling"
    assert_includes response.body, "Push demo"
    refute_includes response.body, "Change language"
    refute_includes response.body, "sidebar_popover_reposition"
  end
end
