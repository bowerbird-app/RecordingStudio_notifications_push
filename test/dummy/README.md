# Dummy app

This Rails app exists to validate the Recording Studio push notifications
addon. It mounts:

- `RecordingStudio` at `/recording_studio` (redirects to `/`)
- `RecordingStudioNotifications` at `/notifications`
- `RecordingStudioNotificationsPush` at `/notifications/push`
- PWA manifest + service-worker routes for the SW composition seam

Sign in with the seeded admin user (`admin@admin.com` / `Password`) and open
**Manage devices**. When Firebase ENVs are set, use **Enable on this browser**.
When they are not, the page shows a warning and keeps Manage notifications.
Dummy home and the devices screen stay on the host sidebar. The devices
screen is titled **Connected devices**. Hosts that do not set a layout get
Recording Studio's Default Layout (back and close) from the gem.

The dummy ships English and French. Use the language selector in the top nav
(left of the theme selector) to switch. Engine copy lives under
`recording_studio.notifications_push.*`; French overrides are in
`config/locales/fr.yml`.
