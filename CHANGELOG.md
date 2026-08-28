# Changelog

## Unreleased

## 0.1.8

### Fixed
- Service worker resolves notification `icon` / `image` to absolute URLs before
  `showNotification` (relative paths were easy to miss on forwarded origins)
- Push `metadata[:icon]` / `[:image]` accept absolute http(s) URLs without the
  notification URL host allowlist (banner assets are not navigation targets)

### Changed
- Dummy icon test sends store absolute icon+image URLs and preview the thumbnail
  in the home inbox / test results
- Dummy copy notes that macOS Chrome keeps the Chrome app badge on the left

## 0.1.7

### Added
- Push payloads include `data.icon` from notification `metadata[:icon]` so the
  service worker can show a custom OS banner thumbnail (falls back to `/icon.png`)
- Dummy home has **Test coral icon** and **Test teal icon** buttons that send
  push demos with `/push-icon-coral.png` and `/push-icon-teal.png`

## 0.1.6

### Added
- Devices page **Manage notifications** default button under the subtitle links to
  the parent notifications settings screen

### Fixed
- Devices trash button uses `data-turbo-method="delete"` so remove redirects back
  to `/notifications/push/devices` instead of a GET routing error

## 0.1.5

### Changed
- Push devices page title is **Push Notifications** with subtitle **Get notifications on your devices**
- Enable button reads **Enable on this device** in an installed PWA and **Enable on this browser** in a normal tab
- Device list uses FlatPack `List` with mobile (`device_phone_mobile`) or desktop (`computer_desktop`) leading icons
- Remove uses a FlatPack ghost icon button (`trash`) instead of a text link
- Empty-state copy and inline enable status text removed
- When push is already enabled on this browser/device, the enable button is hidden (use **Remove** on the list row to turn off)

## 0.1.4

### Fixed
- FCM web sends are **data-only** again; the service worker always calls `showNotification`. Skipping display when FCM included a `notification` block left Chrome with no banner because an active service worker must show it itself.

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
