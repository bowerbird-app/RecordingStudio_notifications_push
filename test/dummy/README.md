# Dummy app

This Rails app exists to validate the Recording Studio push notifications
addon. It mounts:

- `RecordingStudio` at `/recording_studio` (redirects to `/`)
- `RecordingStudioNotifications` at `/notifications`
- `RecordingStudioNotificationsPush` at `/notifications/push`
- PWA manifest + service-worker routes for the SW composition seam

Sign in with the seeded admin user, open **Manage devices**, and register a
browser (or paste a FID when Firebase ENVs are unset).
