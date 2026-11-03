# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class RootSwitchDropdownTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "sign in page uses the devise layout and is not squished by the default layout" do
    get new_user_session_path

    assert_response :success
    assert_includes response.body, "admin@admin.com"
    assert_includes response.body, "Password"
    assert_includes response.body, 'data-theme="rounded"'
    refute_includes response.body, "data-recording-studio-default-layout"
    refute_includes response.body, "mt-28"
    refute_includes response.body, "fixed inset-0"
  end

  test "home page renders the root switch dropdown trigger" do
    user = User.find_or_create_by!(email: "root-switch-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    workspace = Workspace.create!(name: "Dropdown Workspace")
    grant_owner!(user, RecordingStudio.root_recording_for(workspace))

    get root_path

    assert_response :success
    assert_includes response.body, workspace.name
    assert_includes response.body, "flat-pack-sidebar-layout"
  end

  test "root switch page renders with the host sidebar" do
    user = User.find_or_create_by!(email: "root-switch-page-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    workspace = Workspace.create!(name: "Switch Page Workspace")
    grant_owner!(user, RecordingStudio.root_recording_for(workspace))

    get "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces"

    assert_response :success
    assert_includes response.body, "Push devices"
  end

  test "switching returns to the current page when it is a valid internal route" do
    user = User.find_or_create_by!(email: "root-switch-redirect-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    source_workspace = Workspace.create!(name: "Source Workspace")
    target_workspace = Workspace.create!(name: "Target Workspace")
    target_root_recording = RecordingStudio.root_recording_for(target_workspace)
    grant_owner!(user, RecordingStudio.root_recording_for(source_workspace))
    grant_owner!(user, target_root_recording)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: target_root_recording.id,
        return_to: "/docs/install"
      }
    }

    assert_redirected_to "/docs/install"
  end

  test "switching falls back to home when return_to is not a valid internal route" do
    user = User.find_or_create_by!(email: "root-switch-fallback-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    source_workspace = Workspace.create!(name: "Fallback Source Workspace")
    target_workspace = Workspace.create!(name: "Fallback Target Workspace")
    target_root_recording = RecordingStudio.root_recording_for(target_workspace)
    grant_owner!(user, RecordingStudio.root_recording_for(source_workspace))
    grant_owner!(user, target_root_recording)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: target_root_recording.id,
        return_to: "/not-a-real-route"
      }
    }

    assert_redirected_to "/"
  end

  test "root switcher lists a granted workspace and hides an ungranted one" do
    user = User.find_or_create_by!(email: "root-switch-mixed@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    visible = Workspace.create!(name: "Visible Workspace #{SecureRandom.hex(4)}")
    hidden = Workspace.create!(name: "Hidden Workspace #{SecureRandom.hex(4)}")
    grant_owner!(user, RecordingStudio.root_recording_for(visible))
    RecordingStudio.root_recording_for(hidden)

    get "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces"

    assert_response :success
    assert_includes response.body, visible.name
    refute_includes response.body, hidden.name
  end

  test "switching to an ungranted workspace is rejected" do
    user = User.find_or_create_by!(email: "root-switch-rejected@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    visible = Workspace.create!(name: "Allowed Workspace #{SecureRandom.hex(4)}")
    hidden = Workspace.create!(name: "Blocked Workspace #{SecureRandom.hex(4)}")
    grant_owner!(user, RecordingStudio.root_recording_for(visible))
    hidden_root = RecordingStudio.root_recording_for(hidden)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: hidden_root.id,
        return_to: "/"
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, visible.name
    refute_includes response.body, hidden.name
  end

  private

  def grant_owner!(user, recording)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user).value!
  end
end
