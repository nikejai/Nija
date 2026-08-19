# Nija Ops README

This document is the operational runbook for Nija setup, backups, platform builds, release checks, and production maintenance.

Nija is local-first. The encrypted `.nija` vault file is the source of truth. Cloud features must only move encrypted vault files or encrypted portable secret files; plaintext vault data, master passwords, recovery phrases, raw keys, salts, nonces, and decrypted documents must never be logged, uploaded, cached, or placed in URLs.

## 1) Operational Principles

- Keep the app usable without a backend.
- Treat cloud backup as encrypted-file portability, not sync.
- Use the same vault crypto model on Android, iOS, and Web.
- Keep paid feature access centralized. Android expanded vault storage and cloud backup are unlocked by the Google Play product `nija_expanded_vault_lifetime` and cached locally for offline starts. `NIJA_PAID_BUILD` is a development override only.
- Store operational secrets outside git:
  - Android release keystore
  - `android/key.properties`
  - Google service files
  - Apple signing certificates/profiles
  - private debug-symbol and obfuscation-map archives

## 2) Backup Model

### What Backup Stores

- Backup uploads or writes the encrypted `.nija` vault file.
- The backup payload remains encrypted at rest with the vault's own encryption.
- Backup metadata can include non-secret fields such as vault id, revision/version labels, and timestamps.
- No decrypted vault payload, raw vault key, master password, recovery phrase, or decrypted document bytes should be stored in cloud backup metadata.

### Backup Identity

- Each vault has a `vaultId` in vault metadata.
- Backups are keyed by `vaultId` so the same vault can update the same cloud backup lineage across devices.
- Android Google Drive backup uses Drive app/private metadata such as `appProperties.nijaVaultId=<vaultId>` to find/update the matching backup.
- iOS iCloud backup writes under `Documents/vaults/<vaultId>/`.

### Current Provider Scope

- Android: Google Drive API upload/restore.
- iOS: iCloud Drive ubiquity container write/restore.
- Web today: local browser private app storage plus encrypted backup download/export flow.
- Web target: Google Drive API upload/restore through a Web OAuth client. This is a separate browser implementation from Android Google Drive backup.
- There is no cross-provider merge. Google Drive and iCloud backups are independent targets.
  Until Web Google Drive backup is implemented, web restore from cloud is expected to report that no cloud backup was found.

### Backup UX Expectations

- Free build: cloud backup controls are disabled with `Available in paid version`.
- Paid build: `Backup now`, backup account, last backup, auto-backup, frequency, and restore controls can be shown.
- Backup must be explicit, observable, and cancellable where platform APIs permit.
- If cloud backup fails, show a user-safe message. Do not expose raw stack traces or cloud API responses containing sensitive data.

## 3) Google Cloud Console Setup

Use one Google Cloud project for Nija's Google Drive backup and Google sign-in/OAuth flows. Android and Web must use separate OAuth client types inside that project.

### Required APIs and Consent

1. Create or select the Google Cloud project for Nija.
2. Enable `Google Drive API`.
3. Configure Google Auth Platform / OAuth consent:
   - app name and support email,
   - developer contact email,
   - test users while the app is in Testing mode,
   - required Drive scopes only.
4. Keep OAuth consent copy plain and privacy-focused. State that Nija uploads encrypted vault backups to the user's Drive.

### OAuth Clients

Create OAuth 2.0 Android clients for every signing key used:

- debug key for local development,
- internal/release key for production builds,
- Play App Signing key if Google Play signs production artifacts.

Android OAuth clients require:

- package name: currently `com.nija`,
- SHA-1 certificate fingerprint for the signing key.

Get SHA values:

```bash
cd android
./gradlew signingReport
```

Use the `:app:signingReport` output. Add at least SHA-1 to the Android OAuth client. Keep SHA-256 recorded as release metadata.

Create a separate OAuth 2.0 Web client for the WebApp:

- Application type: `Web application`.
- Name: `Nija Web`.
- Authorized JavaScript origins:
  - local fixed-port development origin, for example `http://localhost:5173`,
  - production origin, for example `https://app.example.com`.
- Do not add paths such as `/settings`; origins include only scheme, host, and optional port.
- Do not use the Android OAuth client for web. Android clients depend on package name and SHA-1; browser clients depend on authorized JavaScript origins.
- Do not store a client secret in the web app. Web OAuth clients use a public client id.

Recommended Web Drive scope:

```text
https://www.googleapis.com/auth/drive.file
```

Use the narrowest scope that allows Nija to create and manage encrypted backup files created by Nija. Avoid broad Drive scopes unless a product change explicitly requires them and gets a privacy/security review.

