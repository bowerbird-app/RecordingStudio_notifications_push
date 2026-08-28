# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

# Create the admin user
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

# Create the workspace recordables
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")

previous_actor = Current.actor
Current.actor = user

begin
  # Create the root recording
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)
ensure
  Current.actor = previous_actor
end

if defined?(RecordingStudioNotificationsPush::Installation) &&
   RecordingStudioNotificationsPush::Installation.table_exists?
  seed_push_devices = [
    { fid: "seed-push-chrome-mac", label: "Chrome on Mac", platform: "web", seen: 2.hours.ago },
    { fid: "seed-push-safari-iphone", label: "Safari on iPhone", platform: "ios", seen: 1.day.ago },
    { fid: "seed-push-firefox-windows", label: "Firefox on Windows", platform: "web", seen: 3.days.ago }
  ]

  seed_push_devices.each do |device|
    installation = RecordingStudioNotificationsPush::Installation.upsert!(
      recipient: user,
      firebase_installation_id: device[:fid],
      label: device[:label],
      platform: device[:platform],
      user_agent: "Seeded demo device"
    )
    installation.update_columns(last_seen_at: device[:seen], updated_at: device[:seen])
  end

  puts "Seeded: #{seed_push_devices.size} push devices for #{user.email}"
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
