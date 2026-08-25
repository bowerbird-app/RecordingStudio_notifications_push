# Changelog

## Unreleased

### Fixed
- Resolve service-worker URL via `main_app.pwa_service_worker_path` so the devices page works inside the mounted engine
- Prefer the host app layout (FlatPack sidebar) for push screens instead of forcing `UsesDefaultLayout`
- Dummy Tailwind `@source` paths cover system Ruby Bundler installs after merging main

## 0.1.0

First product release of the Recording Studio Firebase push channel.

- Register `:push` with `RecordingStudioNotifications`
- Store installations in `recording_studio_notifications_push_installations`
- FCM HTTP v1 client with hand-rolled service-account OAuth (no googleauth)
- Flatpack devices page + Stimulus registration controller
- PWA service-worker extension partial for background `showNotification`
- Install + migrations generators
- No rollups / no `deliver_rollup`
