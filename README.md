# nija

Nija is a local-first, privacy-first vault application built with Flutter.

## Tech stack and frameworks

- Framework: Flutter (Material 3 UI)
- Language: Dart
- Rich text editor: `flutter_quill`
- Cryptography: `cryptography` package
- Localization: Flutter localization delegates + app-level string dictionary (`en`, `es`)
- Testing: `flutter_test` (unit + widget tests)
- Launcher icons: `flutter_launcher_icons`
- Web production headers: `web/_headers` for static hosts and `firebase.json` for Firebase Hosting
- Web privacy policy: `web/privacy.html` is served directly at `/privacy.html`

## Architecture

- `lib/app`: app bootstrap, theme, and app-level localization mode handling
- `lib/features`: onboarding and vault feature UI
- `lib/domain`: core models and validators
- `lib/application/services`: vault business logic (`VaultService`, `DefaultVaultService`)
- `lib/infrastructure/adapters`: storage and crypto adapters

The app follows a layered approach:
- UI (`features`) calls service layer (`application`)
- Service layer uses adapters (`infrastructure`) for storage/crypto
- Domain models (`domain`) define vault file/data contracts

## Current capabilities

- Onboarding flow: welcome, guardian setup, recovery phrase, vault created, unlock
- Long-running security operations now show an in-app progress overlay with step text and animated progress bar (create vault, unlock, recovery unlock).
- Recovery phrase:
  - generated from internal dictionary (12 words),
  - shown in onboarding,
  - used in service-level recovery unlock,
  - seeded into a default recovery note
- Vault persistence:
  - writes local vault file (`nija_vault.nija`) through `VaultService`
  - supports unlock by master password
  - supports unlock by recovery phrase
  - supports immediate password reset after recovery unlock (before normal session access)
  - supports key rotation workflows from Settings:
    - rotate master-password wrapper
    - rotate recovery-phrase wrapper
  - web runtime uses durable browser private app storage through `WebVaultStorageAdapter`; vault bytes and source metadata are not stored in HTTP cookies
  - non-web targets use file-based persistence (`FileVaultStorageAdapter`)
  - new/small free vaults are capped at 100 MB; existing vaults already above 100 MB are treated as legacy vaults and can continue up to 1 GB
  - cross-platform vault import/export:
    - import encrypted vault from local file/upload,
    - export current encrypted vault to local storage with user-selected file name,
    - cached known-vault references (via app preferences) for quick reopen from `Open existing vault`, including non-sensitive source hints such as browser private storage and selected file name
  - lock/background transitions clear in-memory master-password input before returning to unlock
- Notes:
  - rich text create/edit/view via `flutter_quill`
  - formatting options include headings, lists, quote, links, code, font size, color, alignment
  - note editor now keeps title/tags and formatting panels collapsed by default to maximize writable area
  - note editor shows a dedicated second-row controls strip (`Title & tags`, `Formatting`) below the app bar, available even while keyboard is open
  - note editor now autosaves every second (`noteAutosaveInterval` in code) and saves automatically when user navigates back
  - Gmail-style multi-select mode for notes (enter via left avatar tap, selected-count top bar with pin/delete)
  - Notes info card removed; inline info icon near Notes title opens a compact info dialog
  - long-press note actions for pin/unpin and delete
  - long-press note actions now include:
    - `Share plain text` (clipboard-ready text)
    - `Share encrypted file` (password-protected `.nijas` file)
    - `Export encrypted file` (password-protected `.nijas` saved to local filesystem)
  - notes list supports:
    - sort by `Last accessed`, `Title`, `Tags`
    - filter by tags
    - pin filter chips: `All`, `Pinned`, `Unpinned`
  - delete action available directly from note view (next to edit)
- Vault UI:
  - item list, type list, custom type definitions, secure notes list
  - active vault name is visible in Vault tab header and in Settings
  - long-press item actions for pin/unpin and delete
  - long-press item actions now include encrypted sharing (`.nijas`) with a user-entered share password
  - long-press item actions now include local encrypted export (`.nijas`) to filesystem
  - item detail now supports edit and delete actions in the app bar
  - item detail uses a constrained desktop/tablet layout with a main content panel, side metadata panel, filtered non-empty fields, and type-aware primary quick actions
  - document previews include an enlarge/fullscreen action for standalone documents and item attachments
  - Gmail-style multi-select mode for vault items (enter via left icon tap, selected-count top bar with pin/delete)
  - list rows now show `Last accessed: ...` metadata for both vault items and notes
  - key list supports:
    - sort by `Last accessed`, `Title`
    - filter by key type
    - pin filter chips: `All`, `Pinned`, `Unpinned`
  - key items support tags:
    - add/edit tags in item form (`Tags (comma separated)`)
    - tag chips shown in key list rows
    - search also matches key tags
