# Migration notes

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

Upstream `recording_studio_notifications_email` on `main` still gemspecs
`recording_studio >= 3, < 4`, which conflicts with this gem's `~> 4.2` stack and
`recording_studio_pwa`. Until that pin is bumped, set:

```bash
export RECORDING_STUDIO_NOTIFICATIONS_EMAIL_PATH=/path/to/patched/email/checkout
```

and patch that checkout's gemspec to `recording_studio ~> 4.2` (and ideally
`recording_studio_notifications >= 0.2`). The Gemfiles fall back to github
`main` when the ENV is unset.
