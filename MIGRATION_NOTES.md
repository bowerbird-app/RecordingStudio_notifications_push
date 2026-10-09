# Migration notes

## 0.4.0

### Host app steps

1. Bump to `0.4.0`. No schema or push-delivery changes.
2. Add `recording_studio_metrics` at tag `v0.2.0`. Hosts that expose the
   operations API should pin `recording_studio_api` `v0.6.11` and call
   `RecordingStudioMetrics::Api.register!(api: :operations)` once.
3. Authorize staff through Accessible `:view` on the AdminRoot recording.
   This gem does not register Metrics API routes itself.

## 0.3.0

### Host app steps

1. Bump to `0.3.0`. No configuration or migration changes are required.
2. English screens stay the same. To offer another language, copy
   `recording_studio.notifications_push.*` from `config/locales/en.yml` into
   `config/locales/<locale>.yml` and list that locale in
   `config.i18n.available_locales`.
3. Do not add `RecordingStudio_Internationalization` to this gem. Add it in the
   host if you want a language selector.
4. Notification titles/bodies and stored device labels stay as written.
   `TestPush.new(title:, body:)` still wins over locale defaults.
5. Parent notifications `0.5.x` is compatible (`>= 0.3.0, < 1`). Dummy uses
   `v0.5.0`.

## 0.2.6

### Host app steps

1. Bump to `0.2.6`. ENV-only hosts need no changes.
2. Optional: store Firebase secrets in `bin/rails credentials:edit` under
   `firebase:` (`api_key`, `app_id`, `auth_domain`, `messaging_sender_id`,
   `project_id`, `storage_bucket`, `vapid_public_key`). `service_account_json`
   is required only to send and may be a nested hash or a JSON string.
3. Re-run `bin/rails generate recording_studio_notifications_push:install` if
   you want the initializer to show the credentials-then-ENV assignments.

## 0.2.2

### Host app steps

1. Bump to `0.2.2`. No configuration or migration changes are required.
2. Devices now render inside Recording Studio's default layout. If you overrode
   `recording_studio_notifications_push/blank`, include
   `RecordingStudio::UsesDefaultLayout` or set
   `layout "recording_studio/default_layout"` on that controller instead.
3. Remove any host copy of the devices PageNav. Core layout already draws
   back and close.
4. Confirm the host Tailwind entry scans FlatPack components and Recording
   Studio default layout views. Dummy writes those paths at `tailwindcss:build`
   with `rake tailwindcss:enhance_sources`.
5. The devices page no longer accepts a pasted Firebase installation id when
   Firebase is unset. Set `FIREBASE_*` and use Enable on this browser. Hosts
   that overrode the unconfigured branch should drop that field too.
6. Drop any host copy of Not getting alerts? and the help Modal on devices.

## 0.2.0

### Host app steps

1. Bump `recording_studio_notifications` to `0.3.0` (or later) first.
2. Bump `recording_studio_notifications_push` to `0.2.0`. No configuration or
   migration changes are required.

## 0.1.15

### Host app steps

1. Bump to `0.1.15`. No configuration or migration changes are required.

## 0.1.14

### Host app steps

1. Bump to `0.1.14` and hard-refresh the push devices page.

## 0.1.13

### Host app steps

1. Bump to `0.1.13` and hard-refresh the push devices page so the preloaded
   help modal JavaScript loads.
2. No configuration changes are required.

## 0.1.12

### Host app steps

1. Bump to `0.1.12` and refresh the devices page for the fact-checked browser
   and OS help.
2. On iPhone and iPad, make sure the PWA manifest has a clear app name. Users
   find that Home Screen web app name—not Safari or Chrome—in Settings →
   Notifications.

## 0.1.11

### Host app steps

1. Bump to `0.1.11` and refresh the devices page so the updated Mac Chrome
   help steps load.

## 0.1.10

### Host app steps

1. Bump to `0.1.10` and refresh the devices page so the help modal and client
   detection script load.

## 0.1.9

### Host app steps

1. Bump to `0.1.9` and refresh the devices page.
2. Enable and Manage notifications now share one row. After this browser is
   enabled, only Manage notifications stays visible.

## 0.1.8

### Host app steps

1. Bump to `0.1.8` and hard-refresh / re-register the service worker so it picks
   up absolute icon URL resolution.
2. Prefer absolute `https://…` icon URLs in `metadata[:icon]` when the host is
   not same-origin with the worker (path-only values still work and are
   absolutized in the worker).
3. **macOS Chrome:** the left OS badge is the Chrome app icon. Custom
   `icon` / `image` values show on Windows and Android; macOS may only show a
   small secondary thumbnail, or none.

## 0.1.7

### Host app steps

1. Bump to `0.1.7`.
2. To customize the OS banner thumbnail per notification, pass
   `metadata: { icon: "/your-icon.png" }` (or an https URL) into
   `RecordingStudioNotifications.notify`. The service worker still falls back
   to `/icon.png` when `icon` is omitted.

## 0.1.6

### Host app steps

1. Bump to `0.1.6` and refresh the devices page.
2. Removing a device uses Turbo `DELETE` and returns you to the devices list.
3. **Manage notifications** on the devices page opens the parent gem settings at
   `/notifications/settings` (or wherever that engine is mounted).

## 0.1.1

### Host app steps

1. Bump to `0.1.1` and restart so Propshaft digests pick up the refreshed
   service-worker extension.
2. Hard-refresh browsers (or unregister the old service worker) so they load the
   SW that calls `registration.showNotification` for native Chrome banners.
3. Native display is owned by the PWA service-worker extension
   (`showNotification`), not an in-page HTML toast.
4. Enable push on **each** browser under `/notifications/push/devices` — FCM
   only reaches registered installations for that account.
5. New route `POST /installations/:id/test_push` backs the devices-page
   diagnostics. It is scoped to the current actor's own active installations.

## 0.1.0 (from gem template)

This repository was renamed from the Recording Studio gem template to
`recording_studio_notifications_push`. Template sample tables and capabilities
are gone.

### Host app steps

1. Add the gem and parent notifications gem.
2. Run `bin/rails generate recording_studio_notifications_push:install`.
3. Run `bin/rails generate recording_studio_notifications_push:migrations`.
4. Set Firebase ENV vars (see README). Service account JSON is required to
   **send**; UI registration can run without it.
5. Mount the engine (suggested `/notifications/push`).
6. Enable `:push` on notification types in the parent notifications initializer.
7. If using `recording_studio_pwa`, mount manifest + service-worker routes so
   the push SW extension can load.

### Breaking vs template

- Removes `recording_studio_notifications_push_pages` sample migration.
- Removes example capability hooks and template home controller.
- Version is `0.1.0` for the product gem (not a continuation of template `0.2.0`).

### Bundler note: notifications_email + Recording Studio 4.2

`recording_studio_notifications_email` `v0.3.4` gemspecs `recording_studio ~> 4.2`
and `recording_studio_notifications >= 0.3.0, < 1`. Root and dummy Gemfiles pin
that GitHub tag. Override with `RECORDING_STUDIO_NOTIFICATIONS_EMAIL_PATH` when
testing against a local checkout.

Notifications stays on branch `cursor/otp-delivery-payload-78f4` because tag
`v0.3.4` does not contain that OTP payload commit. PWA stays on
`cursor/pwa-service-worker-seam-453c` because tag `v0.2.3` does not contain the
service-worker seam commit. Do not move those pins until the target tag is an
ancestor of the pinned commit.