- Localization:
  - English and Spanish
  - manual selector in `Settings -> Language` (`System default`, `English`, `Español`)
- Settings menu now omits `Vault Backup`, `Recovery Phrase`, and `Danger Zone` entries.
- Settings includes `Import encrypted secret` to import `.nijas` files into Vault/Notes.
- Settings includes default sort selectors for both keys and notes (`Last accessed` or `Title`), persisted locally.
- Settings includes a Storage section showing vault usage, the active vault limit, Google Play entitlement status, purchase restore, and Android expanded-storage upgrade.
- Settings includes a paid-gated cloud-backup toggle:
  - Android label: `Backup to Google Drive`
  - iOS label: `Backup to iCloud`
  - Android is controlled by the Google Play expanded-storage entitlement; `NIJA_PAID_BUILD` remains a development override
  - disabled without entitlement with hint text `Available in paid version`
  - when enabled, `Backup now` performs direct cloud upload:
    - Android: OAuth sign-in + Google Drive API upload (no share sheet)
    - iOS: iCloud ubiquity container write (no share sheet)
  - each backup is keyed by `vaultId` (stored in vault metadata) so the same vault from different devices can update the same cloud object lineage
  - includes in-app backup center controls:
    - last backup timestamp
    - auto backup toggle (while app is active)
    - frequency selection (`Daily`, `Weekly`, `Monthly`)
    - `Restore backup` action from the same section
- App PIN can be set or changed from Settings -> Security and provides local quick unlock when biometrics are unavailable.
- Biometric enable/disable in Settings uses a slider switch control with confirmation dialogs for both enable and disable.
  - On web, biometric/device unlock uses secure WebAuthn PRF quick unlock after a successful master-password login. PIN setup is required first; PRF wraps the PIN, and the PIN unlocks the encrypted local helper. Browsers or devices without secure PRF support keep biometrics disabled and use PIN or master-password unlock.
- Android expanded vault storage uses Google Play Billing with product id `nija_expanded_vault_lifetime`; verified purchases are cached locally for offline starts and unlock the 1 GB vault limit.
- Encrypted secret sharing:
  - app-specific portable secret file extension: `.nijas`
  - content uses JSON envelope with PBKDF2-HMAC-SHA256 key derivation + AES-256-GCM payload encryption
  - sender chooses both file name and per-file share password at share time
  - Android/iOS app metadata now registers `.nijas` document type association for open-with flows
