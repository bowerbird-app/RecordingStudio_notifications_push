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
    assert_top_bar_names_workspace(workspace.name)

    label = css_select("[data-flat-pack-sidebar-section-title] p").find { |node| node.text.strip == "Workspace" }
    assert label, "the drawer should label the workspace switcher"
    row = css_select("[data-flat-pack-sidebar-item]").find { |node| node.text.include?(workspace.name) }
    assert row, "the drawer should show the current workspace on a sidebar row"
    assert_includes row["class"], "px-[var(--sidebar-item-padding-x)]"
    assert_includes row["class"], "py-[var(--sidebar-item-padding-y)]"
    assert_includes row["class"], "text-sm"
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

  def assert_top_bar_names_workspace(name)
    theme = css_select("[data-controller~='flat-pack--theme']").first
    assert theme, "theme control should be on the top bar"
    assert_select theme, "[data-flat-pack--button-dropdown-target=trigger]", count: 1

    desktop = css_select(".fp-top-nav [data-flat-pack--button-dropdown-target=trigger]").find { |node|
      classes = node.ancestors.map { |ancestor| ancestor["class"].to_s.split }.flatten
      classes.include?("md:flex") && node.text.include?(name)
    }
    assert desktop, "desktop top bar should show #{name}"
    refute_includes theme.text, name

    drawer = css_select("[class~='md:hidden']").find { |node|
      node.text.include?(name) && !node.ancestors.include?(desktop)
    }
    assert drawer, "mobile sidebar drawer should show #{name}"
  end

  def grant_owner!(user, recording)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user).value!
  end
end