Record these values in release notes or deployment configuration:

```text
GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
GOOGLE_DRIVE_SCOPE=https://www.googleapis.com/auth/drive.file
```

Never commit OAuth client ids in secret files. Public web client ids may be present in build configuration, but still keep environment and release documentation clear so the active client id can be audited.

### Google Service File

- Place `google-services.json` at `android/app/google-services.json` if the selected Google integration requires it.
- Do not place Google service files under `lib/`.
- Do not commit secrets or local-only service files unless they are explicitly safe for public client distribution and approved for the release process.

### Common Google Issues

- `ApiException: 10` / `DEVELOPER_ERROR`: package name, OAuth client, or SHA fingerprint mismatch.
- Drive API `403` disabled error: OAuth succeeded, but the Google Drive API is not enabled in the same project.
- OAuth changes can take a few minutes to propagate. Reinstall the app after changing OAuth clients or SHA fingerprints.
- Web `origin_mismatch`: the exact browser origin is missing from the Web OAuth client's Authorized JavaScript origins.
- Web popup closes or blank popup: verify browser popup policy and deployment headers, especially `Cross-Origin-Opener-Policy`.
- Web `access_denied`: the test user is not added to OAuth audience while the app is in Testing mode, or the requested scope is not configured for the app.

### Email Usage

Nija does not currently use Gmail API or send email from the app backend.

Operational email fields are still required in consoles:

- Google OAuth support email,
- Google developer contact email,
- Play Console contact/support email,
- Apple developer/account contact email,
- App Store support URL/email if published.

If email-based features are added later, they must get a separate privacy/security review and must not receive plaintext vault data.

## 4) Android Operations

### Package and Metadata

Current Android package/application id:

```text
com.nija
```

Before production release, verify:

- app label and launcher icon,
- package id,
- version name/code in `pubspec.yaml`,
- Play Store short/long descriptions,
- privacy policy URL,
- support email,
- data safety form,
- content rating,
- screenshots and feature graphic,
- closed/internal testing tracks.

### Release Signing

Release signing is configured to fail if `android/key.properties` is missing for release tasks.

Generate a local release keystore:

```bash
keytool -genkey -v \
  -keystore ~/nija-release.jks \
  -alias nija-release \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

Create `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=nija-release
storeFile=/Users/<you>/nija-release.jks
```

Keep `android/key.properties` and the keystore out of git. Back up both
securely, ideally in a password manager plus an encrypted offline backup. If the
release keystore is lost, future app updates can be blocked unless Play App
Signing key recovery has been configured and approved.

Verify the local files exist before building:

```bash
test -f android/key.properties
test -f /Users/<you>/nija-release.jks
```

Verify signing:

```bash
cd android
./gradlew signingReport
```

Copy the release SHA-1 into the Google Cloud Android OAuth client used for Drive backup.

For the current local release keystore, `./gradlew signingReport` reports:

```text
Package name: com.nija
Debug SHA-1: 97:E7:92:C9:81:E0:30:74:18:96:81:F4:52:10:16:F0:80:02:6D:F3
Release SHA-1: 8B:3D:36:2F:FF:EA:44:19:C5:C5:A3:89:56:CB:57:E8:36:25:C2:50
Release SHA-256: 7E:AB:F5:34:40:C7:52:A5:49:ED:81:CB:B8:6B:C7:38:8E:A1:A3:B4:29:31:A2:33:97:06:A0:12:5B:90:B4:1C
```

If Google Drive backup/restore shows a message like `retry after selecting the
google account on signed application`, treat it as a Google Sign-In OAuth
configuration failure. Verify every installed build's signing SHA-1 is
registered on an Android OAuth client for `com.nija`: debug SHA-1 for
`flutter run`, release SHA-1 for locally signed APK/AAB installs, and Play App
Signing SHA-1 for Play/internal-testing installs. Wait for propagation, uninstall
the old app build, install the newly signed build, and select the same tester
Google account that is allowed by the OAuth consent screen.

If both debug and release builds fail after SHA-1 registration, pass the Web
OAuth client id from the same Google Cloud project as the native server client:

```bash
flutter run -d <android-device-id> \
  --dart-define=NIJA_GOOGLE_NATIVE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

Use the same define for release builds when validating Drive backup/restore:

