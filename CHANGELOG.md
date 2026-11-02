# Changelog

## Unreleased

## 0.6.7

### Changed

- Development and dummy apps pin FlatPack ref `a8d24dee` (`0.1.335`), which
  adds `FlatPack::List::Item` `title` and `subtitle` and sidebar `version:`.
- Development and dummy apps pin PWA ref `0d4d01bc` (`0.7.0`) with
  `>= 0.7.0`, `< 0.8`.
- Device rows use those list slots. The dummy sidebar header shows this gem's
  version.
- The lockfile carries nokogiri `1.19.6`, loofah `2.25.3`, and
  rails-html-sanitizer `1.7.2`.
- Runtime dependency `flat_pack` is `>= 0.1.335`, `< 0.2`.

### Upgrade notes

- Bump to `0.6.7`. No migration. Device lists can pass `title:` and `subtitle:`
  to `FlatPack::List::Item`. Sidebar headers can pass `version:`.
  Stay on PWA `0.7.x`.

## 0.6.6

### Changed (behavior)

- FCM `webpush.fcm_options.link` is the absolute `https` open URL from
  `RecordingStudioNotifications.notification_url`. The data payload still
  carries the notification's own URL for the service worker.
- A missing `default_url_options` host leaves that link unset. The push still
  sends. Other `ArgumentError`s from `notification_url` are raised.
- Runtime dependency `recording_studio_notifications` is `>= 0.14.7`, `< 1`.

### Changed

- Control characters in click and icon URLs are rejected by
  `RecordingStudioNotifications::UrlSafety`. The local character check is gone.
- Development pins use notifications tag `v0.14.7`.

### Upgrade notes

- Bump to `0.6.6`. Requires notifications `0.14.7` or newer. No migration.
- Set `config.action_mailer.default_url_options` host and `protocol: "https"`
  so the push click opens the notification and marks it read. An `http` open
  URL is not copied into `fcm_options.link`. Without a host, the push still
  sends and the service worker uses `data.url`.

## 0.6.5

### Changed

- Runtime dependency `recording_studio` is `>= 6.1.0`, `< 7`.
- Development pins: PWA `v0.6.1`.
- Dummy pins: PWA `v0.6.1`, plus Root Switchable `v0.11.3` and Internationalization
  `v0.2.0`.
- `view_component` stays `4.20.0`.

### Upgrade notes

- Bump to `0.6.5`. No migration. Hosts on Recording Studio 7 are out of range.
- Move PWA to `v0.6.1` with this gem. PWA no longer
  reads `api_key`, `enable_feature_x`, or `timeout`. This gem does not set them.
- Internationalization `v0.2.0` drops `hooks.extend_model` and
  `hooks.extend_controller`. This dummy never used them.

## 0.6.4

### Changed

- The bell in the dummy top nav is `recording_studio_notifications_async_menu`.
- The dummy sidebar header is FlatPack's header, with no hand-rolled buttons
  and no version badge.
- Config docs use `FlatPack::Table`. The home "Test results" heading is a
  section title.
- The devices page renders in the dummy app shell, with one title and no
  back/close bar.
- The home page keeps an in-app inbox beside the test pings.
- The dummy language select submits on change, with no submit button and no
  stacked label, and uses the small button padding so it matches the top bar.
  The theme control is the cog. Its menu is a Theme radio group (System,
  Light, Dark), with a check on the saved choice. System is checked when
  nothing is saved. The language heading and select sit in the phone-only
  panel and use the default field border. The workspace switcher keeps the
  current workspace name. Below the `md` breakpoint the select sits in the
  cog menu and the switcher sits in the sidebar drawer, on a sidebar-item
  row under a Workspace label, so the top bar is one row.
- Home test results use a FlatPack list row, text, and a badge per channel.
  Delivered is the success badge. Failed is the danger badge.
- The home in-app inbox uses the same current-root set as the bell, resolved
  through the notifications configuration. It walks that set in batches, keeps
  eight authorized rows, and stops. A test ping refreshes the bell as soon as
  it sends.
- Unchecked theme checks stay in the row. The dummy stylesheet hides them
  inside the theme menu, so the labels share one gutter. The Theme heading
  uses the same item inset as the Language heading. The theme menu controller
  sits on the radio group. The theme menu sets `--duration-base` to `0ms`, so
  the panel is opaque on the first frame and stays on the solid surface color.
  The dummy system test opens the cog and checks that the panel opacity
  and background alpha are both 1.
  In dark mode the language select in that menu uses the field surface and
  full-contrast text, from the same dummy layer as the rest of the menu.
