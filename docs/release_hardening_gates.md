# Release Hardening Gates

Use this document as the release gate before tagging any production build.

## 1) Security Review Checklist

- [ ] Recovery phrase handling verified (never logged, validated, and reset flow works).
- [ ] Master password rotation and recovery rotation verified.
- [ ] Vault unlock failures return safe generic errors (no secret leakage).
- [ ] Migration/version checks reject unsupported future versions.
- [ ] Sensitive input fields are cleared on lock/background transitions.

## 2) Production Configuration Checks

- [ ] `debugShowCheckedModeBanner` is disabled in app shell.
- [ ] `PrototypeCryptoAdapter` is not used by production wiring.
- [ ] No secret-bearing debug logs in app code.
- [ ] Crash/error messages do not include raw vault payload/key material.
- [ ] Web adapter uses encrypted payload model consistently.
- [ ] Release builds use obfuscation/hardening where supported.
- [ ] Android release builds use production signing, R8/ProGuard, native `SYMBOL_TABLE` debug-symbol handling, and private Dart debug-symbol archival.
- [ ] Client bundles contain no secrets, entitlement bypasses, debug endpoints, or sensitive constants.

## 3) WebApp Release Gates

- [ ] Web release build steps are documented and reproducible.
- [ ] Web app is installable on iOS Safari and Android Chrome with production icons, manifest, theme color, and mobile viewport behavior.
- [ ] Web app starts and unlocks previously created encrypted vault data while offline after the first successful load.
- [ ] Service worker/cache strategy does not cache decrypted vault contents, recovery phrases, master passwords, or raw secret exports.
- [ ] IndexedDB/local web storage contains only encrypted vault data and non-secret app preferences.
- [ ] HTTPS-only deployment is enforced with appropriate security headers, including the checked-in CSP/header policy in `web/_headers` or `firebase.json`.
- [ ] Browser visibility/background behavior locks or protects sensitive vault surfaces consistently with native app expectations.
- [ ] Web production artifacts are hardened with `./scripts/harden_web_release.sh` after the wasm build.
- [ ] Wasm-only web releases run `./scripts/harden_web_release.sh` and `./scripts/release_hardening_gate.sh --web-flavor=wasm-only`.
- [ ] Wasm-only deployable artifacts do not include `build/web/main.dart.js`.
- [ ] Wasm-only `build/web/flutter_bootstrap.js` contains only the `dart2wasm` app build and includes the unsupported-browser upgrade message.
- [ ] JS-compatible web releases for iOS PWA run `./scripts/harden_web_release.sh --compat-js` and `./scripts/release_hardening_gate.sh --web-flavor=compat-js`.
- [ ] JS-compatible deployable artifacts include `main.dart.js`, `main.dart.wasm`, `nija_integrity_manifest.json`, and `nija_integrity_manifest.sig`.
- [ ] JS-compatible release gates verify the manifest signature and every listed artifact hash before upload.
- [ ] Required runtime JavaScript remains present: Flutter bootstrap/runtime, renderer support, service-worker cleanup, and Nija browser bridge files.
- [ ] cPanel/Apache/LiteSpeed deployments include `build/web/.htaccess` so `.wasm` and `.mjs` assets are not served as `index.html` or blocked by `nosniff`.
- [ ] Static-host artifacts are readable by the web server: directories `755`, files `644`; release gate rejects unreadable files/directories.
- [ ] Stable web entry files and integrity metadata are no-cache: `main.dart.js`, `main.dart.mjs`, `main.dart.wasm`, and `nija_integrity_*`.

## 4) Final Validation Matrix

Run all checks:

```bash
flutter build web --release --wasm -O4 --no-source-maps --csp
./scripts/harden_web_release.sh
./scripts/release_hardening_gate.sh --web-flavor=wasm-only
```

For a JS-compatible iOS PWA deployment:

```bash
./scripts/build_web_compat_release.sh
```

The helper produces `build/web` and, after the compat-js gate passes,
`.release/web/<timestamp>/web.zip` for cPanel/static-host upload. The archive
is created from the validated `build/web` contents and includes `.htaccess`.

For CI or stable production keys:

```bash
flutter build web --release --wasm -O4 --no-source-maps --csp \
  --dart-define=NIJA_WEB_INTEGRITY_ENABLED=true \
  --dart-define=NIJA_WEB_INTEGRITY_PUBLIC_KEY_B64=<public-key> \
  --dart-define=NIJA_WEB_INTEGRITY_BUILD_ID=<build-id>
NIJA_WEB_INTEGRITY_PRIVATE_KEY_B64=<private-seed> \
NIJA_WEB_INTEGRITY_BUILD_ID=<build-id> \
  ./scripts/harden_web_release.sh --compat-js
./scripts/release_hardening_gate.sh --web-flavor=compat-js
```

The compat-js gate verifies manifest signature and hashes, then checks the
compiled web artifact contains the expected public-key and build-id markers so
manual builds cannot accidentally ship with runtime web checks disabled.

Platform run validation:

- [ ] Web: create -> unlock -> lock -> unlock -> recovery unlock -> reset password.
- [ ] Web installed-app mode on iOS: create -> unlock -> offline restart -> unlock -> CRUD persistence.
- [ ] Web installed-app mode on Android: create -> unlock -> offline restart -> unlock -> CRUD persistence.
- [ ] Android: create -> unlock -> lock -> unlock -> recovery unlock -> reset password.
- [ ] iOS: create -> unlock -> lock -> unlock -> recovery unlock -> reset password.
- [ ] Rotation validation on each platform:
  - [ ] master-password rotation
  - [ ] recovery phrase rotation
- [ ] CRUD persistence validation on each platform after app restart.