```bash
flutter build apk --release \
  --dart-define=NIJA_GOOGLE_NATIVE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

### Run Locally

```bash
flutter pub get
flutter run -d android
```

Paid build run example:

```bash
flutter run -d android --dart-define=NIJA_PAID_BUILD=true
```

Useful local commands:

```bash
flutter devices
flutter run -d <android-device-id>
flutter install -d <android-device-id>
```

For Google Drive backup testing, use a device or emulator build signed with a key whose SHA-1 is registered in the Google Cloud Android OAuth client.

### Android SDK Toolchain Repair

If `flutter build appbundle --release` reports:

```text
Release app bundle failed to strip debug symbols from native libraries.
```

first confirm `android/app/build.gradle.kts` keeps release native symbol handling
enabled:

```kotlin
buildTypes {
    release {
        ndk {
            debugSymbolLevel = "SYMBOL_TABLE"
        }
    }
}
```

This lets Android Gradle strip native `.so` files from the delivered app bundle
while placing native symbol tables in AAB metadata for Play/native crash
symbolication. Do not add `--extra-gen-snapshot-options=--strip` to the AAB
command; that can remove Dart AOT debug metadata before Flutter verifies the
bundle.

Then check the Android toolchain:

```bash
flutter doctor -v
```

The Android section must show command-line tools installed and all Android
licenses accepted. If doctor reports `cmdline-tools component is missing` or
`Android license status unknown`, install the SDK Command-line Tools from
Android Studio:

1. Open Android Studio.
2. Open `Settings` -> `Languages & Frameworks` -> `Android SDK`.
3. Open `SDK Tools`.
4. Enable `Android SDK Command-line Tools (latest)`.
5. Ensure `NDK (Side by side)` is installed.
6. Apply changes.

Then accept licenses:

```bash
flutter doctor --android-licenses
flutter doctor -v
```

For command-line-only setup, install the current command-line tools ZIP from
Google into:

```text
~/Library/Android/sdk/cmdline-tools/latest
```

Then run:

```bash
~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager --licenses
flutter doctor -v
```

If the strip failure persists, verify the NDK strip tool exists:

```bash
find ~/Library/Android/sdk/ndk -name llvm-strip
```

Reinstall `NDK (Side by side)` from Android Studio if no `llvm-strip` binary is
found.

### Release Builds

Before building:

1. Confirm the release version in `pubspec.yaml`:

```yaml
version: 0.1.0+1
```

The part before `+` is the user-visible version name. The number after `+`
is the Android version code and must increase for every Play Console upload.

2. Confirm release signing is configured:

```bash
test -f android/key.properties
test -f /Users/<you>/nija-release.jks
```

The file must contain:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=nija-release
storeFile=/Users/<you>/nija-release.jks
```

3. Run the release gate:

```bash
./scripts/release_hardening_gate.sh
```

Build the signed Android App Bundle for Play Console. Use this default command
when Google Drive backup/restore already works with the registered Android OAuth
client SHA-1:

```bash
flutter clean
flutter pub get
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols/android
```

If native Google Sign-In needs an explicit server client id, pass the Web OAuth
client id from the same Google Cloud project:

```bash
flutter build appbundle --release \
  --dart-define=NIJA_GOOGLE_NATIVE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com \
  --obfuscate \
  --split-debug-info=build/symbols/android
```

Expected signed AAB output:

```text
build/app/outputs/bundle/release/app-release.aab
```

Verify the AAB exists:

```bash
ls -lh build/app/outputs/bundle/release/app-release.aab
```

Optional local release APK for device smoke testing:

APK:

```bash
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/symbols/android
```

APK with explicit native Google Sign-In server client id:

```bash
flutter build apk --release \
  --dart-define=NIJA_GOOGLE_NATIVE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com \
  --obfuscate \
  --split-debug-info=build/symbols/android
```

App Bundle:

```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols/android
```

The Android release Gradle config also generates native symbol tables for AAB
metadata. Archive `build/symbols/android` privately for Dart crash
symbolication. Do not publish Dart symbol maps.

Build outputs:

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

After building:

1. Archive `build/symbols/android` privately with the release version and build
   number.
2. Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console
   internal testing first.
3. If Play App Signing is enabled, copy the Play signing SHA-1 into the Google
   Cloud Android OAuth client before validating Drive backup.
4. Install or distribute the same signed build for final real-device validation.

### Deploy / Release Options

You cannot install an `.aab` directly on a device. Use Play Console internal
testing for the real release path, or build/install a release APK for a quick
local smoke test.

- Local device install from release APK:

Build the APK:

```bash
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/symbols/android
```

Install the APK:

```bash
flutter devices
flutter install -d <android-device-id> --use-application-binary build/app/outputs/flutter-apk/app-release.apk
```

- Play Console internal testing:
  1. Build the release AAB.
  2. Upload `build/app/outputs/bundle/release/app-release.aab`.
  3. Select internal testing track.
  4. Add tester emails or Google Groups.
  5. Roll out to internal testers.
  6. Verify Google Drive backup with the Play signing SHA-1 if Play App Signing is enabled.