- The config initializer path wraps on a narrow screen. The Ruby sample scrolls instead of breaking mid-token.
- Dummy popover reposition script and its CSS are gone.
- Development and dummy apps pin FlatPack `v0.1.332`.
- The lockfile carries nokogiri `1.19.6`, loofah `2.25.3`, and
  rails-html-sanitizer `1.7.2`.
- Devices use `recording_studio_layout`, which reads
  `RecordingStudio.configuration.layout` (`flat_pack_sidebar` in the dummy).

### Upgrade notes

- Bump to `0.6.4`. No migration. Hosts that copied
  `sidebar_popover_reposition` can delete it. Mount the notifications bell
  with `recording_studio_notifications_async_menu`.

## 0.6.3

### Changed

- The dummy root switcher uses Root Switchable's default access check and
  available roots. A person only sees workspaces they can view.
- Return-path checks rescue `ActionController::RoutingError` only, inside the
  initializer. There is no top-level `internal_route?`.
- The dummy application layout is `layout :application_layout`. The unused
  `recording_studio_layout` block is gone.

### Upgrade notes

- Bump to `0.6.3`. No migration. This is dummy-app behavior. Hosts that copied
  `access_check { true }` should delete it and grant view access instead.

## 0.6.2

### UrlSafety

Click and icon URLs go through `RecordingStudioNotifications::UrlSafety`.
This replaces the local URL check:

- `javascript:` URLs and protocol-relative URLs are dropped.
- An icon URL is kept only when it is a same-origin path, or an absolute
  `http`/`https` URL whose host is in `allowed_url_hosts`.
- `webpush.fcm_options.link` is set only for an absolute `https` URL. A
  relative notification URL is no longer copied there.
- Control characters in a URL are still rejected in this gem until a later
  notifications release takes that check.

### Changed

- Runtime dependency `recording_studio_notifications` is `>= 0.14.0`, `< 1`.

### Upgrade notes

- Bump to `0.6.2`. Requires notifications `0.14.0` or newer. No migration.
- Put banner icon hosts in `allowed_url_hosts`, or use a same-origin path.
- A relative notification URL is no longer copied into `fcm_options.link`.

## 0.6.1

### Changed

- Push payload URL checks live in `Event::Url`, and delivery field reads live
  in `Event::Payload`.
- FCM fan-out goes through `FcmAdapter#deliver_each`.
- Google OAuth JWTs are built by `GoogleAccessToken::Assertion`.
- Device user-agent labels live in `Installation::UserAgent`.
- `Installation.disable!` still accepts `reason:` and still does not store it.
- `Installation.upsert!` still accepts the same keyword arguments. An unknown
  keyword raises `ArgumentError`.

### Upgrade notes

- Bump to `0.6.1`. No migration. Do not pass extra keywords to `upsert!`.

## 0.6.0

### Changed

- Host YAML loads only when the file exists. Invalid YAML and other
  configuration errors raise. A missing file still boots.
- `Api::Access.can_view?` no longer turns resolver bugs into a silent deny.
- Device route helpers rescue `ArgumentError` only. `NoMethodError` propagates.
- FCM and Google token requests share `Http.build`.

### Upgrade notes

- Bump to `0.6.0`. No migration.
- A broken `config/recording_studio_notifications_push.yml` now stops boot.
  Delete the file if you do not use it.
- A raising admin recording resolver is no longer reported as "not allowed".

## 0.5.8

### Changed

- Tests use `minitest-mock` instead of a global `Object#stub` patch.
- Admin and PWA presence in tests goes through `Api::Access.admin_loaded?`,
  `admin_configuration`, and `Engine.pwa_registrar`.
- HTTP client tests use plain response doubles.
- Version and dependency-pin literals are no longer hard-coded in tests.

### Upgrade notes

- Bump to `0.5.8`. No migration. `minitest-mock` is a development dependency
  of this repo, not a runtime dependency.

## 0.5.7

### Changed

- CI Postgres database name is `recording_studio_notifications_push_test`.
- Dummy development and test databases read `DB_NAME_DEVELOPMENT` and
  `DB_NAME_TEST`, so one shared `DB_NAME` cannot point both at the same
  database.
- Credential tests no longer assert a `gem_template` API key. The encrypted
  credentials file is unchanged.

### Upgrade notes

- Bump to `0.5.7`. No migration. Set `DB_NAME_DEVELOPMENT` and `DB_NAME_TEST`
  if you overrode the dummy database name with `DB_NAME`.

