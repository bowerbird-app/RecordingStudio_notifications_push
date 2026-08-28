# Changelog

## Unreleased

### Added
- Dummy `/docs/install` walks through host setup and states that
  `recording_studio_notifications` and `recording_studio_pwa` are required
- Dummy `/docs/config` documents the push addon settings, ENV keys, timeouts,
  and `configuration.to_h`
- Devices page has a **Not getting alerts?** section with two checks that isolate where a notification stops:
  - **Show a local notification** calls `registration.showNotification` with no FCM, so an invisible result points at browser/OS notification settings
  - **Send a test push** posts to `POST /installations/:id/test_push` and reports exactly what FCM answered
- Devices page shows diagnostics: page origin, notification permission, service-worker state and scope, and push subscription host
- `RecordingStudioNotificationsPush::TestPush` sends one diagnostic message to a single installation and returns an `accepted` / `status` / `error` result

### Changed
- FCM web sends are **data-only** again so the service worker shows one OS banner (including both `notification` and `data` duplicated alerts when the worker was active) — **reverted in 0.1.3**; use notification+data with SW dedupe instead
- Devices page no longer shows the **Not getting alerts?** troubleshooting section (local notification + test push checks). The `test_push` API endpoint remains for programmatic use.
- FCM web sends include **both** `notification` and `data` so a browser whose service worker is stale still has a payload to display instead of dropping a data-only message
- The PWA service-worker extension owns native Chrome `showNotification` (OS banner — not an in-page HTML toast)
- Invalid FCM registration tokens (`INVALID_ARGUMENT` / "not a valid FCM registration token") disable that installation
- Devices page uses a blank engine layout with FlatPack `PageNav` (same shape as notifications settings) — no host sidebar or top nav
- Dummy home page adds a Turbo **Test notification** button that sends `:push_demo` (respects notification settings) and prepends results on the page
- Dummy home also lists recent **in-app inbox** rows so inbox delivery is visible without opening `/notifications`
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

## 0.1.3

### Fixed
- Restore FCM `notification` payloads for web push display; data-only sends stopped showing alerts in Chrome
- Service worker only skips `showNotification` when the push payload includes a real notification title/body (avoids swallowing data-only messages that still carry an empty `notification` object)

## 0.1.2

### Fixed
- FCM web sends no longer include a `notification` block alongside `data`, which duplicated OS banners when the service worker was active

## 0.1.1

### Changed
- Data-only FCM web payloads so the service worker shows a **native Chrome** notification via `showNotification`
- Disable installations on invalid FCM registration tokens
- Service worker notification options include `/icon.png` for a standard Chrome banner look

## 0.1.0

First product release of the Recording Studio Firebase push channel.

- Register `:push` with `RecordingStudioNotifications`
- Store installations in `recording_studio_notifications_push_installations`
- FCM HTTP v1 client with hand-rolled service-account OAuth (no googleauth)
- Flatpack devices page + Stimulus registration controller
- PWA service-worker extension partial for background `showNotification`
- Install + migrations generators
- No rollups / no `deliver_rollup`