- Local AAB validation with bundletool:

Use this when you want to validate the exact `.aab` locally without waiting for
Play Console delivery. Install `bundletool` first if it is not already available.

```bash
bundletool build-apks \
  --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=build/app/outputs/bundle/release/nija.apks \
  --ks=/Users/<you>/nija-release.jks \
  --ks-key-alias=nija-release
```

Then install to the connected device:

```bash
bundletool install-apks \
  --apks=build/app/outputs/bundle/release/nija.apks
```

If the device is not detected, reconnect USB, approve the device debugging
prompt, and check:

```bash
adb devices
```

- Real-device validation checklist:
  1. Create a vault.
  2. Unlock with the master password.
  3. Set and change the app PIN.
  4. Validate biometric unlock/gate where available.
  5. Lock, background the app, return, and unlock again.
  6. Recover with phrase and reset the master password.
  7. Add, edit, search, favorite, and delete vault items.
  8. Create, edit, share, and delete notes.
  9. Import, preview, save, and export documents.
  10. Import/export encrypted vault data.
  11. Purchase/restore expanded storage from Settings -> Storage when using a Play test install.
  12. Backup and restore if the paid/cloud build is enabled.
  13. Restart the app and verify encrypted vault persistence.

### Android Google Play Billing Setup

Nija uses Google Play Billing for the Android expanded-storage entitlement.

Product:

```text
nija_expanded_vault_lifetime
```

Entitlement behavior:

- free/default vault limit: 100 MB,
- Google Play product owned: 1 GB,
- entitlement is restored from Play on app start/session refresh,
- last verified purchased entitlement is cached in app-local secure storage for offline starts,
- pending purchases do not unlock storage,
- successful purchased/restored transactions are completed/acknowledged through the Billing plugin.

Play Console setup:

1. Confirm the app package is `com.nija`.
2. Upload at least one signed AAB to an internal, closed, or production track. Play Billing products are not fully testable from a purely sideloaded APK.
3. Open Play Console -> Monetize with Play -> Products -> In-app products.
4. Create a managed in-app product with product id:

```text
nija_expanded_vault_lifetime
```

5. Product type: one-time/non-consumable managed product.
6. Add name/description, for example:
   - name: `Expanded Vault Storage`
   - description: `Unlock up to 1 GB vault storage on Android.`
7. Set price and tax/distribution settings.
8. Activate the product.
9. Add license testers in Play Console -> Setup -> License testing.
10. Add the tester accounts to the internal/closed test track.
11. Install Nija from the Play testing link with the same tester Google account.
12. Open Nija -> Settings -> Storage -> Upgrade storage.
13. Complete the test purchase.
14. Confirm Settings -> Storage shows the 1 GB limit and Google Play entitlement source.
15. Restart the app offline and confirm the 1 GB limit remains available from the cached entitlement.
16. Reinstall from Play with the same Google account and use Restore purchase to confirm the entitlement is restored.

What is needed before validation:

- Play Console app access for `com.nija`,
- Play payments/merchant setup completed,
- an uploaded signed AAB on an internal or closed testing track,
- product `nija_expanded_vault_lifetime` activated,
- at least one license tester Google account,
- tester installed app from Play, not only `adb install`.

Notes:

- Local debug/sideload builds can compile the Billing code, but real purchase and restore validation should use a Play-installed test build.
- Without a backend, Google Play is the online source of truth and the app-local cache is an offline convenience. Do not store entitlement state inside a vault file.
- Android cloud backup uses the same expanded-storage entitlement. Do not add `NIJA_PAID_BUILD=true` to normal Play release builds.

- Production Play Store release:
  1. Complete store listing, privacy policy, data safety, content rating, and app access forms.
  2. Confirm release signing and OAuth SHA-1 values.
  3. Run release hardening gates and real-device validation.
  4. Promote from internal/closed testing to production.
  5. Keep release notes, AAB, mapping/symbol artifacts, and validation evidence archived.

### Android Hardening Checklist

- Production release signing configured.
- Google Drive OAuth client includes the production signing SHA-1.
- No debug signing in production release.
- R8/ProGuard/resource shrinking reviewed before final release.
- Obfuscation and split debug info used for release artifacts.
- `debugShowCheckedModeBanner` disabled.
- No secret-bearing logs.
- `.nijas` open-with and text share-intent flows validated.
- Biometrics, lock/background, backup/restore, document preview, and import/export validated on real devices.

## 5) iOS Operations

### Apple Developer Setup