## 0.5.6

### Removed

- Template leftovers: `docs/gem_template`, `UPDATE_SUMMARY.md`, `bin/rename_gem`,
  rename tests and Rake tasks, `test_codespaces_setup.sh`, the saved dummy
  install page, device layout screenshots, `hello_controller.js`, empty `.keep`
  files, nested `test/dummy/.github`, and the template docs pages for
  recordable types, the recordings tree, gem views, and methods.
- Tracked `test/dummy/coverage` output. `coverage/` was already gitignored.
- The dummy `Workspace` include of `RecordingStudio::Capabilities::Example`.
  Accessible stays on.

### Changed

- Copilot and architect notes name this push engine.
- The dummy wiring test is `DummyPushWiringTest`.
- Development pin docs no longer say parent gems are unpublished.

### Notes

- Tag `v0.5.1` points at `e9bbbe4`, where `VERSION` is `0.5.0`. There is no
  `0.5.1` changelog section. That tag stays as published.

### Upgrade notes

- Bump to `0.5.6`. No migration. `MIGRATION_NOTES.md` still has the `0.5.4`
  host steps.

## 0.5.5

### Security

- Development and dummy locks pin `rack` `3.2.8` (GHSA-2j8w-xcrc-x985,
  GHSA-5v64-555j-wjxm, GHSA-p8x9-v4hv-2w4g, GHSA-wvg4-6p58-3gh3). `view_component`
  stays `4.20.0`.

### Upgrade notes

- Bump to `0.5.5`. No migration. Re-bundle so `rack` resolves to `3.2.8` or newer.

## 0.5.4

### Changed

- Runtime dependency `recording_studio` is now `>= 6.1.0`. Development and dummy
  apps pin core tag `v6.3.0` and FlatPack tag `v0.1.329`.
- Companion dummy pins: notifications `v0.14.1`, PWA `v0.5.0`, notifications
  email `v0.4.0`, Accessible `v0.24.0`, Trashable `v0.12.0`, Metrics `v0.7.0`,
  Cache `v0.6.0`, Root Switchable `v0.11.2`, and Internationalization `v0.1.8`.
- Dummy chrome follows core 6 layout: `recording_studio_layout`, a String
  Root Switchable `config.layout`, and FlatPack Card `border:` / `shadow:`
  instead of `style:`.
- `DevicesController` uses `recording_studio_layout` instead of
  `RecordingStudio::UsesDefaultLayout`. The devices view calls
  `flat_pack_page_nav` (core 6 page nav) instead of
  `recording_studio_page_nav`.

### Upgrade notes

- Bump to `0.5.4`. Requires Recording Studio `>= 6.1.0`. Stay on `0.5.3` if
  you are still on Recording Studio 4.
- Pin PWA to `v0.5.0` and notifications email to `v0.4.0` (both require
  Recording Studio `>= 6.1.0`).
- No migration in this gem.

## 0.5.3

### Changed

- Runtime dependency `recording_studio_metrics` is `>= 0.3.0, < 1.0` (CI tested
  with Metrics `0.5.0`). No code change.

## 0.5.2

Accepts Recording Studio Metrics through `0.5`. Dummy pins Metrics `v0.5.0`
when that tag resolves with the rest of the lock.

### Changed

- Runtime dependency `recording_studio_metrics` is `>= 0.3.0, < 0.6` (GitHub
  tag `v0.5.0` in this repo). Hosts may stay on Metrics `0.3` or `0.4`.

### Upgrade notes

- Bump to `0.5.2`. No migration.
- Pin `recording_studio_metrics` at tag `v0.5.0` when other host gems allow
  Metrics `0.5`. Keep `v0.3.1` if a sibling gem still requires `~> 0.2`.
- Keep `RecordingStudioMetrics::Api.register!(api: :operations)` in the host.

## 0.5.0

Requires Recording Studio Metrics `0.3` so hosts that also run MCP `0.17` can
list one tool per push-device metric.

### Changed

- Runtime dependency `recording_studio_metrics` is `>= 0.3.0, < 0.4` (GitHub
  tag `v0.3.1`). Hosts pinning Metrics `v0.2.0` must move to `v0.3.1`.

### Added

- README names the MCP `0.17` tools for the existing `:push_devices` metrics:
  `push_devices-by_platform`, `push_devices-active`, and
  `push_devices-new_over_time`. Only the timeseries tool takes `from`, `to`,
  and `interval`. This gem still does not call
  `RecordingStudioMetrics::Api.register!`.