- Unlock flow enhancements:
  - Wide WebApp first page and unlock now use the same Nija app-themed onboarding surfaces as mobile, scaled for tablet/web.
  - Wide WebApp/tablet vault screens use a narrow brand/status rail plus a separate vault navigation sidebar and constrained content frame while mobile keeps bottom navigation.
  - Wide WebApp/tablet vault picker opens as a centered dialog; mobile keeps the bottom sheet picker.
  - Wide WebApp/tablet add-item saved confirmation opens as a centered constrained dialog; mobile keeps the bottom sheet confirmation.
  - Wide WebApp/tablet New Item category selection is bounded to a readable column instead of stretching rows across the full browser width.
  - First-page `Import data` imports a vault instead of opening create-vault onboarding, and successful imported-vault password entry opens the vault directly.
  - Wide dashboard uses compact wrapping category tiles plus a recent/quick-actions split layout so all folders/types remain visible without stretched empty cards.
  - Web/tablet dashboard now uses a wireframe-aligned homepage with a constrained search row, six stat cards, recent items, quick actions, and an optional homepage-only demo preview CTA for new empty vaults.
  - Home dashboard search now opens All Items with stale category/filter state cleared, and All Items search matches titles, subtitles, item type, folder, tags, note text, and field values.
  - Mobile remains the source experience below `760px` and in short landscape windows; tablet/web adds the bounded rail/sidebar workspace only when there is sufficient vertical room.
  - Tablet/web All Items uses a bounded index with type, folder, and modified columns, while mobile retains compact rows and horizontal filters.
  - Dashboard category tiles render only saved categories; folders remain inferred item metadata until a dedicated folder-management flow is introduced.
  - Web install metadata now uses the Nija name, description, icon set, and app theme color rather than Flutter defaults.
  - The first entry screen now uses one responsive, mobile-first Nija vault flow at every breakpoint: select a known vault, open a vault file, create a vault, import data, or restore from supported cloud storage. Selecting, switching, or locking a vault opens the same compact full-page local-reference list from the web flow reference, then advances directly to one unlock step; `Select different vault file` stays wired to the local import path.
  - Opening or importing a vault that is already known validates the entered password and enters the app directly instead of showing a second unlock screen.
  - Imported-vault password validation reuses the normal unlock UI and `Unlock` action; there is no separate `Unlock imported vault` step in the login flow.
  - `Create vault` is available directly from unlock screen.
  - `Open encrypted secret` on unlock screen decrypts `.nijas` with file password and opens a key-value viewer page.
  - encrypted secret viewer provides:
    - per-field copy
    - hide/show for sensitive values
    - `Copy full secret (visible)`
    - `Import to vault`
  - `Import to vault` uses a standardized protected-action login flow:
    - select vault from bottom sheet
    - unlock with master password or biometric
    - import into the selected vault
  - opening `.nijas` directly from Android file manager/app picker now forwards payload into Nija and launches the same decrypt/open flow.
- Multi-vault behavior:
  - vault picker sorting is based on `last opened` metadata (most recent first)
  - biometric enrollment/prompt is tracked per vault in app-local storage
  - web PIN quick unlock stores a per-vault encrypted unlock helper derived from the user PIN
  - web biometric quick unlock stores per-vault WebAuthn enrollment metadata, a PRF salt, and an encrypted PIN helper; the PRF wrapping key is recreated only after device verification and is not stored

## Security status

Implemented foundations:
- Vault file format includes:
  - KDF metadata
  - encrypted vault-key wrapper by password
  - encrypted vault-key wrapper by recovery phrase
  - encrypted payload blob
  - explicit migration/version strategy:
    - current vault file `formatVersion`: `1`
    - current payload `schemaVersion`: `1`
    - legacy `v0` metadata/payload is normalized to current shape during reads
    - future versions (`> current`) are rejected explicitly
- Service-level create/unlock/recovery unlock/reset/rotation paths are wired end-to-end

Current limitation:
- Active crypto now uses `SecureCryptoAdapter` with:
  - Argon2id key derivation
  - AES-256-GCM authenticated encryption
- Remaining work before release focuses on platform-specific secure memory/storage refinements and release hardening.

See: `docs/encryption_and_recovery.md`

## Storage and file model

- Vault file contract: `lib/domain/models/vault_file.dart`
- Storage adapters:
  - `FileVaultStorageAdapter` for local file persistence
  - `InMemoryVaultStorageAdapter` for tests
  - `VaultReferenceCache` for persisted known-vault location list

## Development and validation

Common commands:

```bash
flutter pub get
flutter analyze
flutter test
```

Web release build:

```bash
flutter build web --release --wasm -O4 --no-source-maps --csp
```

The web release uses Flutter WebAssembly output with hardened CSP-compatible
flags. Detailed deployment headers, OAuth origin setup, and hosting checks are
documented in `docs/ops_readme.md`.

Paid build run example:

```bash
flutter run --dart-define=NIJA_PAID_BUILD=true
```

## Cloud backup platform setup

The app supports direct third-party cloud providers:
- Android: Google Drive (OAuth + Drive API)
- iOS: iCloud Drive via app ubiquity container

### Android (Google Drive) setup

1. In Google Cloud Console, create/use one project for the app.
2. Enable `Google Drive API` in that same project.
3. Configure OAuth consent screen and add test users if the app is in Testing mode.
4. Create OAuth 2.0 `Android` client ID(s):
   - package name must match your app `applicationId`
   - add SHA-1 (and SHA-256 recommended) for each signing key you use (debug/release)