Configure the App ID / Bundle ID for the Runner app:

- iCloud capability,
- iCloud Documents service,
- iCloud container,
- Associated Domains later if WebApp/native handoff is added,
- App Groups only if needed for future share extension or shared storage.

The current iCloud backup code calls `FileManager.default.url(forUbiquityContainerIdentifier: nil)`, so the first configured ubiquity container is used.

### iCloud Backup Path

iOS backup writes:

```text
Documents/vaults/<vaultId>/latest.nija
Documents/vaults/<vaultId>/<timestamp>_<suggestedName>
```

If iCloud Drive or the ubiquity container is unavailable, backup returns `false` and the app should show a user-safe failure message.

### Xcode Setup

1. Open `ios/Runner.xcworkspace`.
2. Select the Runner target.
3. Enable iCloud capability.
4. Select the same iCloud container attached in the Apple Developer portal.
5. Verify entitlements contain the iCloud container/service keys.
6. Build on a signed physical device with iCloud Drive enabled.

### Run Locally

```bash
flutter pub get
flutter run -d ios
```

Paid build run example:

```bash
flutter run -d ios --dart-define=NIJA_PAID_BUILD=true
```

Useful local commands:

```bash
flutter devices
flutter run -d <ios-device-id>
open ios/Runner.xcworkspace
```

For iCloud backup testing, run on a signed physical device with iCloud Drive enabled. Simulator iCloud behavior is not a substitute for release validation.

### Release Build

```bash
flutter build ipa --release \
  --dart-define=NIJA_PAID_BUILD=true \
  --obfuscate \
  --split-debug-info=build/symbols/ios
```

Archive `build/symbols/ios` privately.

Build output:

```text
build/ios/ipa/*.ipa
```

### Deploy / Release Options

- Local Xcode/device validation:
  1. Open `ios/Runner.xcworkspace`.
  2. Select Runner target and signing team.
  3. Run on a physical device.
  4. Validate create/unlock/backup/restore/lock flows.

- TestFlight:
  1. Build the release IPA.
  2. Upload through Xcode Organizer, Transporter, or CI.
  3. Add internal/external testers in App Store Connect.
  4. Verify iCloud backup with the same signed build testers receive.

- App Store release:
  1. Complete App Store metadata, privacy nutrition labels, screenshots, support URL, and age rating.
  2. Confirm iCloud entitlements and provisioning profiles.
  3. Run release hardening gates and real-device validation.
  4. Submit the validated build for review.
  5. Archive IPA, symbols, release notes, and validation evidence.

### iOS Hardening Checklist

- App Store signing/provisioning profiles are current.
- iCloud container works on a physical signed device.
- iCloud backup and restore work with airplane-mode/offline failure paths.
- Share extension is still pending for true iOS share-sheet text ingestion.
- Lock/background/app-switcher behavior verified.
- Obfuscation and private symbol archival used for release.

## 6) WebApp Operations

### Current Web Position

The web app should feel close to native on iOS and Android browsers, but production WebApp release still needs explicit readiness work.

Security assumptions:

- browser storage must only hold encrypted vault data and non-secret preferences,
- service worker/cache must never cache decrypted payloads,
- plaintext secrets must not appear in URLs, logs, history, analytics, or crash payloads.
- until runtime paid entitlement exists, web storage limits are client-enforced:
  new/small vaults are capped at 100 MB, while existing encrypted vaults already above 100 MB can continue up to 1 GB.
  This is product behavior, not an anti-tamper licensing control; durable paid enforcement requires a server-side entitlement or signed receipt.

### Run Locally

Debug browser run:

```bash
flutter pub get
flutter run -d chrome
```

Run paid web mode locally:

```bash
flutter run -d chrome --dart-define=NIJA_PAID_BUILD=true
```

Run paid web mode on a fixed OAuth origin:

```bash
flutter run -d chrome \
  --web-port 5173 \
  --dart-define=NIJA_PAID_BUILD=true \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

Add `http://localhost:5173` to the Web OAuth client's Authorized JavaScript origins before testing Google Drive backup locally.

Run against a specific browser/device when available:

```bash
flutter devices
flutter run -d <web-device-id>
```

### Web Release Build

```bash
flutter pub get
flutter build web --release
```

Paid WebApp release build with Google Drive configuration:

