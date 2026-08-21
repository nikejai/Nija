# Development Log

This log captures implementation decisions, deployment lessons, and recurring
debugging notes that should remain visible across release cycles. Use
`CHANGELOG.md` for user-facing change history; use this file for engineering
context and operational follow-up.

## 2026-08-21 22:58:51 IST

### Free tier while monetization is deferred

Context:

- Client-side monetization on web is not a strong boundary, and the immediate
  product priority is beta usability.
- Google Play Billing remains useful on Android for a future supporter unlock.

Decision:

- Make the free tier 151 MB.
- Enable cloud backup and restore in the free app.
- Keep one vault as the free default through configurable vault-count limits.
- Keep `nija_expanded_vault_lifetime` for Android 1 GB storage and Android
  multi-vault support.

Follow-up:

- Revisit monetization after beta usage data and decide whether web/iOS need a
  backend entitlement service or should remain free.

## 2026-08-21 18:18:18 IST

### Startup entitlement check before cloud restore

Context:

- Android release builds can start with the locally cached entitlement while
  Google Play Billing restore is still querying Play.
- Cloud restore is not a paid feature, but release restore failures can look
  related to paid status because both Google Play and Google Drive initialize
  near startup.

Decision:

- Track the app-level Play entitlement refresh during startup and pass that
  state into Settings.
- Show a visible `Checking Google Play purchase...` storage entitlement state
  while startup restore is in progress.
- Refresh entitlement state before cloud import, cloud restore, and cloud
  backup actions. Backup and restore are now available to free users.

Diagnostics:

- If cloud restore still fails only in release, check the Google Cloud Android
  OAuth client for the exact release signing SHA-1 and Play App Signing SHA-1,
  confirm the Drive API is enabled, and confirm the signed-in tester is allowed
  by the OAuth consent/testing configuration.

## 2026-08-21 17:55:45 IST

### Hardened wasm web release on cPanel/Apache hosts

Context:

- Local hardened web builds worked with `python3 -m http.server` and
  `flutter run -d chrome --wasm`.
- Hostinger served the hardened Flutter wasm release correctly.
- MilesWeb showed Nija's wasm startup fallback message even in a supported
  browser, which indicated a deployment/hosting response problem rather than
  browser incompatibility.

Decision:

- Added `web/.htaccess` for cPanel/Apache/LiteSpeed hosting.
- Updated `scripts/harden_web_release.sh` to copy `web/.htaccess` into
  `build/web/.htaccess` after each hardened web build.
- The `.htaccess` file explicitly sets `.wasm` and `.mjs` MIME types, applies
  security/cache headers, serves existing assets directly, and rewrites only
  unknown SPA routes to `index.html`.

Deployment checks:

- Upload the contents of `build/web` into `public_html`, including hidden file
  `.htaccess`.
- Confirm these URLs return real files with HTTP 200, not the Nija HTML page:
  `/main.dart.wasm`, `/main.dart.mjs`, `/canvaskit/skwasm.js`, and
  `/canvaskit/skwasm.wasm`.
- Confirm `.wasm` responses use `Content-Type: application/wasm`.
- Confirm `.mjs` responses use a JavaScript MIME type such as
  `text/javascript`.
- If MilesWeb/cPanel hides dotfiles, enable hidden files or upload `.htaccess`
  manually into `public_html`.

Follow-up:

- If a supported browser still shows the wasm startup fallback after these
  checks, inspect DevTools Network for 404/HTML responses on wasm/module assets
  and clear any old service worker/site data.