### Upgrade notes

- Bump to `0.5.0`. No migration.
- Pin `recording_studio_metrics` at tag `v0.3.1`.
- Keep `RecordingStudioMetrics::Api.register!(api: :operations)` in the host.

## 0.4.0

Site-wide push device metrics register with Recording Studio Metrics for the
operations API.

### Added

- `RecordingStudioNotificationsPush::Metrics.register!` registers
  `:push_devices` (`blast_radius: :site`) with RecordingStudioMetrics.
  Metrics: `push_devices.by_platform` (`platform`), `push_devices.active`
  (`Installation.active` / `disabled_at` nil), `push_devices.new_over_time`
  (`created_at`). Each metric is exposed on `:operations` only.
  `api_authorize` uses `RecordingStudioNotificationsPush::Api::Access.can_view?`
  (AdminRoot `:view`). The admin recording is `site_admin_recording_resolver`,
  or `access_recording_resolver` when the site resolver is unset. A resolver
  error denies the metric.
- Runtime dependency `recording_studio_metrics` `~> 0.2` (GitHub tag `v0.2.0`).

### Upgrade notes

- Bump to `0.4.0`. No migration.
- Add `recording_studio_metrics` at tag `v0.2.0`.
- This gem does not call `RecordingStudioMetrics::Api.register!`. The host
  registers Metrics endpoints once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

## 0.3.0

Customer-facing push devices copy now lives under
`recording_studio.notifications_push.*` so hosts can translate the opt-in
screen, flashes, Stimulus strings, and default payloads this gem generates.

### Added

- Engine ships English only in `config/locales/en.yml`
- Nested keys: `t("recording_studio.notifications_push.devices.title")`
- Dummy hosts English and French via Recording Studio Internationalization, with
  a compact language selector in the top nav (left of the theme selector)
- Stimulus enable/disable copy, permission denied, and unsupported-browser
  messages are passed from I18n (no hard-coded English in JS)

### Upgrade notes

- Bump to **0.3.0** (minor: hosts can translate the push devices screen). No
  migration
- English screens stay the same. `TestPush` `title:` / `body:` arguments still
  win over locale defaults, including `nil`
- To offer another language, copy `recording_studio.notifications_push.*` from
  `config/locales/en.yml` into the host (`config/locales/<locale>.yml`) and list
  that locale in `config.i18n.available_locales`. Dummy
  `test/dummy/config/locales/fr.yml` is a complete starting point
- Do not add `RecordingStudio_Internationalization` as a gem dependency of this
  engine. Use plain Rails I18n. Internationalization is a host (and dummy)
  concern
- Notification titles and bodies stored by the parent notifications gem stay
  untranslated. Stored device labels stay as written
- Developer errors (missing recipient, missing Firebase installation id,
  invalid service-account JSON, FCM HTTP failures) stay English
- Dummy pins notifications `v0.4.1` and Flatpack `v0.1.209`. The gemspec still
  allows `recording_studio_notifications` `>= 0.3.0, < 1`
- Dummy adds `RecordingStudio_Internationalization` `v0.1.2` as a host-only
  dependency. Development and dummy Gemfiles pin notifications to tag `v0.4.1`
  (was the OTP payload branch). PWA stays on
  `cursor/pwa-service-worker-seam-453c`

## 0.2.6

Firebase config reads Rails credentials, then ENV.

Tags `v0.2.3` through `v0.2.5` already exist on this repository while `main`
still had `VERSION` `0.2.2`; this release ships as `0.2.6`.

### Changed

- `Configuration` resolves Firebase values when they are read:
  `Rails.application.credentials.dig(:firebase, :key)` first, then
  `ENV["FIREBASE_*"]`. Credential keys are `api_key`, `app_id`,
  `auth_domain`, `messaging_sender_id`, `project_id`, `storage_bucket`,
  `vapid_public_key`, and `service_account_json`.
- `service_account_json` may be a nested hash or a JSON string.
- The install generator initializer uses the same
  `credentials.dig(...) || ENV[...]` pattern as RecordingStudio_AI.
- README documents a `bin/rails credentials:edit` YAML block and which
  key is send-only (the service account).

### Upgrade notes

- Bump to `0.2.6`. ENV-only hosts need no changes.
- Optional: move secrets into Rails credentials under `firebase:` using the
  snake_case keys above. Keep `test/dummy/config/master.key` out of git.

## 0.2.2

Devices screens use Recording Studio core's default layout.

### Changed