```bash
flutter build web --release \
  --dart-define=NIJA_PAID_BUILD=true \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

Output:

```text
build/web
```

Serve `build/web` from HTTPS only. Validate with a local static server before deployment:

```bash
cd build/web
python3 -m http.server 8000
```

Open:

```text
http://localhost:8000
```

For mobile device testing on the same network, serve from the host machine and open the host LAN IP from iOS/Android. For installability and service-worker validation, use HTTPS or a supported local development origin.

### Deploy / Release Options

- Static hosting:
  1. Build with `flutter build web --release`.
  2. Upload the full `build/web` directory to the host.
  3. Serve over HTTPS.
  4. Configure SPA fallback to `index.html`.
  5. Set cache headers carefully:
     - long cache for hashed Flutter assets,
     - short/no-cache for `index.html`, `flutter_bootstrap.js`, manifest, and service-worker files.
  6. Apply the production security headers from `web/_headers` or translate the same policy to the host/CDN.
  7. Validate online load, offline reload, install/add-to-home-screen, and vault persistence.

- Firebase Hosting:
  1. Configure hosting with public directory `build/web`.
  2. Build the app.
  3. Use the checked-in `firebase.json` headers, cache controls, and SPA rewrite.
  4. Confirm the privacy policy is reachable at `/privacy.html`.
  5. Deploy with Firebase CLI.

```bash
flutter build web --release
firebase deploy --only hosting
```

- Any CDN/object storage host:
  1. Upload `build/web`.
  2. Enable HTTPS.
  3. Configure security headers equivalent to `web/_headers`.
  4. Configure fallback routing to `index.html`.
  5. Confirm the privacy policy is served directly at `/privacy.html` and is not rewritten to the Flutter app shell.
  6. Purge CDN cache after release.

### Web Security Headers

The production web build includes two deployable header configurations:

- `web/_headers` for hosts that copy Flutter web assets directly, including Netlify and Cloudflare Pages style deployments.
- `firebase.json` for Firebase Hosting, using `build/web` as the public directory.

Required production headers:

```text
Content-Security-Policy: default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' https://www.gstatic.com https://accounts.google.com https://apis.google.com; connect-src 'self' https://www.gstatic.com https://fonts.gstatic.com https://www.googleapis.com https://oauth2.googleapis.com https://accounts.google.com https://www.google.com wss: blob:; img-src 'self' data: blob: https://*.googleusercontent.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' data: https://fonts.gstatic.com; frame-src https://accounts.google.com; worker-src 'self' blob: https://www.gstatic.com; manifest-src 'self'
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: accelerometer=(), autoplay=(), bluetooth=(), camera=(), clipboard-read=(), display-capture=(), encrypted-media=(), fullscreen=(self), geolocation=(), gyroscope=(), hid=(), idle-detection=(), magnetometer=(), microphone=(), midi=(), payment=(), publickey-credentials-get=(self), screen-wake-lock=(), serial=(), usb=(), xr-spatial-tracking=()
Cross-Origin-Opener-Policy: same-origin-allow-popups
Cross-Origin-Resource-Policy: same-origin
```

Policy notes:

- Flutter web currently requires inline/eval/WebAssembly allowances for its bootstrap/runtime. Keep these allowances scoped to the app origin and Google origins needed for Identity/Drive.
- Keep `Cross-Origin-Opener-Policy` at `same-origin-allow-popups` so Google OAuth popup flows continue to work.
- Do not enable `Cross-Origin-Embedder-Policy` until Google sign-in, fonts, CanvasKit, service-worker behavior, and OAuth popups are validated with that isolation mode.
- Keep HSTS only on HTTPS production domains. Do not preload a domain until all subdomains are HTTPS-ready.
- Mirror header changes in both `web/_headers` and `firebase.json`.

### Web Google Drive Backup Setup

Current implementation note: web currently falls back to encrypted backup download and reports the backup account as `Browser download`. The following setup is required before implementing and validating real browser-based Google Drive backup.

Google Cloud setup:

1. Use the Nija Google Cloud project.
2. Enable `Google Drive API`.
3. Configure Google Auth Platform branding:
   - app name: `Nija`,
   - support email,
   - developer contact email,
   - privacy policy URL before production.
4. Keep OAuth app in Testing mode while validating; add tester Google accounts under Audience.
5. Add Drive scope `https://www.googleapis.com/auth/drive.file`.
6. Create OAuth client type `Web application`.
7. Add local and production Authorized JavaScript origins.
8. Copy the Web client id into deployment configuration as `GOOGLE_WEB_CLIENT_ID`.

Implementation expectations for Web Google Drive backup:

