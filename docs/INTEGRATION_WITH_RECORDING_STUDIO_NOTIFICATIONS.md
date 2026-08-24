# Integration with RecordingStudioNotifications

This gem is a **channel addon**. It does not own notification rows, preferences,
or delivery jobs.

## Responsibilities

| Layer | Owner |
|---|---|
| Notification + delivery records | `recording_studio_notifications` |
| Channel preference + cadence | `recording_studio_notifications` |
| `:push` adapter + FCM HTTP v1 | this gem |
| Device installation rows | this gem (`recording_studio_notifications_push_installations`) |
| Email delivery | `recording_studio_notifications_email` |
| Service worker shell | `recording_studio_pwa` (extension seam) |

## Registration

On `to_prepare`, the engine calls:

```ruby
RecordingStudioNotificationsPush.register!
# => RecordingStudioNotifications.register_channel(:push, adapter)
```

The adapter implements `#deliver(notification:, delivery:)` only. It does **not**
implement `#deliver_rollup`. Types that defer rollups must not list `:push` as a
rollup channel.

## Delivery flow

1. Host calls `RecordingStudioNotifications.notify(...)` with `:push` selected.
2. Parent creates a delivery row and invokes the registered adapter.
3. `FcmAdapter` loads active `Installation` rows for the recipient.
4. Each installation is targeted FID-first (`firebase_installation_id`, then
   `legacy_fcm_token`).
5. `FcmClient` exchanges `FIREBASE_SERVICE_ACCOUNT_JSON` for a Google OAuth
   token and POSTs to FCM HTTP v1.
6. `UNREGISTERED` / `NOT_FOUND` responses disable that installation.
7. Delivery succeeds when **at least one** installation send succeeds.
8. If no installations exist, or every send fails, the adapter raises
   `DeliveryError`.

## PWA seam

When `RecordingStudioPwa` is loaded, this engine registers:

```ruby
RecordingStudioPwa.register_service_worker_extension(
  "recording_studio_notifications_push/service_worker_push"
)
```

The partial adds `push` and `notificationclick` handlers that call
`showNotification` from the payload. Hosts may additionally `importScripts`
Firebase messaging workers if they need SDK-managed notification payloads.

## Mount points

Suggested host routes:

```ruby
mount RecordingStudioNotifications::Engine, at: "/notifications"
mount RecordingStudioNotificationsPush::Engine, at: "/notifications/push"
```

Devices UI: `/notifications/push/devices`  
Installations JSON: `POST/DELETE /notifications/push/installations`
