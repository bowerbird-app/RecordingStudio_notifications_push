# Changelog

## Unreleased

### Changed
- Devices page uses a blank engine layout with FlatPack `PageNav` (same shape as notifications settings) — no host sidebar or top nav
- Dummy home page adds a Turbo **Test notification** button that sends `:push_demo` (respects notification settings) and prepends results on the page
- Dummy importmap loads `@hotwired/turbo-rails` so Turbo Stream updates work on the home page

### Fixed
- Resolve service-worker URL via `main_app.pwa_service_worker_path` so the devices page works inside the mounted engine
- Prefer the host app layout (FlatPack sidebar) for non-devices push screens instead of forcing `UsesDefaultLayout`
- Dummy Tailwind `@source` paths cover system Ruby Bundler installs after merging main
- Dummy PWA head hook resolves manifest/service-worker routes through `main_app` so mounted engine pages (e.g. `/notifications/push/devices`) register the worker instead of rejecting with "PWA service worker route is not mounted"
- Push devices Stimulus controller falls back to an explicit `navigator.serviceWorker.register` when `RecordingStudioPwa.serviceWorkerReady` rejects for a missing host helper
- Clearer devices-page errors when the browser cannot reach Chrome's push service (`Registration failed - push service not available`) — usually Brave/privacy settings or blocked Google push, not missing Firebase ENV
- Dummy Stimulus `controllers/index.js` only lazy-loads under `controllers` so push/FlatPack pins resolve (nested prefixes requested doubled paths and left Enable as a no-op)
- Devices "Enable on this browser" binds via controller event delegation (`data-push-enable`) so the click runs when the Stimulus controller is connected
- Devices page swaps to "Disable on this browser" when the current browser's FCM token matches an active installation

## 0.1.0

First product release of the Recording Studio Firebase push channel.

- Register `:push` with `RecordingStudioNotifications`
- Store installations in `recording_studio_notifications_push_installations`
- FCM HTTP v1 client with hand-rolled service-account OAuth (no googleauth)
- Flatpack devices page + Stimulus registration controller
- PWA service-worker extension partial for background `showNotification`
- Install + migrations generators
- No rollups / no `deliver_rollup`
