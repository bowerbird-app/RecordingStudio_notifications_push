# Dummy app

This Rails app exists to validate the Recording Studio push notifications
addon. It mounts:

- `RecordingStudio` at `/recording_studio` (redirects to `/`)
- `RecordingStudioNotifications` at `/notifications`
- `RecordingStudioNotificationsPush` at `/notifications/push`
- PWA manifest + service-worker routes for the SW composition seam

Sign in with the seeded admin user (`admin@admin.com` / `Password`) and open
**Manage devices**. When Firebase ENVs are set, use **Enable on this browser**.
When they are not, the page shows a warning and keeps Manage notifications /
Not getting alerts? Dummy home stays on the host sidebar. The devices screen
uses Recording Studio's default layout (back and close), not that sidebar.