- Authenticate with Google Identity Services in the browser.
- Request `drive.file` only when the user starts backup/restore or connects Drive.
- Upload only encrypted `.nija` backup bytes.
- Store only non-secret metadata in Drive, such as vault id, version id, revision, and updated timestamp.
- Use Drive app/file properties to find backups by `vaultId`, similar to Android's `appProperties.nijaVaultId=<vaultId>` behavior.
- Keep access tokens in memory where possible. If token persistence is added, document storage, expiry, revocation, and sign-out behavior.
- Do not place tokens, vault ids, filenames, passwords, recovery phrases, or decrypted content in URLs.
- Restore must list/read only Nija-created backup files allowed by the selected Drive scope.

Validation after Web Google Drive backup is implemented:

1. Run locally on the fixed OAuth origin:

```bash
flutter run -d chrome \
  --web-port 5173 \
  --dart-define=NIJA_PAID_BUILD=true \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

2. Create and unlock a vault.
3. Add at least one item.
4. Open Settings -> Cloud Backup.
5. Enable cloud backup.
6. Confirm Google account connection uses the expected tester account.
7. Click `Backup now`.
8. Confirm success message and backed-up version metadata.
9. Inspect Google Drive:
   - backup file exists,
   - file content is encrypted `.nija` data,
   - no plaintext item values appear in file name, description, app properties, or custom properties.
10. Lock, reload the browser, unlock, and click Restore.
11. Confirm restore downloads the matching backup for the same `vaultId`.
12. Test wrong-account/no-backup path: expected user-safe `No cloud backup found` or equivalent message.
13. Test offline path: backup/restore controls should fail gracefully without exposing raw API errors.

Until that implementation exists, validate the current WebApp behavior instead:

1. Run paid web mode.
2. Enable cloud backup in Settings.
3. Confirm account label is `Browser download`.
4. Click `Backup now`.
5. Confirm the browser downloads an encrypted `.nija` backup.
6. Click Restore.
7. Confirm the expected `No cloud backup found` behavior.

### Web Hardening and PWA Checks

- Verify `manifest.json`, app icons, theme color, and viewport behavior.
- Validate add-to-home-screen on iOS Safari and Android Chrome.
- Validate offline startup after first successful load.
- Validate create/unlock/lock/reopen while offline.
- Confirm IndexedDB/local storage contains only encrypted vault data and non-secret preferences.
- Confirm service-worker/cache entries do not include decrypted vault contents, master passwords, recovery phrases, raw secret exports, or decrypted documents.
- Deploy with HTTPS and security headers:
  - `Content-Security-Policy`,
  - `Strict-Transport-Security`,
  - `X-Content-Type-Options: nosniff`,
  - `Referrer-Policy`,
  - `Permissions-Policy`.
- If Google Identity Services is enabled, include required Google origins in CSP for scripts, frames, and network connections.
- If Google OAuth popups are used, validate `Cross-Origin-Opener-Policy` supports the popup flow, typically `same-origin-allow-popups` where required.
- Disable production debug internals and development flags.

### Web Obfuscation Note

Flutter web release builds are minified and tree-shaken. Flutter's native `--obfuscate` flow does not apply to web builds. Do not rely on client-side minification for trust decisions.

## 7) Paid Build and Entitlements

Current state:

- Android cloud backup and expanded storage are controlled by Google Play Billing product `nija_expanded_vault_lifetime`.
- Free builds show paid backup controls disabled.
- Play entitlements are cached locally for offline starts.

Release target:

- Add Play Billing non-consumable product `nija_expanded_vault_lifetime`.
- On app start, load locally cached entitlement and reconcile with Play Billing state.
- Default to free features until a trusted entitlement is loaded.
- Store entitlement state in app-local storage, not inside any vault.
- Keep development build flags only as overrides, not production source of truth.

## 8) Common Local Validation

Run these before platform-specific release work:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Run targeted integration checks as needed:

```bash
flutter test integration_test
```

For web integration tests that require ChromeDriver:

```bash
chromedriver --port=4444
flutter drive -d chrome --driver=test_driver/integration_test.dart --target=integration_test/app_smoke_test.dart
flutter drive -d chrome --driver=test_driver/integration_test.dart --target=integration_test/e2e_full_flow_test.dart
```

## 9) Important Flutter Commands

### Environment and Dependencies

```bash
flutter doctor -v
flutter --version
flutter devices
flutter pub get
flutter pub outdated
flutter pub upgrade
```

Use `flutter pub upgrade` deliberately and review `pubspec.lock` changes before release.

### Formatting, Analysis, and Tests

```bash
dart format .
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test test/vault_shell_test.dart
flutter test integration_test
```

### Local Runs

```bash
flutter run
flutter run -d chrome
flutter run -d android
flutter run -d ios
flutter run -d <device-id>
flutter run --release -d <device-id>
flutter run --profile -d <device-id>
```

Paid/development override:

```bash
flutter run -d <device-id> --dart-define=NIJA_PAID_BUILD=true
```

### Build Commands

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ipa --release
flutter build web --release
```