- `DevicesController` includes `RecordingStudio::UsesDefaultLayout` instead of
  `layout "recording_studio_notifications_push/blank"`.
- The devices show template no longer renders `FlatPack::PageNav`. Core layout
  owns back and close. `recording_studio_page_nav` still sets the document
  title and Close to the host root.
- Removed the unused gem `blank` layout.
- When Firebase is not configured, the devices Alert uses FlatPack
  `style: :warning`. The page no longer offers a Firebase installation id
  paste field or Register this id. Manage notifications stays on that branch.
- The devices page title is **Connected devices**. The subtitle is
  **Your connected devices that can receive notifications**. The browser
  tab uses the same title via `recording_studio_page_nav`.
- The devices page no longer has Not getting alerts? or the help Modal.

### Upgrade notes

- Bump to `0.2.2`. No schema or configuration changes.
- If a host overrode `recording_studio_notifications_push/blank`, include
  `RecordingStudio::UsesDefaultLayout` (or set
  `layout "recording_studio/default_layout"`) on the devices controller
  instead. Do not render a second PageNav in the devices template.
- Tailwind must scan FlatPack components and Recording Studio default layout
  views so core PageNav back/close can paint. Dummy writes those `@source`
  paths at `tailwindcss:build` via `tailwindcss:enhance_sources`.
- Drop any host override of the unconfigured FID paste field. Set `FIREBASE_*`
  and use Enable on this browser.
- Drop any host copy of Not getting alerts? and the help Modal on devices.

## 0.2.1

Cloud Agent Builds fetch Recording Studio skills. A warm rebuild does not fail
the install hook.

### Added

- Cloud Agent Builds run `.cursor/install.sh`, then `.cursor/fetch-skills.sh`.
  On a warm snapshot the install hook skips apt, ruby-build, db:prepare, and
  tailwind when Ruby, bundle, and Postgres are already usable. A skippable
  provision failure does not fail the Build. Fetch-skills always runs last.

### Upgrade notes

- No host or schema changes. Rebuild the Cloud Agent environment with Draft
  off so Build loads the pack.

## 0.2.0

### Added
- `FcmAdapter#available_for?` returns false when the recipient has no active push
  installations.

### Changed
- Push `Event` resolves title, body, and url via
  `RecordingStudioNotifications.delivery_payload_for` when a delivery is present.
- Require `recording_studio_notifications` `>= 0.3.0`.

### Upgrade notes
- Install `recording_studio_notifications` `0.3.0` (or later) before bumping to
  `0.2.0`.

## 0.1.15

### Changed
- `FcmAdapter` builds one FCM payload per notification before fanning out to
  installations instead of recomputing title, body, url, and metadata assets
  for every device
- `Event#metadata` is memoized so icon and image resolution reuse one frozen
  copy
- Firebase web-client readiness now lives on
  `RecordingStudioNotificationsPush.configuration.web_push_client_ready?`
- Devices page secondary actions (Manage notifications, Not getting alerts?)
  render from one shared template block
- Removed unused `testPushUrlTemplate` Stimulus value from the push devices
  controller

## 0.1.14

### Changed
- Help modal title is now **Not receiving push notifications?**
- Removed browser/OS detection line, permission status line, and system-toggle
  disclaimer from the help modal — only the step lists remain

## 0.1.13

### Fixed
- Notification help modal is filled on page load (before it is opened), with
  generic fallback steps in HTML when JavaScript has not run yet
- Push devices Stimulus controller is preloaded so browser and OS detection
  finishes before users tap **Not getting alerts?**

## 0.1.12

### Changed
- Notification help now follows the same three-step format for every detected
  browser and OS, using vendor-documented settings paths
- iPhone and iPad guidance now correctly requires an iOS/iPadOS 16.4+ Home
  Screen web app and points to that web app—not the browser—in Notifications
- iPhone and iPad setup in Firefox or Opera directs users to a supported
  installation browser instead of implying in-tab website push support
- Safari on Mac now points to the website entry under Application Notifications

## 0.1.11

### Changed
- Mac Chrome help modal steps now point to `chrome://settings/`, Privacy and
  security → Site settings → Notifications, and “Sites can ask to send
  notifications”

## 0.1.10

### Added
- Devices page **Not getting alerts?** opens a help modal with steps tailored to
  the detected browser and OS (site permission + system notification settings)

## 0.1.9

### Changed
- Devices page puts **Enable** and **Manage notifications** side by side; when
  this browser is already registered, only **Manage notifications** remains

### Fixed
- RuboCop cyclomatic complexity on Event `#meta_asset`

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
