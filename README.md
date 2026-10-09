# RecordingStudioNotificationsPush

`recording_studio_notifications_push` is the Firebase Cloud Messaging (FCM)
channel for
[`recording_studio_notifications`](https://github.com/bowerbird-app/RecordingStudio_notifications).
It is a standalone Rails engine under `RecordingStudioNotificationsPush`.

The parent notifications engine owns notification records, preferences,
background delivery, retries, and delivery status. This gem:

- registers a `:push` channel adapter
- stores **device installations** in one ActiveRecord table (not a recordable)
- sends FCM HTTP v1 messages with a service-account OAuth token
- exposes a Flatpack devices page on Recording Studio's default layout and a
  PWA service-worker extension

This channel does **not** implement rollups / `deliver_rollup`.

## Installation

```ruby
gem "recording_studio_notifications"
gem "recording_studio_notifications_push"
# Optional but recommended for installable web apps:
gem "recording_studio_pwa"
```

```bash
bundle install
bin/rails generate recording_studio_notifications:install
bin/rails generate recording_studio_notifications_push:install
bin/rails generate recording_studio_notifications_push:migrations
bin/rails db:migrate
```

Mount the engines:

```ruby
mount RecordingStudioNotifications::Engine, at: "/notifications"
mount RecordingStudioNotificationsPush::Engine, at: "/notifications/push"

# Host PWA chrome (from recording_studio_pwa)
get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
```

During Rails preparation this engine registers:

```ruby
RecordingStudioNotifications.register_channel(
  :push,
  RecordingStudioNotificationsPush.adapter
)
```

When `RecordingStudioPwa` is present it also registers the service-worker
extension partial
`recording_studio_notifications_push/service_worker_push`.

## Configuration

Firebase values are resolved when they are read: Rails credentials under
`firebase:` first, then matching `FIREBASE_*` environment variables. Hosts can
still override any key in `RecordingStudioNotificationsPush.configure`.

ENV-only hosts keep working. `service_account_json` /
`FIREBASE_SERVICE_ACCOUNT_JSON` is required only for sending. Browser
registration uses the web keys and VAPID public key.

Edit credentials:

```bash
bin/rails credentials:edit
```

```yaml
firebase:
  api_key: your-web-api-key
  app_id: your-web-app-id
  auth_domain: your-project.firebaseapp.com
  messaging_sender_id: "123456789"
  project_id: your-project
  storage_bucket: your-project.appspot.com
  vapid_public_key: your-web-push-certificate-key
  # Required only to send (nested hash or a JSON string):
  service_account_json:
    type: service_account
    project_id: your-project
    client_email: firebase-adminsdk@your-project.iam.gserviceaccount.com
    private_key: "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

Matching ENV names:

| Credential | ENV | Purpose |
|---|---|---|
| `firebase.api_key` | `FIREBASE_API_KEY` | Firebase web config |
| `firebase.app_id` | `FIREBASE_APP_ID` | Firebase web config |
| `firebase.auth_domain` | `FIREBASE_AUTH_DOMAIN` | Firebase web config |
| `firebase.messaging_sender_id` | `FIREBASE_MESSAGING_SENDER_ID` | Firebase web config |
| `firebase.project_id` | `FIREBASE_PROJECT_ID` | Web config + FCM v1 project |
| `firebase.storage_bucket` | `FIREBASE_STORAGE_BUCKET` | Firebase web config |
| `firebase.vapid_public_key` | `FIREBASE_VAPID_PUBLIC_KEY` | Web Push certificate key |
| `firebase.service_account_json` | `FIREBASE_SERVICE_ACCOUNT_JSON` | Server OAuth for FCM sends |

```ruby
RecordingStudioNotificationsPush.configure do |config|
  config.channel = :push
  # Optional overrides. Defaults are credentials.dig(:firebase, ...) || ENV[...].
  # config.firebase_service_account_json =
  #   Rails.application.credentials.dig(:firebase, :service_account_json) ||
  #     ENV.fetch("FIREBASE_SERVICE_ACCOUNT_JSON", nil)
end
```

`FIREBASE_SERVICE_ACCOUNT_JSON` (and `firebase.service_account_json`) may be
unset while developing UI. Delivery raises
`RecordingStudioNotificationsPush::DeliveryError` when a send is attempted
without it.

## Parent notification setup

```ruby
RecordingStudioNotifications.register_notification_type(
  :page_comment,
  label: "Page comment",
  default_channels: %i[in_app push],
  available_channels: %i[in_app email push]
)

RecordingStudioNotifications.notify(
  notification_type: :page_comment,
  recipient: user,
  title: "New comment",
  body: "A collaborator commented on your page.",
  url: page_url(page)
)
```

## Device registration

Authenticated users visit `/notifications/push/devices` to enable the current
browser. The screen is titled Connected devices. It uses Recording Studio's
default layout for back and close. When Firebase web config is missing, the page shows a warning Alert
and keeps Manage notifications. It does not accept a
pasted installation id. When Firebase is ready, the Stimulus controller
reads web config from the page, requests notification permission, obtains a
token via Firebase Messaging (importmap pins), and POSTs an installation
JSON record.

Installations are keyed by polymorphic recipient + `firebase_installation_id`
(FID-first targeting). `legacy_fcm_token` is optional for older clients.

## Internationalization

The engine ships English defaults in `config/locales/en.yml` under
`recording_studio.notifications_push.*` and adds that file to the host I18n
load path. The devices screen, flashes, default test-push payload, fallback
banner title, and Stimulus strings resolve those keys at request time.

Other languages are the host's job. Copy the same keys into
`config/locales/<locale>.yml` and list that locale in
`config.i18n.available_locales`. A host key with the same name overrides the
English default. The dummy app's `test/dummy/config/locales/fr.yml` is a
complete French override you can copy.

`RecordingStudio_Internationalization` is optional and a host dependency. This
gem does not declare it. Hosts that want a language selector add that gem
themselves.

Notification titles and bodies stored on the parent notification (or written
by other gems) stay as written. Device labels you store yourself stay as
written. Browser labels generated from a user agent follow the current locale.

JavaScript has no hard-coded English. The devices Stimulus controller reads
copy from a `copy` value rendered from I18n (the same idea as Flatpack's
`data-fp-copy` on `<html>`). `TestPush` `title:` / `body:` arguments still win
over locale defaults, including `nil`.

## Development Gemfile pins

Until parent gems are published:

```ruby
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.4.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.11.1"
gem "recording_studio_notifications",
    github: "bowerbird-app/RecordingStudio_notifications",
    tag: "v0.5.0"
gem "recording_studio_notifications_email",
    github: "bowerbird-app/RecordingStudio_notifications_email",
    tag: "v0.3.4"
gem "recording_studio_pwa", github: "bowerbird-app/RecordingStudio_PWA", branch: "cursor/pwa-service-worker-seam-453c"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.209"
```

PWA stays on the service-worker seam branch until tag `v0.2.3` contains that
commit. See [MIGRATION_NOTES.md](MIGRATION_NOTES.md).

## Dummy credentials

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with
the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or
put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted
file; do not generate a per-repo dummy key.

## Cloud Agent boot

Cloud Agent Builds run `.cursor/install.sh`, then `.cursor/fetch-skills.sh`.
The install hook provisions a cold image. On a warm snapshot it skips apt,
ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are
already usable. If `RAILS_MASTER_KEY` is set, `install.sh` writes gitignored
`test/dummy/config/master.key` so dummy credentials decrypt. Fetch-skills always
runs last. `.cursor/start.sh` starts PostgreSQL on each boot. Rebuild with Draft
off to load a new pack. See
[Cursor skills in Cloud Agents](docs/cursor-skills.md).

## License

MIT