Release hardening builds:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols/android
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/android
flutter build ipa --release --obfuscate --split-debug-info=build/symbols/ios
```

Development override examples:

```bash
flutter build appbundle --release \
  --dart-define=NIJA_PAID_BUILD=true \
  --obfuscate \
  --split-debug-info=build/symbols/android

flutter build ipa --release \
  --dart-define=NIJA_PAID_BUILD=true \
  --obfuscate \
  --split-debug-info=build/symbols/ios

flutter build web --release \
  --dart-define=NIJA_PAID_BUILD=true
```

### Install and Clean

```bash
flutter install -d <device-id>
flutter clean
flutter pub get
```

Use `flutter clean` when generated platform artifacts or dependency state become inconsistent. Always run `flutter pub get` afterward.

### Icons and Assets

```bash
flutter pub run flutter_launcher_icons
```

Run this after changing `assets/branding/nija_mark.png` or launcher icon config in `pubspec.yaml`.

### Debugging and Diagnostics

```bash
flutter logs -d <device-id>
flutter attach -d <device-id>
flutter symbolize -i <stack-trace-file> -d <symbols-file>
```

Keep obfuscation symbols private. They are required to decode release stack traces.

### Web Release Smoke Run

```bash
flutter build web --release
cd build/web
python3 -m http.server 8000
```

Open `http://localhost:8000`, then validate create/unlock/reload/offline behavior.

## 10) Security Review

Before any production tag:

```bash
./scripts/release_hardening_gate.sh
flutter analyze
flutter test
```

Run platform builds:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols/android
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/android
flutter build ipa --release --obfuscate --split-debug-info=build/symbols/ios
flutter build web --release
```

Release gate reference: `docs/release_hardening_gates.md`.

Security signoff must verify:

- recovery phrase is never logged and reset flow works,
- password/recovery rotation works,
- wrong unlock failures are safe,
- migration rejects unsupported future versions,
- sensitive inputs clear on lock/background,
- crash/error messages do not expose payload/key material,
- web storage and service worker cache contain no plaintext secrets,
- client bundles contain no secrets, debug endpoints, entitlement bypasses, or sensitive constants.

## 11) Manual Validation Matrix

Run on real devices where applicable:

- Android: create vault -> unlock -> lock -> unlock -> recovery unlock -> reset password.
- iOS: create vault -> unlock -> lock -> unlock -> recovery unlock -> reset password.
- Web: create vault -> unlock -> lock -> unlock -> recovery unlock -> reset password.
- Android/iOS/Web: master-password rotation.
- Android/iOS/Web: recovery phrase rotation.
- Android/iOS/Web: CRUD persistence after app restart.
- Android/iOS: import/export `.nija`.
- Android: `.nijas` open-with and text share-to-note.
- iOS: iCloud backup/restore.
- Android: Google Drive backup/restore.
- Web: current encrypted backup download fallback.
- Web after provider implementation: Google Drive backup/restore using the Web OAuth client and `drive.file` scope.
- Web installed on iOS/Android: offline restart -> unlock -> CRUD persistence.
- Document/PDF preview: focus/scroll/pan/zoom/fullscreen.

## 12) Incident and Recovery Notes

- If a release signing key is lost, follow Play App Signing recovery process if enabled; otherwise app updates may be blocked.
- If OAuth SHA is wrong, backup sign-in may fail until the correct SHA is added and propagated.
- If a cloud backup is corrupt or stale, the local `.nija` vault remains the source of truth.
- If a user loses both master password and recovery phrase, Nija cannot recover the vault.
- If a build accidentally includes debug internals, do not promote it. Rebuild from a clean release configuration and rotate any exposed non-public operational data.

## 13) Useful References

- Flutter web release: https://docs.flutter.dev/deployment/web
- Flutter obfuscation: https://docs.flutter.dev/deployment/obfuscate
- Google Workspace credentials: https://developers.google.com/workspace/guides/create-credentials
- Google Identity Services Web setup: https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid
- Google Drive JavaScript quickstart: https://developers.google.com/workspace/drive/api/quickstart/js
- Google Drive scopes: https://developers.google.com/workspace/drive/api/guides/api-specific-auth
- Google Drive file search and `appProperties`: https://developers.google.com/workspace/drive/api/guides/search-files
- Google Drive custom file properties: https://developers.google.com/workspace/drive/api/guides/properties
- Apple iCloud entitlements: https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingiCloud.html
- Apple iCloud services: https://developer.apple.com/documentation/Xcode/configuring-icloud-services