5. Get SHA values from:
```bash
cd android
./gradlew signingReport
```
Or from project root:
```bash
./android/gradlew -p android signingReport
```
   - Use SHA values from `:app:signingReport` only (ignore plugin/module sections).
   - For local development, use `Variant: debug` SHA-1.
   - For production/internal release signing, use the release keystore SHA-1.
6. Reinstall the app after OAuth changes.

Common Android error:
- `ApiException: 10` (`DEVELOPER_ERROR`) means OAuth client, package name, or SHA fingerprint mismatch.
- `DetailedApiRequestError(status: 403, ... Drive API has not been used ... or it is disabled)` means OAuth succeeded but `Google Drive API` is disabled in that project. Enable Drive API for the same project and retry after a few minutes.
- `google-services.json` must be placed at `android/app/google-services.json` (not under `lib/`).

### Android release signing key (how to get release SHA)

By default this project signs release with debug keys unless you configure a real release keystore.

1. Generate a release keystore:
```bash
keytool -genkeypair \
  -v \
  -keystore ~/nija-release.jks \
  -alias nija-release \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

2. Create `android/key.properties`:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=nija-release
storeFile=/Users/<you>/nija-release.jks
```

3. Update `android/app/build.gradle.kts` to load `key.properties` and set `buildTypes.release.signingConfig` to your release signing config instead of debug.

4. Verify release signing SHA:
```bash
cd android
./gradlew signingReport
```
Check `:app:signingReport -> Variant: release` and copy its `SHA1` into Google Cloud OAuth Android client settings.

### iOS (iCloud container) setup

1. In Apple Developer portal:
   - enable `iCloud` capability for the app identifier
   - enable iCloud Documents/CloudKit as needed
   - create/attach iCloud container(s)
2. In Xcode target capabilities:
   - enable `iCloud`
   - select the same iCloud container(s)
3. Ensure entitlements include iCloud container/service keys for the Runner target.
4. Build/run on a signed iOS device with iCloud Drive available.

Common iOS issue:
- If ubiquity container is unavailable, backup returns false and log includes `[VaultPortability][ICloudBackup] ...`.

### Current cloud scope

- Upload is vault-file level (`.nija` encrypted file).
- Android upload uses Drive file `appProperties.nijaVaultId=<vaultId>` to find/update existing backup.
- iOS writes to `Documents/vaults/<vaultId>/latest.nija` plus timestamped history copies.
- There is no cross-provider sync/merge layer (Drive and iCloud are independent targets).

Release hardening gate:

```bash
./scripts/release_hardening_gate.sh
```

Checklist reference:
- `docs/release_hardening_gates.md`

Security-focused automated test coverage includes:
- wrong master password unlock rejection
- wrong recovery phrase unlock rejection
- tampered format-version metadata rejection
- corrupted encrypted payload failure handling
- recovery + reset + key-rotation continuity flow

Web integration test (requires `chromedriver` running on `http://localhost:4444`):

Install ChromeDriver (macOS/Homebrew):

```bash
brew install --cask chromedriver
# if already installed:
brew upgrade --cask chromedriver
chromedriver --version
```

Start ChromeDriver server:

```bash
chromedriver --port=4444
```

Run Flutter web integration tests (in another terminal):

```bash
flutter drive -d chrome --driver=test_driver/integration_test.dart --target=integration_test/app_smoke_test.dart
flutter drive -d chrome --driver=test_driver/integration_test.dart --target=integration_test/e2e_full_flow_test.dart
```

## Product documentation

- Design rules: `docs/design.md`
- Architecture and wireframes: `docs/architecture_wireframe.md`
- Web prototype reference: `docs/web_prototype.tsx`
- Web revamp tracker: `docs/web-revampt-todo.md`
- Ops runbook: `docs/ops_readme.md`
- Encryption and recovery model: `docs/encryption_and_recovery.md`
- Security flow diagrams: `docs/security_flow_diagram.md`
- Screen and feature flow graph: `docs/screen_flow_graph.md`
- Development tracker: `docs/todo.md`
- Vault item type research: `docs/vault_item_types.md`

## Branding

- Source branding image: `nija.png`
- Launcher icon source: `assets/branding/nija_mark.png`
- Google Play listing icon: `assets/store/play_store_icon.png`
- Google Play feature graphic: `assets/store/play_feature_graphic.jpg`
