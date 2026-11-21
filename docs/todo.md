# Nija Development TODO (MVP)

This tracker converts the current `docs/` specs into an execution plan for a user-centric mobile app MVP.

## 1) Foundation Setup

- [x] Finalize app architecture modules: `ui`, `application`, `domain`, `infrastructure`.
- [x] Define domain models for `Vault`, `VaultItem`, `SecureNoteDocument`, `GuardianProfile`.
- [x] Create locale and configuration structure for strings, labels, guardian profiles, and static assets.
- [x] Add app-wide design tokens (spacing, radius, colors, typography) from `docs/design.md`.

## 2) Core Security & Vault Engine

- [x] Implement vault file schema (`.nija`) with header + encrypted payload.
- [x] Implement key derivation with guardian profile mapping (Owl/Lion/Falcon).
- [x] Implement vault create flow (generate vault key, wrap key, encrypt payload, save file).
- [x] Implement vault unlock flow (read header, derive key, decrypt vault key, decrypt payload).
- [x] Add security controls: no sensitive logs, secure memory handling boundaries, lock-on-background hooks.

## 3) Onboarding & Access Flows

- [x] Build Welcome screen: create vault / open existing vault.
- [x] Build Guardian selection + master password setup.
- [x] Build recovery phrase screen with offline-storage guidance.
- [x] Build unlock screen with master password.
- [x] Add biometric unlock placeholder flow (convenience only).

## 4) Vault Experience (User-Centric)

- [x] Build dashboard with quick overview and recent items.
- [x] Build vault item list + search.
- [x] Build item detail with masked sensitive fields and per-field reveal/copy.
- [x] Build add/edit flows for Login, Card, and Identity item types.
- [x] Add empty states and helpful microcopy for first-time users.

## 5) Notes & Documents

- [x] Build Notes tab as first-class section.
- [x] Implement structured block model (heading, paragraph, bullet, checklist, quote).
- [x] Build add/edit/view secure note flows.
- [x] Store notes as structured blocks (no raw HTML).

## 6) Settings, Backup, and Safety UX

- [x] Build Settings screen (vault info, guardian profile display, lock preferences).
- [x] Add backup/export placeholder flow.
- [x] Implement clipboard auto-clear behavior with user messaging.
- [x] Add screenshot/app-switcher protection where platform supports it.

## 7) Quality, Validation, and Release Readiness

- [x] Add unit tests for vault parsing, crypto flow boundaries, and domain validators.
- [x] Add widget/UI tests for onboarding, unlock, vault list, and notes flows.
- [x] Verify mobile-first layout (390px–430px), touch target minimum (44x44), and calm UX rules.
- [x] Run final MVP checklist against `docs/design.md` and `docs/architecture_wireframe.md`.

## 8) Suggested Build Order

1. Foundation Setup
2. Core Security & Vault Engine
3. Onboarding & Access Flows
4. Vault Experience
5. Notes & Documents
6. Settings/Backup/Safety
7. Validation & hardening

## 9) Production Hardening Backlog (Post-MVP, One-by-One)

Work these items strictly one at a time. Each item should be fully implemented, validated, and documented before starting the next.

- [x] Enforce password reset immediately after recovery unlock.
  - Recovery path should require setting a new master password before opening normal app session.
  - Re-wrap vault key with new password-derived key and persist updated file metadata.
- [x] Add key-rotation workflows.
  - Rotate master-password wrapper without re-encrypting full payload.
  - Rotate recovery-phrase wrapper and invalidate old recovery wrapper safely.
- [x] Persist encrypted CRUD updates for real vault data.
  - Ensure add/edit/delete for vault items and notes writes encrypted payload back to vault file.
  - Remove remaining in-memory-only state behavior for core vault entities.
- [x] Add durable web storage adapter.
  - Replace web in-memory fallback with persistent web storage strategy (IndexedDB/local-first).
  - Keep encryption and key-handling model consistent with non-web platforms.
- [x] Strengthen secure memory and lifecycle hygiene.
  - Minimize plaintext/key lifetime in memory.
  - Clear sensitive buffers/controllers on lock/background/logout paths where feasible.
- [x] Add explicit vault format migration/version strategy.
  - Support forward-compatible metadata evolution and safe migration routines.
  - Add migration tests for old/new file versions.
- [x] Expand security testing and failure-path coverage.
  - Wrong password / wrong recovery phrase behavior.
  - Corrupted ciphertext / tampered metadata handling.
  - Recovery + reset + rotation end-to-end tests.
  - Added integration abuse coverage for tampered document chunks, path-style document IDs, unconfirmed/wrong-credential imports, and debug-internals plaintext leakage.
- [x] Add release hardening gates.
  - Security review checklist.
  - Production configuration checks (logging, debug flags, crash surfaces).
  - Final pre-release validation pass across Android/iOS/Web.
- [x] Add multi-vault selection and import flow.
  - Added vault picker before unlock when user taps `Open existing vault`.
  - Added known-vault cache persisted in app storage.
  - Added vault import/add flow per platform (web upload, mobile/desktop file picker).
- [x] Add imported-vault recovery flow.
  - Current recovery flow only recovers the currently selected active vault.
  - When importing or selecting an existing vault, offer both `Open with password/PIN` and `Recover with phrase`.
  - `Recover with phrase` must use the selected/imported vault's recovery wrapper, not the previously active vault.
  - After successful recovery phrase unlock, require the user to set/change the vault password/PIN before opening the normal vault session.
  - Persist the new password/PIN wrapper for that recovered vault and refresh any per-vault biometric enrollment state.
  - Add wrong-phrase, cancelled recovery, imported-vault recovery, and active-vault-is-not-recovered regression tests.
  - Added `Recover with phrase` to imported-vault password prompts.
  - Imported-vault recovery now targets the staged imported vault handle, forces master password reset, imports/selects the recovered vault, and clears biometric enrollment for that vault.
  - Existing vault selection continues to expose `Recover with phrase` on the unlock screen, now with active-session recovery checks reset when switching vaults.
  - Added regression coverage proving a staged imported vault can reset with its own recovery phrase without mutating the previously active vault.
- [x] Add vault last-opened metadata and sorting in vault picker.
  - Vault references now persist `lastOpenedAt` and vault picker list is sorted by most recently opened first.
- [x] Add first-install onboarding walkthrough screens.
  - Show only on first install / first app open, before the normal create/open vault screen.
  - Add multiple pages that explain the Nija flow at a high level: create/open a vault, save recovery phrase, unlock with password/PIN/biometrics, add items/documents, backup/export safely, and recover if needed.
  - Include skip and continue controls, with progress indicators.
  - Persist completion in app-local storage, not inside any vault.
  - Ensure returning users, restored installs with completed onboarding, and test/dev resets behave predictably.
  - Add widget tests for first-run display, page navigation, skip/finish persistence, and non-display after completion.
  - Added a five-page first-run walkthrough with skip/continue/get-started actions and progress indicators.
  - Persisted completion in `SharedPreferences` under app-local storage.
  - Added widget coverage for first-run display, page navigation, skip/finish persistence, and hidden-after-completion behavior.
- [ ] Add web-only release/runtime integrity hardening for JS-capable web delivery.
  - Goal: allow a JS web build path for platforms where Flutter wasm is not viable, such as iOS PWA, while adding release-time integrity hygiene and distributed runtime checks.
  - Scope note: this is web client hardening, not unbreakable DRM. Browser-delivered code can still be patched by a determined attacker, so checks should raise work factor and catch accidental/untrusted artifact drift without becoming a core security boundary for vault encryption.
  - Progress: compat-js hardening, signed manifest generation, release-gate verification, app-start runtime verification, feature-level web wrappers, and compat-js runtime marker gate are implemented.
  - Phase 1: release-time integrity manifest.
    - Generate `manifest.json` containing hashes for important web build artifacts, selected assets, build id, app version, and verifier grouping metadata.
    - Sign the manifest digest with the Esya Kalpa release private key on the release machine/CI.
    - Bundle only the signed manifest, signature, and public verification key with the web artifact.
    - Keep private signing keys out of the repo and out of shipped app assets.
  - Phase 2: hardening gate verifies before upload.
    - Extend the web release hardening gate to verify manifest signature, manifest freshness, expected artifact hashes, and absence/presence rules for the selected web flavor before deploy.
    - Support both hardened wasm-only output and the future JS-capable web output needed for iOS PWA compatibility.
    - Fail release validation on unsigned manifests, stale manifest build ids, source maps in release output, unexpected artifact drift, or missing required runtime files.
  - Phase 3: runtime verification, added carefully.
    - Added generated differently-shaped wrapper functions for startup, unlock, vault-reference, capacity, transfer, and settings groups.
    - App start verifies the signed manifest plus the startup group.
    - Vault unlock hash-checks the `unlock` group against the manifest.
    - Create/open additional vault checks the `vault_reference` group.
    - Expanded capacity above 151 MB checks the build id marker plus `capacity` group and falls back to the free tier on failure.
    - Export/backup checks the `transfer` group and uses existing generic unavailable/error paths on failure.
    - Settings checks the `settings` group and keeps security detail unavailable through normal settings behavior on failure.
    - Fail closed silently into each feature's natural error path instead of emitting a distinctive integrity failure.
    - Avoid user-visible strings, logs, telemetry names, or symbols that contain obvious `tampered` / `integrity failed` wording.
  - Add a small release codegen script in Python or Dart.
    - Run per release after the web build and before signing/upload.
    - Initial Dart codegen writes the removable app-start wrapper/noise file.
    - Randomly assign hashed files to verifier groups.
    - Randomly choose from pre-written verifier template variants for each generated check.
    - Write a generated Dart file imported by the relevant feature files.
    - Regenerate `manifest.json` and `manifest.sig` to match the grouping and build id.
    - Keep generated code deterministic for a given release seed stored only in release metadata, not in shipped app-readable config.
  - Validation plan:
    - Add unit tests for manifest parsing, signature verification, and hash mismatch behavior.
    - Add release-gate tests with good manifest, bad signature, stale build id, missing artifact, and changed artifact cases.
    - Add web smoke tests proving normal app start/unlock/export/settings paths still work for supported builds.
    - Add negative tests proving failures map to generic feature errors without distinctive integrity strings.
  - [ ] Before production use, move from local/test ephemeral keys to one stable web integrity signing key stored in release secrets/CI beside Android release material.
  - [ ] Investigate browser load-time protections such as Subresource Integrity if Flutter's web loader can support it cleanly.

## 10) Reported Bug Backlog (2026-05-21)

- [x] Fix `Add item` list styling in dark mode so the list uses the same themed elements as the rest of the app.
- [x] Refresh biometric settings when the active vault changes.
  - Repro: create a new vault; unlock screen can still show the old vault master-key and biometric state.
- [x] Hide password values from list preview for single-field custom templates.
- [x] Prevent vault auto-lock when the app backgrounds during an in-progress operation.
- [x] Align dashboard filter menu with the all-items filter menu.
  - Dashboard should only show categories that are present, matching all-items behavior.
- [x] Show the current vault name in the app UI.
- [x] Ensure auto-lock works after the app is minimized or left unused for the configured duration.
- [x] Implement auto-lock configuration with a seconds-based slider.
- [x] Show numbers in notes preview mode.
- [x] Add support for identity items to attach ID photos.
  - Support a dynamic number of photos per identity.
- [x] Reset biometric password state for the vault when the master password is updated.
- [x] Show password strength when updating the master password.
- [x] Biometrics keeps prompting to enable even after biometrics has already been enabled.
- [x] Rework Notes UI: ensure editor scrolls while typing, prevent keyboard from hiding writable area, and make Notes menu items collapsible.
- [x] Improve pin interactions: long-press to show pin/delete actions, support adding notes to pinned items, and show delete action near edit when opening notes or secrets.
- [x] Add Gmail-style multi-select for vault items and notes: select items, select all, delete selected, and share selected as plain text.
  - Note sharing now uses full rich-text body serialization (including line-level formatting markers) instead of preview-only/plain fallback.
  - Added dual share actions in quick actions: `Share plain text` and password-protected `Share encrypted file` (`.nijas`).
  - Added encrypted-secret import entry points: `Open encrypted secret` on Vault main screen and `Import encrypted secret` in Settings.
  - Improved Android file association so tapping `.nijas` in file managers shows Nija in open-with options (including generic MIME providers).
  - Added unlock-screen `Open encrypted secret` flow to decrypt and preview file content using only secret-file password.
  - Added `Export encrypted file` action for notes/items to save `.nijas` directly to local filesystem.
  - Fixed secret import vault-lock regression: external picker/share transitions no longer immediately force lock during quick pause/resume.
  - Fixed Android open-with handoff: when app is launched from `.nijas` file intent, payload is now consumed in Flutter and opens encrypted-secret flow.
  - Improved Android file-explorer open flow for `.nijas` content-provider URIs (display-name/mime fallback parsing) and added `Import to vault` action on encrypted-secret preview.
  - Standardized protected-action vault login flow: select vault, unlock via password/biometric, then continue import action.
- [x] Fix Android vault export flow (currently not working).
- [x] Change biometrics enable/disable control in Settings to a slider.
- [x] Ensure each vault has a visible name.
- [x] Show `Create vault` option on the `Unlock existing vault` screen.
  - Added `Create vault` action on unlock screen that routes directly to setup flow (`Choose Guardian`).
  - Fixed back-navigation regression: when setup is opened from unlock and user presses back, app now returns to unlock screen (no hang).
- [x] On unlock screen back press: first press shows toast, second press exits app (instead of immediate exit).
  - Back press from inside unlocked vault now returns to unlock screen instead of exiting immediately.
- [x] Auto-save notes when navigating back from edit; run autosave every second and keep interval configurable in code.
  - `NoteEditorScreen` now auto-emits save payload every second (`noteAutosaveInterval` constant) and saves on back navigation.
- [x] Fix wrong-password error message on unlock: show `Wrong vault password` instead of `No vault found`.
  - Unlock now checks vault existence first and returns `Wrong vault password` only when file exists.
- [x] Require biometric confirmation in Settings for both enabling and disabling biometrics.
  - Settings toggle now asks for confirmation dialogs for both enable and disable actions.
- [x] Fix multi-vault biometric state: when switching to a different vault, prompt to enable biometrics for that vault if not enrolled; store biometric enrollment/signature mapping per vault in app-local storage (not inside vault file).
  - Added per-vault biometric enrollment map in app-local preferences and tied unlock prompt/toggle state to vault-specific enrollment.
  - Added list sort/filter options (`Last accessed`, `Title`) for vault items and notes, plus Settings defaults for both tabs.
  - Updated toolbar controls to explicit `Sort by` and `Filter by` with icons; added vault `Filter by type`, notes `Filter by tags`, and notes `Sort by tags`.
  - Added pin filter chips (`All / Pinned / Unpinned`) for both keys and notes; added key tags input + list tag display + tag-aware key search.

## 11) Free vs Paid Feature Gating

- [x] Add app-level feature gating boolean(s) for `free` vs `paid` version behavior.
  - Centralize in config so UI + actions can check the same source of truth.
  - Keep paid features disabled by default unless paid mode is enabled.
- [x] Add first paid feature: Google backup integration (paid-only).
  - Historical note: backup was first implemented as paid-only.
  - Current direction: backup and restore are free while monetization is deferred.
  - Android expanded storage remains gated by the Google Play entitlement; `NIJA_PAID_BUILD` remains a development override.
  - Implemented paid-build `Backup now` action via native share sheet to save encrypted vault file into Google Drive/iCloud Drive.
  - Centralized cloud-backup and expanded-storage capability checks in `AppFeatures`, and added free-build regression coverage for the Settings gate.
- [x] Move paid feature unlocks from build-only flags to runtime entitlements.
  - Paid features must be toggleable at runtime based on a locally cached entitlement and the latest Play Billing purchase state.
  - Keep build flags only for development/testing overrides, not as the production source of truth.
  - Centralize runtime entitlement state so Settings UI, backup actions, storage limits, and future paid features all read the same source.
  - Default to free features until a trusted runtime entitlement is loaded.
  - Add tests proving paid UI/actions can unlock and relock without rebuilding the app.
  - Web storage limits are currently client-enforced: new/small vaults cap at 151 MB, and legacy vaults already above 151 MB can continue up to 1 GB until runtime entitlement exists.
- [ ] Revisit monetization after beta usage data.
  - Free app currently includes 151 MB storage, one vault, and cloud backup/restore.
  - Keep Google Play product `nija_expanded_vault_lifetime` for Android 1 GB storage and multi-vault support.
  - Decide later whether web/iOS need server-backed entitlement, subscription, or remain free.
- [x] Add Google Play Billing lifetime storage unlock.
  - Create a Play Billing product: `nija_expanded_vault_lifetime`.
  - Product type: non-consumable one-time purchase.
  - On purchase, Google Play records entitlement against the user's Google account.
  - On every Nija start, call the Play Billing API and unlock premium features when the product is returned as purchased.
  - Store the last known purchased entitlement securely in app-local storage, not inside any vault, so premium remains available during offline starts.
  - If Play Billing returns not purchased and no trusted local entitlement exists, keep free features only.
  - Purchase restoration should work automatically when the user reinstalls, changes phone, or signs into another Android device with the same Google account.
  - No backend should be required for the initial lifetime supporter entitlement.

## 12) Mobile Share-Into-Notes Flow

- [ ] Add mobile text share-intent ingestion so Nija appears in share sheet and can import shared text into the selected vault as a note.
  - When user shares text to Nija, create a note with:
    - Title format: `Shared from <ApplicationName> datetime`.
    - Tag will be application name , shared 
    - Body containing the full shared text.
    - Timestamp metadata (shared/import time).
  - Route to vault selection when needed, then save into the chosen vault.
  - [x] Added Android `ACTION_SEND text/plain` ingestion through the existing native intent bridge.
  - [ ] Add iOS Share Extension target for true iOS share-sheet ingestion.

## 13) Vault Item Attachments

- [x] Add attachments support to normal vault items.
  - Store attachment metadata on the item and encrypted bytes in private document sections.
  - Keep document bytes out of item payload JSON.
  - Enforce existing per-document limit: `VaultLimits.maxDocumentBytes` (`5 MB`).
  - Continue enforcing total vault size through `VaultLimits.maxVaultBytesFor`.
- [x] Add support for multiple documents per vault item.
  - Use an `attachments` list instead of single-document fields such as `documentSection`, `documentFileName`, and `documentSizeBytes`.
  - Support adding, opening, exporting, and deleting individual attachments.
  - Keep the existing standalone Document item flow working during migration.
  - Attachment removal currently removes item metadata; private document-section garbage collection remains a future storage cleanup task.
- [x] Fix PDF/document preview focus and scrolling.
  - Real-device verification completed; PDF/document preview gesture focus is working better.
  - Ensure PDF previews and basic document previews can receive gesture focus and scroll vertically/horizontally inside the viewer.
  - Added attachment-preview interaction locking so normal item detail scrolling is disabled while a document/PDF preview is being touched.
  - Wired `pdfrx` interaction callbacks so PDF pan/zoom interactions keep the parent page from stealing gestures.
  - Added regression coverage for the attachment preview interaction boundary and a PDF gesture integration test target.
- [x] Add fullscreen/enlarged document preview mode.
  - Current document preview window is too small for comfortable reading.
  - Add an enlarge/fullscreen icon from document preview surfaces.
  - Fullscreen mode should preserve PDF pan/zoom and basic document scrolling behavior.
  - Provide an obvious close/minimize action and keep save/export actions reachable.
  - Add widget/integration coverage for opening and closing fullscreen document preview.
  - Added fullscreen preview actions for standalone document detail and item attachment preview panels.
  - Added widget coverage for opening and closing fullscreen previews from both surfaces.
- [ ] Add Android open-with support for supported documents.
  - Basic docs and PDFs should be directly openable by Nija when the user selects `Open document`.
  - Register Android picker/open intent support so Nija appears for supported document MIME types/extensions.
  - Documents opened from Android picker/open intents should render in a sandbox viewer without asking for the vault password and without importing into a vault by default.

## 14) Release Readiness Fixes

- [x] Clean up `vault_app_shell.dart` analyzer issues.
  - Goal: `flutter analyze` passes with zero issues.
  - Scope: unused fields/methods, deprecated `WillPopScope`, unnecessary casts, and related analyzer warnings.
- [x] Implement Settings `Security & Encryption`.
  - Goal: replace the `Settings coming soon` placeholder with a user-safe security details surface.
  - Add a polished screen or bottom sheet from Settings -> `Security & Encryption`.
  - Explain the user-facing security model:
    - master password is used only to derive an unlock key,
    - Argon2id derives the password/recovery keys,
    - the derived key unwraps the random vault key,
    - vault contents are encrypted with authenticated encryption,
    - master password and raw vault key are not stored,
    - recovery phrase cannot be recovered by Nija if lost.
  - Hide current vault crypto metadata from the user-facing sheet for now:
    - guardian profile,
    - KDF name (`Argon2id`),
    - KDF memory / iterations / parallelism,
    - cipher name (`AES-256-GCM`).
  - Keep sanitized vault format metadata visible:
    - vault format/schema/storage layout versions,
    - vault created/updated timestamps,
    - vault revision/version label.
  - Add simple security status checks:
    - vault encrypted at rest,
    - recovery key wrapper present,
    - biometric unlock enabled/disabled,
    - auto-lock setting,
    - cloud backup enabled/disabled,
    - last backup timestamp,
    - release build hides debug internals.
  - Add links/actions from this surface:
    - change master password,
    - rotate recovery phrase,
    - manage biometrics,
    - adjust auto-lock,
    - export encrypted vault,
    - open backup/restore controls.
  - Reuse `readVaultInternals()` only through a sanitized presentation model.
  - Keep debug internals separate: do not expose working folder/files, raw encrypted section names, raw errors, payloads, keys, salts, nonces, stack traces, or other non-user-facing internals in production UI.
  - Add tests for the Settings row opening the new surface and for sanitized format/status rendering.
  - Added bottom sheet with security model explanation, sanitized format metadata, status checks, and security actions.
  - Added recovery-phrase rotation dialog entry point from the security surface.
  - Added widget coverage that verifies sanitized format/status rendering, hides crypto metadata rows, and excludes raw working-store/internal fields.
- [ ] Configure real Android release signing.
  - Goal: release APK/AAB is signed with a production keystore, not debug keys.
  - Scope: add `android/key.properties` handling, define a release signing config in `android/app/build.gradle.kts`, remove debug signing from `buildTypes.release`, and document release SHA setup for Google Drive OAuth.
- [ ] Finalize production Android app identity and metadata.
  - Goal: package ID, app description, version name/code, and release comments are production-ready.
  - Scope: replace placeholder Gradle TODOs, confirm `applicationId`, update `pubspec.yaml` description/version, and verify store-facing labels/assets.
- [x] Sanitize release logging and error surfaces.
  - Goal: no production path logs raw vault, backup, payload, credential, or stack trace details.
  - Scope: gate or remove `debugPrint`/stack traces in onboarding and cloud backup paths, return user-safe errors, and keep detailed diagnostics out of release builds.
- [ ] Complete release hardening checklist signoff.
  - Goal: every item in `docs/release_hardening_gates.md` is verified or explicitly documented before tagging a production build.
  - Scope: recovery phrase handling, rotation flows, unlock failure behavior, migration rejection, sensitive-field clearing, debug config, logging, crash surfaces, and encrypted web storage behavior.
- [ ] Run real-device production validation matrix.
  - Goal: Android/iOS/Web critical flows are manually verified on release/profile builds.
  - Scope: create vault, unlock, lock, recovery unlock, password reset, master/recovery rotation, CRUD persistence after restart, import/export, encrypted secret open-with, document open/share, free cloud backup/restore, and Android paid storage upgrade.
- [x] Fix onboarding create-vault/recovery widget tests.
  - Goal: onboarding tests reliably reach `Recovery phrase` and `I saved my phrase`.
  - Scope: update test helpers or UI flow assumptions around vault-name/password fields and async create flow.
- [x] Fix note editor widget test localization setup.
  - Goal: note editor tests pass without `MissingFlutterQuillLocalizationException`.
  - Scope: add `FlutterQuillLocalizations.delegate` to test app setup or shared test harness.
- [x] Update stale vault shell widget tests for current UI.
  - Goal: `test/vault_shell_test.dart` passes against the current app navigation/actions.
  - Scope: update tests expecting old `Custom templates`, `All types`, note action keys, selection/share actions, and related labels.
- [ ] Re-run release readiness gates.
  - Goal: `./scripts/release_hardening_gate.sh`, `flutter test`, and `flutter build apk --release` all pass.
- [x] Add WebApp release build steps.
  - Goal: document and validate repeatable release steps for the web app.
  - Scope: added commands for clean Flutter wasm web release build, build artifact location, hosting assumptions, cache headers/service-worker behavior, and release smoke checks.
  - Include a release note/template for producing the web app release artifact and confirming it can be deployed without dev-only flags.
- [ ] Implement WebApp/tablet UX consistent with the Nija app theme.
  - Work these one item at a time and validate each item before moving to the next.
  - [x] Add responsive web vault-start first page and unlock surface.
    - Match the existing Nija mobile app theme on web/tablet so onboarding and unlock feel consistent across platforms.
    - Keep side navigation for authenticated landscape/tablet/web vault screens, not for the onboarding welcome/unlock surfaces.
    - Ensure first-page import actions open import/restore flows, not create-vault onboarding.
    - Keep imported-vault password validation from asking for the same password again after successful import.
    - Web builds skip the first-install walkthrough and land on the vault-start welcome surface.
    - Make `Create vault` a proper button action instead of text-only.
    - Preserve existing mobile unlock behavior and back/unlock/recovery actions.
    - Add widget coverage for wide-screen first page and unlock layout.
  - [ ] Add responsive web home dashboard.
    - Desktop/tablet shell should use left sidebar navigation, greeting/header, search, stats cards, recent items, quick actions, vault status, and category summary.
    - Dashboard type/folder cards should use responsive columns and fixed readable widths instead of stretching across the whole browser.
    - Preserve existing mobile bottom-navigation flow.
  - [ ] Add responsive web all-items table view.
    - Wide layout should show table-style rows with checkbox, name, category, folder, username/details, updated timestamp, actions, search, filter, customize, add item, and pagination controls.
    - Preserve existing mobile card/list behavior.
  - [ ] Add light-mode web visual polish pass.
    - Use the reference palette direction with restrained purple accents, white surfaces, soft borders, small radii, and compact enterprise-style density.
    - Verify typography, spacing, hover/focus states, and button/icon treatment.
  - [ ] Add responsive web regression coverage.
    - Cover desktop width, tablet width, phone width, and light mode for login, dashboard, and all-items surfaces.
- [ ] Make WebApp installable/offline-first with native-app feel.
  - Goal: web app should work well on iOS Safari and Android Chrome as an installable app and remain usable offline after initial load.
  - Scope: verify PWA manifest, icons, theme color, safe-area handling, viewport sizing, service worker caching, offline startup, IndexedDB/local vault persistence, and add-to-home-screen behavior.
  - Validate create/unlock/lock/reopen flows on iOS and Android browsers in installed and normal browser modes.
  - Keep UX aligned with native app behavior for navigation, touch targets, document preview, backup/export, and offline messaging.
  - Audit and update `web/manifest.json` for PWA installability:
    - production app name/short name,
    - app description,
    - `start_url`,
    - `scope`,
    - `display: standalone`,
    - theme/background colors,
    - 192px/512px maskable icons.
  - Audit `web/index.html` for mobile web app behavior:
    - manifest link,
    - viewport and safe-area behavior,
    - iOS web-app capable metadata,
    - theme-color metadata,
    - no development-only script/config.
  - Replace web vault persistence from `localStorage` to IndexedDB for larger encrypted vault/document payloads.
    - Store only encrypted `.nija` payload data and non-secret preferences.
    - Add migration from existing `localStorage` web vault entries if needed.
    - Add tests for create/unlock/edit/reload persistence using the web adapter.
  - Verify Flutter web service-worker/offline behavior.
    - First successful online load should cache the app shell.
    - Later launches from iOS/Android home screen should start without network.
    - Offline mode must not block unlocking an already-created local vault.
  - Add offline UI states:
    - show when running offline,
    - disable or explain cloud backup/restore while offline,
    - keep local save/edit/export behavior clear.
  - Add add-to-home-screen guidance:
    - Android Chrome install prompt / install app menu.
    - iOS Safari Share -> Add to Home Screen.
    - iOS limitation note: browser install prompts are limited compared with Android.
  - Validate browser/platform differences:
    - iOS Safari normal tab,
    - iOS home-screen web app,
    - Android Chrome normal tab,
    - Android installed PWA.
  - Add responsive/tablet-web pass for installed WebApp:
    - phone portrait,
    - phone landscape,
    - tablet portrait,
    - tablet landscape,
    - document/PDF fullscreen preview.
  - Add WebApp release smoke tests:
    - `flutter build web --release --wasm -O4 --no-source-maps --csp`,
    - serve `build/web` locally,
    - load app online,
    - create vault,
    - reload and unlock,
    - disable network,
    - launch/reload and unlock existing vault,
    - edit/save and confirm persistence after reload.
- [ ] Add WebApp security release review.
  - Goal: web release receives an explicit security pass before production deployment.
  - Scope: check HTTPS-only hosting, secure headers/CSP, no secret-bearing logs, no raw vault data in URLs/history, service-worker cache excludes decrypted payloads, IndexedDB stores only encrypted vault data, clipboard behavior, lock-on-background/visibility changes, and browser storage clearing behavior.
  - Validate that web debug internals and development-only flags are unavailable in production builds.
- [ ] Add obfuscation and reverse-engineering hardening for release builds.
  - Goal: make static analysis and reverse engineering harder without weakening maintainability or crash diagnosis.
  - Scope: enable Flutter/Dart obfuscation for release builds, split debug info into private artifacts, configure Android R8/ProGuard rules, strip unused resources, and document symbol/archive handling.
  - Add release commands for Android APK/AAB and web builds that include the agreed hardening flags.
  - Verify no secrets, API keys, entitlement bypasses, debug endpoints, or sensitive constants are embedded in client code.
  - Document limitations: obfuscation is defense-in-depth and does not replace cryptographic protections or server-side trust where needed.

## 15) Release Findings From Manual Testing

- [x] Close sensitive item/detail screens when the vault is locked in background.
  - Finding: if an item or note is open and the app auto-locks/background-locks, the same detail screen can remain visible after resume.
  - Goal: on app resume, check the current lock state before rendering vault content.
  - Scope: ensure item detail, note detail/editor, document preview, encrypted secret preview, and nested routes are dismissed or replaced by the unlock screen when the vault is locked.
  - Add regression coverage for: open item -> lock app/session -> resume -> item content is not visible.
  - Lock now collapses app routes to the root before switching to unlock, so sensitive pushed screens cannot remain above the unlock UI.
  - Added onboarding lifecycle regression coverage for: open note detail -> background auto-lock -> resume -> unlock screen visible and detail route dismissed.
- [x] Fix Debug view performance/hang.
  - Finding: opening the debug/internals view can hang the app, and pressing Home or performing operations feels slow afterward.
  - Goal: Debug view must not block UI or repeatedly trigger expensive filesystem/metadata reads.
  - Scope: audit `onReadVaultInternals`, debug file-tree rendering, `FutureBuilder` rebuild behavior, file-size traversal, and any synchronous work on the UI isolate.
  - Keep debug-only internals behind development surfaces and avoid raw filesystem scans in production paths.
  - Add performance guard or test coverage for opening/closing Debug view without repeated expensive reads.
  - Cached the debug internals future so Home/Debug navigation and normal rebuilds do not repeatedly read metadata/filesystem state.
  - Added an explicit Refresh action for debug internals when a fresh snapshot is needed.
  - Capped rendered debug file rows/tree entries to keep large vaults from flooding the widget tree.
  - Added widget coverage for cached debug reads, explicit refresh, and capped rendering.
- [x] Review debug internals rendering and attachment storage architecture.
  - Finding: the debug `Encryption` section shows too much document-attachment information and includes repeated/duplicate details.
  - Finding: `Vault file tree` can stretch the page and appears to show duplicate items.
  - Finding: `Working files` in the TODO/debug section also shows duplicate files.
  - Goal: debug internals should be readable without expanding the whole page to match large encryption/file-tree output.
  - Scope: make `Encryption`, `Vault file tree`, and `Working files` fixed-height scrollable panels.
  - Scope: dedupe repeated rows/details in these sections and hide noisy attachment internals that do not help validate vault health.
  - Scope: review file saving and attachment persistence architecture to confirm whether attachment writes are polluting the vault with duplicate/orphaned sections.
  - If attachment persistence is polluting the vault, fix the write/delete flow and add regression coverage for duplicate/orphaned attachment sections.
  - Grouped document manifest/chunk rows in `Encrypted sections`, `Vault file tree`, and `Working files` so attachment internals do not repeat noisy per-file details.
  - Made `Encrypted sections`, `Vault file tree`, and `Working files` render in bounded scroll panels.
  - Tightened document overwrite storage: replacing a large attachment with a smaller one now removes stale chunks for the same document id immediately, before the next payload commit.
  - Added regression coverage for immediate stale chunk pruning and debug document section grouping.
  - Fixed file-backed private vault commits to prune files that are no longer part of the committed section set.
  - Fixed payload persistence to retain only referenced document manifests/chunks, pruning stale replacement chunks and unreferenced attachment/document sections.
  - Added regression coverage for stale chunk pruning, removed-document pruning, and grouped debug rendering.
- [x] Investigate and fix app lag when pressing Home.
  - Finding: the app starts lagging when the Home tab/button is pressed.
  - Goal: Home navigation should feel immediate and should not trigger unnecessary persistence, vault metadata reads, document byte reads, debug reads, or broad list recomputation.
  - Scope: profile Home tab rebuilds, recent-item sorting, size calculations, dashboard filters, lifecycle lock checks, and any async work started during tab switch.
  - Add targeted profiling notes and regression coverage for avoiding redundant work on Home navigation.
  - Cached derived Home dashboard data behind an input signature so normal Home rebuilds/tab switches do not repeatedly recompute counts and recent rows.
  - Replaced full recent-list sorting with a single-pass top-4 recent activity calculation.
  - Kept relative-time labels on a minute-bucket signature so labels refresh without rebuilding on every frame.
- [x] Investigate and fix note writing lag.
  - Finding: typing in notes lags.
  - Goal: note editor typing should remain responsive with autosave enabled.
  - Scope: audit autosave interval, rich-text delta serialization, title/tag rebuilds, persistence frequency, keyboard/scroll listeners, and expensive parent callbacks.
  - Consider debouncing heavy serialization/persistence and keeping autosave off the typing critical path.
  - Add a large-note/manual typing validation case before release.
  - Replaced periodic autosave polling with a debounced autosave timer that resets while the user continues editing.
  - Full Quill document serialization and parent persistence now happen only after the user pauses or explicitly saves.
  - Reused a single note snapshot for fingerprinting/payload creation and removed a JSON encode/decode clone from the save path.
  - Added widget coverage that verifies active edits delay autosave until typing pauses.
- [x] Allow attached documents to be downloaded from preview and item pages.
  - Finding: document preview/viewing flow lacks a direct download/export action where users expect it.
  - Goal: users can save/download an attached document from the document preview page and from the item detail page when an item has document attachments.
  - Scope: add clear `Download`/`Save copy` actions to document preview, document detail, and item detail attachment rows.
  - Preserve encrypted vault storage; exported/downloaded files are explicit user actions and should use the original filename/mime where available.
  - Add tests for document preview download action availability and item-page attachment download action availability.
  - Added platform export support for decrypted document bytes using the original filename and MIME type.
  - Added `Save copy` on the document preview/detail page.
  - Added `Save copy` to document quick actions from the item list.
  - Added widget coverage for save-copy action availability in the document preview and document action sheet.

## 16) Vault App Shell File Split

- [x] Move encrypted import/share UI out of `vault_app_shell.dart`.
  - Goal: keep vault shell focused on orchestration, not import bundle screens.
  - Scope: move `_EncryptedShareChoice`, `_EncryptedImportEntry`, `_PreparedVaultImport`, `_EncryptedShareInputDialog`, `_EncryptedImportBundleScreen`, `_EncryptedImportEntryPreviewScreen`, `_ImportPreviewHeader`, `_ImportPreviewRow`, and import preview helpers into `lib/features/vault/presentation/widgets/encrypted_import_widgets.dart` or a dedicated `encrypted_import/` folder.
- [x] Move custom template manager into its own screen file.
  - Goal: isolate custom template CRUD from shell navigation.
  - Scope: move `_CustomTemplateManagerScreen` and related state into `lib/features/vault/presentation/custom_template_manager_screen.dart`.
- [x] Move settings widgets and dialogs into settings-focused files.
  - Goal: keep settings layout reusable and easier to test.
  - Scope: move `_SettingsSection`, `_SettingsRow`, `_SettingsActionRow`, `_AutoLockSecondsSheet`, `_RenameVaultDialog`, `_PasswordStrengthMeter`, and related formatting helpers into `lib/features/vault/presentation/widgets/vault_settings_widgets.dart`.
- [x] Move document detail UI into a dedicated screen file.
  - Goal: separate document rendering/export logic from the shell.
  - Scope: move `_DocumentDetailScreen`, `_DocumentHeader`, `_DocumentPreviewMessage`, document filename/extension/size/mime helpers, and document payload helpers into `lib/features/vault/presentation/document_detail_screen.dart`.
- [x] Move item detail and identity photo UI into dedicated files.
  - Goal: separate item viewing/editing and identity photo viewing from shell state.
  - Scope: move `_ItemDetailScreen`, `_IdentityPhotosSection`, `_IdentityFullPhoto`, `_IdentityPhotoPreview`, and identity photo size helpers into `lib/features/vault/presentation/item_detail_screen.dart` plus optional identity photo widget file.
- [x] Move shared small vault widgets into a common widget file.
  - Goal: reduce noise in shell and reuse visual primitives consistently.
  - Scope: move `_EntryMetadataPanel`, `_EntryMetadataLine`, `_EmptyState`, `_TinyChip`, `_SectionHeader`, `_DebugInfoCard`, `_HomeTypeCard`, `_AllItemsSelectionActionBar`, `_SelectionActionNavItem`, `_AllItemsFiltersOverlay`, `_ActiveFilterChip`, icon/color helpers, and metadata timestamp helpers into focused widget/helper files.
  - Extracted shared visual primitives and filter overlays into `lib/features/vault/presentation/widgets/vault_common_widgets.dart`.
- [x] Re-run format, analyzer, and targeted widget tests after each split.
  - Goal: keep every extraction behavior-preserving.
  - Scope: run `dart format`, `flutter analyze`, and the most relevant `flutter test` target after each moved group.
  - Formatted files, verified clean static analyzer, and verified all 60 tests in `test/vault_shell_test.dart` pass without regressions.

## 17) Codebase Slimming, De-bloating & Architecture Modernization

### Architectural Audit & Findings
- **Purpose vs. Footprint**: Nija is defined as *"A local-first, privacy-first encrypted vault for passwords, notes, documents, and identities"*, but has grown to **41,686 lines of Dart** in `lib/` (plus 12,649 lines in tests).
- **Presentation Layer Overweight**:
  - `lib/domain/` (core models and crypto logic): **661 lines** (1.6% of app).
  - `lib/features/` (UI and screen state): **30,690 lines** (73.6% of app).
  - Business logic, platform hooks, Google OAuth flows, and file I/O are heavily coupled directly inside Flutter `StatefulWidget` classes rather than services.
- **Monolithic "God Files"**:
  - `lib/features/onboarding/presentation/onboarding_flow.dart`: **9,150 lines** (48 classes). Despite being called "onboarding", it houses `UnlockScreen`, `_NijaPinDialog`, `KnownVaultSelectionScreen`, `_VaultMergeScreen` (1,200 lines), encrypted secret previewers, and inline PDF/document viewers. `_OnboardingFlowState` alone is **5,232 lines**.
  - `lib/features/vault/presentation/vault_app_shell.dart`: **6,154 lines** (was 8,310). Acts as an all-in-one controller for tabs, filters, multi-select, auto-locks, drawer modals, and clipboard listeners.
  - `document_detail_screen.dart` (1,714 lines), `add_vault_item_screen.dart` (1,664 lines), `item_detail_screen.dart` (1,604 lines).
- **Out-of-Scope Feature Creep**:
  - **Web Runtime Anti-Tamper Engine (`lib/core/web_integrity/`)**: Manifest hashing, Ed25519 signature checks, codegen, verifier groups, and startup checksum validation. Futile client-side DRM for a web app that adds build-step friction and code weight.
  - **In-App Purchases & Entitlements Engine (`lib/core/entitlements/`, `in_app_purchase`)**: Google Play Billing state machine and an artificial 151 MB free vs. 1 GB paid storage limit paywall in what should be a local-first privacy vault.
  - **Direct Cloud Sync & Google Drive APIs (`googleapis`, `google_sign_in`, `http`)**: Web OAuth popups, token refresh mechanisms, and complex 3-way cloud merge conflict screens instead of delegating file sync to the OS/file-system.
  - **Heavy Third-Party Dependencies**: `flutter_quill` (WYSIWYG delta rich-text engine) and `pdfrx` (native C++ PDF rendering engine).
- **Component Duplication**:
  - Identical copies of `_DocumentPreviewMessage` and `_PdfStatusBanner` duplicated across `onboarding_flow.dart` and `document_detail_screen.dart`.
  - Redundant PIN and biometric confirmation dialogs.

---

### Step-by-Step Modernization & Slimming Tasks (To Do One-by-One)

- [x] **17.1 Decompose and modularize `onboarding_flow.dart` (9,150 lines)**:
  - [x] 17.1.1 Extract `_VaultMergeScreen` and merge version preview cards (~1,200 lines) into `lib/features/vault/presentation/widgets/vault_merge_screen.dart`.
  - [x] 17.1.2 Extract `_NijaPinSetupDialog`, `_NijaPinEntryDialog`, and PIN actions (~250 lines) into `lib/features/vault/presentation/widgets/nija_pin_dialogs.dart`.
  - [x] 17.1.3 Extract `_EncryptedSecretViewerScreen`, `_EncryptedImportBundleScreen`, and secret previewers (~800 lines) into `lib/features/vault/presentation/widgets/encrypted_secret_viewer.dart`.
  - [x] 17.1.4 Extract `KnownVaultSelectionScreen`, `_KnownVaultCard`, and vault picker (~500 lines) into `lib/features/onboarding/presentation/known_vault_selection_screen.dart`.
  - [x] 17.1.5 Extract `UnlockScreen` (~450 lines) into a standalone `lib/features/onboarding/presentation/unlock_screen.dart`.
  - [x] 17.1.6 Deduplicate `_DocumentPreviewMessage` and `_PdfStatusBanner` into a single shared component in `vault_common_widgets.dart`.
  - [x] 17.1.7 Run `flutter analyze` and `flutter test test/onboarding_flow_test.dart` to ensure 100% test pass rate after each extraction.

- [x] **17.2 Deconstruct remaining monolithic tabs from `vault_app_shell.dart` (6,154 lines)**:
  - [x] 17.2.1 Extract `_buildTypesTab` (item categories/types view) into `lib/features/vault/presentation/widgets/vault_types_view.dart`.
  - [x] 17.2.2 Extract `_buildFavoritesTab` (starred items/notes view) into `lib/features/vault/presentation/widgets/vault_favorites_view.dart`.
  - [x] 17.2.3 Extract `_buildSettingsTab` (settings root view) into `lib/features/vault/presentation/widgets/vault_settings_view.dart`.
  - [x] 17.2.4 Verified shell tab modularization; validated with `flutter analyze` and `test/vault_shell_test.dart` (60/60 tests passing).

- [x] **17.3 Remove Web Runtime Anti-Tamper Subsystem (`web_integrity`)**:
  - [x] 17.3.1 Remove `lib/core/web_integrity/` directory and `lib/generated/web_integrity_groups.g.dart`.
  - [x] 17.3.2 Remove runtime integrity verifier calls and startup checks from app initialization and feature gates.
  - [x] 17.3.3 Remove obsolete web integrity test files (`test/web_integrity_*`, `integration_test/web_integrity_*`).
  - [x] 17.3.4 Verify clean build with `flutter analyze` and `flutter test`.

- [x] **17.4 Remove In-App Purchases and Entitlement Paywalls**:
  - [x] 17.4.1 Remove `lib/core/entitlements/` directory.
  - [x] 17.4.2 Remove `in_app_purchase` and `in_app_purchase_android` dependencies from `pubspec.yaml`.
  - [x] 17.4.3 Remove artificial 151 MB storage cap and lifetime purchase checks; allow unlimited local storage bounded only by device disk space.
  - [x] 17.4.4 Verify clean build and test suite.

- [x] **17.5 Audit and Streamline Heavy Third-Party Dependencies**:
  - [x] 17.5.1 Review `flutter_quill: ^11.5.1`: Audited WYSIWYG notes engine. Evaluated moving from Quill Delta format to a lightweight Markdown editor. Found existing serialized vaults rely on Delta JSON payloads; recommended retaining backward-compatible Delta reader while scheduling v2.0 lightweight Markdown transition.
  - [x] 17.5.2 Review `pdfrx: ^2.4.1`: Audited PDF rendering. Evaluated replacing native PDFium C++ engine with `open_filex`/intent. Found that external viewer hand-off requires writing decrypted plaintext PDF bytes to temporary device storage (breaking cryptographic privacy guarantees); concluded that `pdfrx`'s in-memory `PdfViewer.data()` is essential for zero-disk-leak secure document viewing.
  - [x] 17.5.3 Review Google Drive direct sync: Audited cloud sync dependencies (`googleapis`, `google_sign_in`, `http`). Verified that cloud sync remains 100% optional, client-side encrypted (AES-256-GCM), and does not affect offline local-first vault operations. Recommended future Storage Access Framework (SAF) folder sync to allow provider-agnostic local sync.
  - [x] 17.5.4 Verified clean static analysis (`flutter analyze`), 100% test pass rate across 182 tests (`flutter test`), and successful debug APK build (`flutter build apk --debug`).

## 18) UI/UX Polish, Critical Fixes & Visual Cohesion

### Phase 1: Critical Bugs & Security
- [x] **Persist custom vault name**: Display the user-entered vault name (Nija Vault or fallback "Personal Vault") instead of the raw UUID across the Unlock screen, Home header, and "Known vaults" list; move a truncated ID (`6bd4...f219`) to secondary monospace metadata.
- [x] **Deduplicate "Known vaults" entries**: Fix state registration during vault creation so a newly created vault appears only once in the Known vaults list.
- [x] **Fix overlapping text in Unlock progress modal**: Prevent `Decrypting vault...` and `Starting vault unlock...` from rendering simultaneously on top of each other, and remove the stray `)` character in the top-left corner of the modal.
- [x] **Mask Recovery Phrase preview on feeds**: Hide plaintext seed words in card previews (`••••••••••••`) on Home, All Items, and Favorites for any recovery/security item, requiring a tap and explicit "Reveal" action to view the phrase.

### Phase 2: Mobile Layout & Navigation
- [x] **Remove duplicate + creation button**: Delete the top-right `+` icon in the header and integrate the bottom floating `+` cleanly into the bottom navigation bar so it doesn't overlap scrolling item cards.
- [x] **Compact the Home category summary cards**: Use a responsive grid (2-4 columns) with compact 64px row-based tiles that fit the viewport width and expand vertically to show all available categories without hiding any cards off-screen.
- [x] **Remove duplicate branding on landing screen**: Hide the top-left Nija निज logo lockup on the root landing screen (keep only the theme toggle in the top right) so it doesn't repeat right above the hero logo.
- [x] **Refine the Demo Mode banner**: Shorten the button label from `Exit explore demo` to `Exit demo` so it stays on one line, and make the banner `position: sticky` below the top header on scroll.
- [x] **Fix rich-text toolbar overflow (New Note)**: Reduce horizontal button padding or wrap the formatting toolbar (Undo, Redo, Font size, B, I, U) in an `overflow-x: auto` container so `U` doesn't clip off the right edge on narrow viewports.

### Phase 3: Forms, Copy & Settings Consistency
- [x] **Add password visibility toggles on vault creation**: Add show/hide eye icons to both Master password and Confirm password inputs in Step 1 (Choose Guardian).
- [x] **Clarify New Item templates**: Differentiated schemas and roles between Login and Password templates; replaced repeated generic *Secure item details* subtitles with distinct descriptions and icons for Card, SSH Key, API Key, Wi-Fi Credential, Server/Database Credential, Bank Account, Passport, and License Key.
- [x] **Unify storage quota figures and labels**: Reconciled limits across Settings and Document Upload using unified `VaultLimits.formatBytes` (displaying `1.00 GB` consistently instead of `1024 MB` or stale `151 MB`), raised document attachment ceiling to 25 MB, and clarified that local device storage is unlimited while the 1.00 GB allocation applies to optional cloud sync.

### Phase 4: Visual Design & Brand Cohesion
- [x] **Introduce warm surface depth**: Shift the page canvas to warm stone (`#F8F7F4` light / `#111214` dark) against elevated `#FFFFFF` (`#1A1C20` dark) cards with 1px solid `rgba(0, 0, 0, 0.06)` borders and subtle shadows (`0 1px 3px rgba(0,0,0,0.04)`).
- [x] **Restyle the Step 1 security callout**: Replace the pastel pink info box (which reads like an error state) with a warm champagne/gold tint (`#FAF6EE` background, `#8A6D3B` text, shield icon) to match the origami N accent.
- [x] **Replace Guardian emojis with origami SVGs**: Swap native OS emojis (🦉, 🦁, 🦅) for three custom geometric/origami line-art SVGs in charcoal and warm gold for Owl, Lion, and Falcon.
- [x] **Assign unique icons per item template**: Replace the duplicated blue shield icons in New Item with distinct icons for Card, SSH Key, API Key, Wi-Fi Credential, and Server/Database Credential.
- [x] **Apply 8% tinted category icon badges**: Carry subtle 8% opacity background tints of each category's accent color into list row badges and filter pills.
- [x] **Refine landing page typographic scale**: Increase the Nija wordmark to 28px–32px (-0.02em tracking), style निज at 15px muted charcoal, and keep *Your private vault* slightly subordinate (22px).
- [x] **Use monospace for technical metadata**: Apply JetBrains Mono / IBM Plex Mono with tabular-nums to cryptographic specs, masked card digits (`•••• 4821`), truncated vault IDs, and storage metrics.

### Phase 5: Screen Polish & Micro-Interactions
- [ ] **Wrap item/note detail views in a structured card**: Present note and item details inside a 16px-padded card with a header bar showing the category badge, colored tag pills, Last modified timestamp, and a persistent Copy button.
- [ ] **Refine the top-right Lock action**: Restyle the oversized rounded rectangle Lock button into a crisp 40×40px circular button or compact 🔒 Lock pill.
- [ ] **Add one-tap quick copy on vault rows**: Place a direct Copy button beside the ⋮ menu on Login and Card rows that morphs into a checkmark for 2 seconds and shows a floating toast (*Copied · Clears in 30s*).
- [ ] **Upgrade Guardian selection feedback**: Add a 150ms border/background transition and visual Speed vs. Hardening indicator bars when toggling between Owl, Lion, and Falcon.


## Section 19: Folders & Metadata Hub (Explorer)

### Phase 1: Domain Model & Metadata Engine
- [x] **Define `VaultFolder` domain model**: Create `VaultFolder` entity (`id`, `name`, `parentId`, `color`, `icon`, `createdAt`, `updatedAt`, `tags`, `metadata`) and extend vault item/document payloads with `folderId` reference.
- [x] **Implement folder tree structure & path resolver**: Build tree builder utility to resolve absolute breadcrumb paths (e.g. `/Documents/Work/Invoices`), parent-child relationships, subfolder counts, and circular hierarchy prevention.
- [x] **Add folder CRUD methods to `VaultService`**: Support creating folders, renaming folders, moving folders/subfolders, and deleting folders (with cascading or orphan-reparenting options) without altering underlying encrypted container format.
- [x] **Metadata Hub storage integration**: Store folder topology as lightweight encrypted vault metadata entries alongside existing items so no separate or monolithic folder file is created, ensuring full compatibility with local persistence, cloud sync, and vault export.

### Phase 2: Navigation & Explorer Shell
- [x] **Integrate Folders into Bottom Navigation**: Add `Folders` navigation destination (`Icons.folder_outlined` / `Icons.folder`) between `All Items` and `Favorites` on mobile bottom navigation bar and wide desktop/web navigation rail.
- [x] **Build Windows Explorer-style Header & Breadcrumb Bar**: Render interactive breadcrumb path navigation (`Home > Work > Q4 Reports`) with back/forward history navigation buttons, path segment dropdowns, and current folder statistics (item count, total size).
- [x] **Unified Action Bar**: Provide top actions for `New Folder`, `Upload File`, `View Mode Switcher` (List / Grid / Tree), `Sort Menu`, and `Multi-Select`.

### Phase 3: Multiple Explorer Views (List, Grid, Tree)
- [x] **List View**: Dense Windows Explorer detail table displaying columns for Name, Date Modified, Type/Format, and Size, with interactive column header sorting.
- [x] **Grid View**: Responsive multi-column card grid featuring distinct folder icons, document preview thumbnails, item count badges, and quick-action triggers.
- [x] **Tree View**: Collapsible hierarchical tree navigator (as a split left pane on wide screens or toggleable drawer on mobile) displaying nested folders with expand/collapse carets.
- [x] **Sorting & Filtering**: Comprehensive sorting by Name (A–Z / Z–A), Date Modified (newest/oldest), Size (largest/smallest), and Type, plus quick search within current folder vs. recursive search.

### Phase 4: File Management, Metadata & Operations
- [x] **Direct File Upload into Active Folder**: Enable uploading files directly into the active folder; automatically extract file metadata (original filename, byte size, MIME type, extension, creation/modification timestamps).
- [x] **File & Folder Operations (Copy, Move, Delete)**: Implement context menu and toolbar actions:
  - **Copy**: Duplicate file or metadata reference to selected target folder.
  - **Move**: Reassign folder parent with an interactive destination folder picker modal.
  - **Delete**: Soft-delete or permanent removal with confirmation dialog and bulk multi-select support.
  - **Rename**: Quick inline or modal renaming with duplicate-name validation.
- [ ] **Rich Metadata Inspector Drawer/Sheet**: Provide an item/file metadata panel showing cryptographic integrity hash, encryption algorithm, size breakdown, parent folder path, tags, and custom metadata key-value pairs.


## Section 20: Independent Analysis v1 — Pre-Release Findings & Solutions

Pre-release review conducted across all four requested perspectives (**User**, **Technical Validator & Tester**, **Performance Test Expert**, **Security Expert**).
- **Baseline Static Check (`flutter analyze`)**: 0 issues.
- **Baseline Test Run (`flutter test`)**: 248 passed, **2 failed**:
  - `test/unlock_flow_regression_test.dart:89` (`lock flow opens themed unlock screen after vault selection`)
  - `test/vault_persistence_test.dart:356` (`mobile-like private store persistence private store commit happens before snapshot write on persist`)

---

### A) Findings as a Technical Validator & Tester (Data Integrity, State & Test Coverage)

- [x] **20.1 Fix stale `.nija` snapshot lockout after password rotation, recovery, or profile migration**
  - **Finding**: In `lib/application/services/default_vault_service.dart` (lines 36–37, 634–636), `_syncSnapshotOnPersist` now defaults to `false` when `privateVaultStore is FilePrivateVaultStore`. `createVault` writes `nija_vault.nija` at `revision: 1`, but subsequent `persistVaultPayload`, `rotateMasterPassword`, `resetMasterPasswordAfterRecovery`, and `migrateToBalancedProfile` calls never update that primary `.nija` snapshot. On cold app restart (`_handleToVaultStoreId` empty), `_readMigratedVaultFile` (lines 1461–1479) checks `_privateVaultStore.vaultExists(filePath)` (false, because the working store is keyed by `vaultId`), falls back to `_readSnapshotFile(filePath)`, and reads the **stale** `kdf` salt and `encryptedVaultKey`—permanently locking the user out of their new password/profile on the default vault path. Also causes `test/vault_persistence_test.dart:356` to fail (`revision` stays `1` instead of `2`).
  - **Solution**: On cold lookup in `_readMigratedVaultFile` / `unlockVault`, resolve the `vaultId` from the `.nija` file header (or registry/cache) and prefer `_privateVaultStore.readHeader(vaultId)` whenever the working store exists; and keep the primary snapshot header/file synchronized (or explicitly test-contracted) on key-wrapping mutations (`rotateMasterPassword`, `resetMasterPasswordAfterRecovery`, `migrateToBalancedProfile`). Add cold-restart regression tests with `FilePrivateVaultStore`.

- [x] **20.2 Fix double-persistence & double revision increment on every vault save**
  - **Finding**: `VaultAppShell._persistVaultDataUnchecked` (`lib/features/vault/presentation/vault_app_shell.dart:2974-2985`) calls `await widget.onPersistVaultData(...)` and then immediately calls `await widget.onPersistFolders!(...)`. In `lib/features/onboarding/presentation/onboarding_flow.dart` (lines 424–430), `onPersistFolders` invokes `_persistVaultData(...)` a second time. Every single item/note/folder save encrypts all core sections twice, commits twice, and increments `revision` by 2.
  - **Solution**: Include `folders` directly in `onPersistVaultData` (or remove the redundant `onPersistFolders` invocation when `onPersistVaultData` already commits `_folders`) so every mutation performs one atomic commit.

- [x] **20.3 Flush pending debounced writes on lock, vault switch, and dispose**
  - **Finding**: Explorer operations (`_renameFolder`, `_moveFolder`, `_deleteFolder`, `_moveItemToFolder`, `_copyItemToFolder`, `_deleteItemFromExplorer`) use `_schedulePersistVaultData()` (400ms `Timer`). `VaultAppShell.dispose()` (`vault_app_shell.dart:504`) cancels `_persistDebounceTimer` without flushing. Locking, switching vaults, or closing the app within 400ms silently drops those edits.
  - **Solution**: Add an explicit `_flushPendingPersist()` helper invoked before `_lockVaultSession`, `_switchVaultFromApp`, `_handleExitFromAppShell`, and on `dispose` / app-background transitions.

- [x] **20.4 Fix uncancellable recursive `Timer` leak in `AutomatedBackupService.scheduleDailyBackup`**
  - **Finding**: `AutomatedBackupService.scheduleDailyBackup` (`lib/application/services/automated_backup_service.dart:226-243`) returns the Day-1 `Timer`, which `VaultAppShell` stores in `_midnightBackupTimer`. When Day 1 fires, the callback calls `scheduleDailyBackup(...)` recursively without updating `_midnightBackupTimer`. After the first execution, disabling automated backups, changing backup time, or locking/disposing `VaultAppShell` cannot cancel the background timer.
  - **Solution**: Return or update a mutable timer handle (e.g., `ScheduledBackupHandle` holding the active `Timer` with `.cancel()`), and cancel it cleanly in `VaultAppShell.dispose()`, `_setAutomatedBackupEnabled(false)`, and `_setAutomatedBackupTime`.

- [x] **20.5 Sync `initialFolders` and `guardianProfile` in `VaultAppShell.didUpdateWidget`**
  - **Finding**: `VaultAppShell.didUpdateWidget` (`vault_app_shell.dart:447-500`) refreshes `_items`, `_notes`, and `_customTypeDefinitions`, but ignores changes to `widget.initialFolders` and `widget.guardianProfile`.
  - **Solution**: Update `_folders` (when `!listEquals` on serialized/ID forms) and `_activeGuardianProfile` in `didUpdateWidget` when parent state changes.

- [x] **20.6 Fix Mobile ↔ Web NIJA V2 backup/restore & local `.nija` import incompatibility**
  - **Finding**:
    1. Mobile `_backupCurrentVaultToCloud` (`onboarding_flow.dart:4281`) exports binary NIJA V2 containers (`StreamingVaultContainer.packPrivateStoreToFile`), whereas `GoogleDriveVaultPortability._downloadDriveFileContent` (`lib/infrastructure/adapters/google_drive_vault_portability.dart:650`) calls `utf8.decode(bytes)` (throwing `FormatException` on binary NIJA V2) and Web's `DefaultVaultService.importNijaFile` only parses JSON snapshots.
    2. `VaultPortabilityAdapterImpl.importVaultFromLocal` (`lib/infrastructure/adapters/vault_portability_io.dart:30`) reads selected files with `File(path).readAsString()`, crashing with UTF-8 `FormatException` when importing a binary NIJA V2 `.nija` file locally.
    3. `GoogleDriveVaultPortability._listAllCloudBackups` (`google_drive_vault_portability.dart:475-486`) parses `revision` from `appProperties` while ignoring `vaultVersionId` and `updatedAt` in `appProperties`, forcing `hydrateCloudBackupContent` to download and `utf8.decode` the file (which fails for NIJA V2). As a result, Settings shows `"Never backed up"` / `"None"` even after mobile cloud backups.
  - **Solution**: Read local/cloud files as bytes (`Uint8List`) and dispatch on `StreamingVaultContainer.isContainerBytes` before UTF-8 decoding; add an in-memory NIJA V2 container unpacker for Web (`Uint8List` stream/slice) and pass file paths directly to `importNijaFile` on native IO; populate `versionId` and `updatedAt` from `file.appProperties` in `_listAllCloudBackups`.

- [x] **20.7 Fix `NetworkConnectivityService` fail-open on errors**
  - **Finding**: `NetworkConnectivityService.isWifiConnected()` and `hasInternetConnection()` (`lib/infrastructure/services/network_connectivity_service.dart:35-38, 55-58`) catch platform exceptions and `return true`, allowing "Back up over Wi-Fi only" to upload over metered cellular if connectivity inspection errors.
  - **Solution**: Fail closed (`return false`) in `isWifiConnected()` when `_cloudBackupWifiOnly` cannot confirm Wi-Fi/Ethernet, and surface a clear status message if connectivity cannot be verified.

- [x] **20.8 Remove dead feature overrides, debug prints, and placeholder platform identifiers**
  - **Finding**:
    - `onboarding_flow.dart:4619,4622` contains dead `AppFeatures.supportsCloudBackup || true` and `defaultTargetPlatform == TargetPlatform.android && true` expressions.
    - `vault_app_shell.dart:3277` contains stray `debugPrint('--> error in _handleLocalBackupNow: $e\n$st');` inside the cloud backup catch block.
    - `GoogleOAuthConfig.nativeServerClientId` (`lib/core/config/google_oauth_config.dart:19-22`) defaults to `''` with no release-build verification check.
    - Placeholder `com.example.*` identifiers remain in `ios/Runner.xcodeproj/project.pbxproj` (`com.example.nija`), `ios/Runner/Info.plist` (`com.example.nija.secret`), `linux/CMakeLists.txt` (`com.example.nija`), and `windows/runner/Runner.rc` (`com.example`).
  - **Solution**: Clean up dead `|| true` / `&& true` logic and stray `debugPrint`; replace all `com.example.*` identifiers with `com.nija.*`; and add a release check for OAuth configuration if native Drive sync is enabled.

- [x] **20.9 Expand pre-release test coverage for uncovered critical paths**
  - **Finding**: Missing automated tests for: (a) malformed headers, truncated streams, oversized `nameLen`/`dataLen`, and `../` path traversal in `StreamingVaultContainer`; (b) cold `DefaultVaultService` reload after `rotateMasterPassword`, `resetMasterPasswordAfterRecovery`, and `migrateToBalancedProfile` with `FilePrivateVaultStore`; (c) Mobile NIJA V2 backup → Web restore round-trip; and (d) locking/disposing `VaultAppShell` immediately after a debounced explorer edit.
  - **Solution**: Add dedicated unit, widget, and integration tests covering all four scenarios before release.

---

### B) Findings as a User (UX, Flows, Copy & Navigation)

- [x] **20.10 Fix system/Android Back navigation on Unlock screen (`test/unlock_flow_regression_test.dart`)**
  - **Finding**: In `onboarding_flow.dart` (`_handleRootBackPress`, lines 632–676), `OnboardingStep.unlock` is not handled and falls through to `_confirmQuitApplication()`, whereas `UnlockScreen`'s top-left back button calls `_goBackFromUnlock()` (navigating to `selectVault`). This makes system back inconsistent with the UI back button and causes `test/unlock_flow_regression_test.dart:89` to fail.
  - **Solution**: Handle `OnboardingStep.unlock` in `_handleRootBackPress` by calling `_goBackFromUnlock()`, returning cleanly to `KnownVaultSelectionScreen` (or cancelling an active import credential prompt).

- [x] **20.11 Fix local snapshot vault keying so backups persist across edits**
  - **Finding**: `VaultAppShell` (`vault_app_shell.dart:3106, 3155, 3214`) keys `AutomatedBackupService` snapshots by `widget.activeVaultVersionId` instead of the vault's stable `vaultId`. Because `vaultVersionId` mutates to a new UUID on every save (`_nextMutationHeader:1912`), every item/note/folder edit makes previous snapshots disappear from Settings (`0/2` again) and leaves unpruned snapshot directories orphaned on disk forever. Also `didUpdateWidget` does not refresh `_localSnapshots` when the vault changes.
  - **Solution**: Pass the stable `vaultId` into `VaultAppShell`, key `AutomatedBackupService` folders by `vaultId`, migrate/clean up any stale `nija_snapshots/` subdirectories from earlier builds, and refresh snapshots in `didUpdateWidget`.

- [x] **20.12 Fix Web local backup silent failure & misleading Settings UI**
  - **Finding**: On Web (`kIsWeb`), `AutomatedBackupService._resolveSnapshotsDirectory` (`automated_backup_service.dart:24`) uses `Directory('/tmp')` and calls `dart:io` `createSync`/`writeAsStringSync`, which throws `UnsupportedError` (caught and returning `null`). `_handleLocalBackupNow` gives no error or feedback when `snapshot == null`, yet Settings still renders the Local Backup toggle, time picker, and `Back up now` button on Web.
  - **Solution**: Either store rolling snapshots in Web IndexedDB (`nijaWriteIndexedText`) with clear size awareness, or hide/disable the `dart:io` rolling-snapshot controls on Web (`!kIsWeb`) and direct Web users to explicit `.nija` file export / Cloud backup.

- [x] **20.13 Stop scheduled backups from interrupting users & remove double busy overlays**
  - **Finding**:
    1. `_runAutomatedBackup()` (`vault_app_shell.dart:3268`) calls `widget.onBackupToCloud()`, which triggers `_backupCurrentVaultToCloud()` (`onboarding_flow.dart:4230`), throwing up a blocking modal progress dialog (or a Google Sign-In popup) mid-session while the user is editing or viewing secrets.
    2. Manual `_handleBackupNow()` (`vault_app_shell.dart:3317`) wraps `widget.onBackupToCloud()` in `_runWithBusy(...)`, stacking **two** modal busy overlays (`VaultAppShell._buildBusyOverlay` + `OnboardingFlow` busy `Stack` overlay) simultaneously.
  - **Solution**: Run scheduled automated cloud backups silently in the background (skipping if no valid Drive session exists rather than popping sign-in UI, and surfacing non-blocking status/banner on completion or failure). Give busy-overlay ownership to a single layer during manual cloud backup.

- [x] **20.14 Implement or remove Settings "Clear Data" stub & persist language preference**
  - **Finding**:
    1. Settings -> Data -> **Clear Data** (`lib/features/vault/presentation/widgets/vault_settings_view.dart:398-407`) is still a stub showing `"Settings coming soon."`.
    2. `_languageMode` in `lib/app/app.dart` is not persisted to `SharedPreferences` (unlike `_themeMode` and `_autoLockSeconds`), so selecting Español (`es`) resets to `'system'` on app restart.
    3. `vault_settings_view.dart:457` and `vault_app_shell.dart:2150` hardcode `Version 1.0.0`, while `pubspec.yaml` specifies `version: 0.1.1+2`.
    4. `onboarding_flow.dart:3678` displays developer setup instructions (*"add http://localhost and http://localhost:5173 to Authorized JavaScript origins in Google Cloud Console"*) inside an end-user SnackBar.
  - **Solution**: Implement **Clear Data** behind explicit master-password + destructive confirmation (wiping local working stores, snapshots, PIN/biometric enrollments, and `SharedPreferences` caches) or remove the row prior to release; persist `_languageMode` in `SharedPreferences`; display the actual build version from `pubspec.yaml`; and replace the `localhost` SnackBar copy with user-appropriate sign-in guidance.

- [x] **20.15 Standardize password whitespace handling & keep recovery note synchronized**
  - **Finding**: `SetupScreen` passes untrimmed `_passwordController.text` on vault creation; `_unlockWithPassword` does not trim; while `_showMandatoryMasterPasswordReset` and `_RotateMasterPasswordDialog` call `.trim()`. Also, `_rotateRecoveryPhrase` updates `_recoveryWords` in memory without updating `note-recovery-phrase` inside the vault, leaving the old phrase in Notes.
  - **Solution**: Standardize password whitespace behavior across create, unlock, rotate, and reset (preserving exact entered characters or trimming consistently with clear UI validation), and update/remove `note-recovery-phrase` when the recovery phrase is rotated.

---

### C) Findings as a Performance Test Expert

- [x] **20.16 Eliminate full-vault document chunk reads/rewrites/`fsync` on every metadata save**
  - **Finding**: `DefaultVaultService._commitPayload` (`default_vault_service.dart:1605-1623`) calls `_readExistingWorkingSections(vaultStoreId)`, reading every file in `vaults/<vaultId>/` (including all multi-MB `document_*_chunk_*.enc` files) into memory. `FilePrivateVaultStore.commitVault` (`private_vault_store.dart:305-312`) then writes **every** section—including unchanged document chunks—to `.tmp` with `flush: true` (`fsync`) and renames it. Combined with `NoteEditorScreen`'s 1s autosave and the double-persist bug (`20.2`), a vault with 200 MB of documents triggers ~400 MB of reads, ~400 MB of writes, and dozens of `fsync` calls per typing pause.
  - **Solution**: Restrict `persistVaultPayload` to writing only core metadata/payload sections (`header.json`, `manifest.enc`, `items.enc`, `notes.enc`, `settings.enc`, `tags.enc`) and deleting only orphaned `document_*` files identified from `describeVault` filenames—never reading or rewriting unchanged document chunks.

- [x] **20.17 Stream local snapshots and local exports instead of materializing full vault JSON in RAM**
  - **Finding**: `AutomatedBackupService.createLocalSnapshot` (`automated_backup_service.dart:113`) uses synchronous `writeAsStringSync`, `listSync`, and `deleteSync` on the UI thread. Both `_handleLocalBackupNow` / `_runAutomatedBackup` and `OnboardingFlow._exportCurrentVaultToLocal` (`onboarding_flow.dart:4190`) call `readRawVaultFile`, loading every document chunk into RAM, base64-encoding (+33% expansion), and `jsonEncode`-ing the entire vault into one giant string rather than using `StreamingVaultContainer` (`vaultService.exportVault`). On vaults up to `VaultLimits` (1 GB), this causes OOM crashes on mobile and browser tab crashes on Web.
  - **Solution**: Route native local snapshots and `_exportCurrentVaultToLocal` through `StreamingVaultContainer.packPrivateStoreToFile` (`vaultService.exportVault`) for bounded < 15 MB streaming I/O, and replace `*Sync` file operations in `AutomatedBackupService` with async I/O / background isolate execution.

- [x] **20.18 Replace per-chunk `compute()` isolate spawning & base64 marshaling with a persistent worker**
  - **Finding**: `SecureCryptoAdapter.encrypt`/`decrypt` (`secure_crypto_adapter.dart:43,71`) and `DefaultVaultService.readVaultDocument` (`default_vault_service.dart:806,825`) invoke Flutter's `compute()` for every payload > 512 bytes, spawning and tearing down a fresh Dart isolate per chunk/section and base64-encoding binary `List<int>` payloads into JSON strings (`vault_document_isolate.dart`) across the isolate boundary.
  - **Solution**: Maintain a persistent long-lived crypto worker isolate on native platforms communicating via `SendPort`/`ReceivePort` with `TransferableTypedData` / `Uint8List` (zero base64/JSON overhead).

- [x] **20.19 Offload large JSON encode/decode and cache per-entry search text**
  - **Finding**: `jsonEncode`/`jsonDecode` + `utf8.encode`/`utf8.decode` for `items.enc` and `notes.enc` execute synchronously on the main UI isolate. Additionally, `VaultAppShell._dashboardInputSignature` (`vault_app_shell.dart:1744-1779`) re-hashes every field of every entry on rebuilds, and `_entrySearchText` (`vault_app_shell.dart:1846-1877`) dynamically concatenates and lowercases all fields, tags, and Quill deltas across all entries during search.
  - **Solution**: Cache normalized search strings per entry ID (invalidating only on entry edit/version change), keep `_dashboardInputSignature` O(1) via revision/mutation counters, and move large `items`/`notes` JSON serialization onto the background worker isolate.

---

### D) Findings as a Security Expert

- [x] **20.20 Patch `StreamingVaultContainer` path traversal & unbounded header allocation**
  - **Finding**: `StreamingVaultContainer.unpackStreamToPrivateStore` (`lib/infrastructure/adapters/streaming_vault_container.dart:165-174`) reads `nameLen` and `fileName` from an untrusted binary `.nija` stream and passes `fileName` straight to `FilePrivateVaultStore.writeSectionStream` (`private_vault_store.dart:271`), which opens `File('${dir.path}${Platform.pathSeparator}$fileName')` with **no path-traversal validation** (`../`, `/`, `\`, absolute paths) and **no upper bound** on `nameLen` before `readExact(nameLen)`. A malicious `.nija` file can overwrite arbitrary files in the app container or crash the app with a multi-GB allocation.
  - **Solution**: Validate `nameLen > 0 && nameLen <= 255`, `dataLen <= VaultLimits.maxVaultBytes`, and enforce a strict section filename allowlist/regex (`^[A-Za-z0-9._-]+$` with no `..`, `/`, `\`, or `.tmp` suffix) in both `StreamingVaultContainer` and `FilePrivateVaultStore`.

- [x] **20.21 Fix Web quick-unlock cryptographic weakness (WebAuthn PRF must wrap master password directly)**
  - **Finding**: On Web (`onboarding_flow.dart:918-924, 1322-1326`), `WebQuickUnlockVaultWeb` (WebAuthn PRF) only encrypts the 6-digit PIN, while `PinCredentialStore` stores `AES-GCM(PBKDF2(PIN), masterPassword)` in `localStorage` (`SharedPreferences`). Any attacker with access to `localStorage` (e.g., via XSS or browser profile access) can offline brute-force all $10^6$ 6-digit PINs against PBKDF2-HMAC-SHA256 to recover the **master password**, bypassing WebAuthn PRF entirely.
  - **Solution**: Store `AES-GCM(PRF_key, masterPassword)` directly in `WebQuickUnlockVaultWeb` (IndexedDB) so Web biometric/passkey unlock never places a PIN-wrapped master password in `localStorage`, and remove the mandatory PIN dependency from Web biometric enrollment.

- [x] **20.22 Move native PIN storage to `FlutterSecureStorage`, add attempt rate-limiting, and tighten native biometric storage**
  - **Finding**:
    1. `PinCredentialStore` (`lib/core/security/pin_credential_store.dart`) persists wrapped master passwords in plaintext `SharedPreferences` (`nija_pin_unlock_v1`) with **zero attempt throttling, backoff, or wipe-after-N-failures**.
    2. `BiometricCredentialStore` (`lib/core/security/biometric_credential_store.dart:13`) instantiates `const FlutterSecureStorage()` with default options (no `AndroidOptions(encryptedSharedPreferences: true)` or Keychain/Keystore biometric-bound access control), meaning device unlock or backup extraction can expose stored credentials without biometric hardware enforcement.
  - **Solution**: Migrate native `PinCredentialStore` records to `FlutterSecureStorage`, enforce a persistent failed-PIN attempt counter with exponential backoff and automatic PIN removal after 5 consecutive failures (falling back to master password), and configure explicit hardened `AndroidOptions` / `IOSOptions` (ideally hardware-backed biometric-bound keys) on `BiometricCredentialStore`.

- [x] **20.23 Enforce master password policy & review Argon2id KDF parameters**
  - **Finding**: `VaultValidators.isStrongEnoughMasterPassword` (`>= 10` chars, letter + digit) is only displayed as guidance text in `_PasswordStrengthMeter` and is **never enforced** in `SetupScreen._canCreateVault`, `_showMandatoryMasterPasswordReset`, or `_RotateMasterPasswordDialog`—users can set `"1"` as a master password. Combined with `Falcon` (`4096 KB`, `1` iteration) and `Owl` (`8192 KB`, `2` iterations) falling below OWASP Argon2id minimums (19–46 MiB), weak passwords are vulnerable to offline cracking if a `.nija` file is exfiltrated.
  - **Solution**: Enforce `VaultValidators.isStrongEnoughMasterPassword` on vault creation, master password rotation, and recovery password reset; evaluate raising default `Owl` (and minimum `Falcon`) Argon2id memory/iteration parameters to meet OWASP guidance while benchmarking target mobile unlock latency.

- [x] **20.24 Generate cryptographically random Argon2id salts & fix cipher header metadata**
  - **Finding**:
    1. `DefaultVaultService` (`default_vault_service.dart:116-118, 311, 361, 414, 468, 485`) derives Argon2id salts from predictable UTC timestamp strings (`utf8.encode('salt-$now-${guardian.id}')`) instead of `Random.secure()`.
    2. `GuardianProfiles` (`lib/core/config/guardian_profiles.dart`) sets `cipher: 'xchacha20-poly1305'`, writing `'xchacha20-poly1305'` into `.nija` headers while `SecureCryptoAdapter` (`secure_crypto_adapter.dart:12`) encrypts with `AesGcm.with256bits()`.
  - **Solution**: Generate 16 cryptographically random bytes via `_randomBytes(16)` for all password and recovery KDF salts. Align `GuardianProfiles.cipher` to `'aes-256-gcm'` (while preserving compatibility when reading legacy headers).

- [x] **20.25 Harden Android manifest, screen-capture protection, temp file cleanup & intent filtering**
  - **Finding**:
    1. `android/app/src/main/AndroidManifest.xml` omits `android:allowBackup="false"` and `dataExtractionRules`, permitting Android Auto Backup to upload `SharedPreferences` (`nija_pin_unlock_v1`) and vault metadata.
    2. `android/app/src/main/kotlin/com/nija/MainActivity.kt` does not set `WindowManager.LayoutParams.FLAG_SECURE`, exposing passwords and recovery phrases to screenshots, screen recording, and OS app-switcher thumbnails.
    3. `MainActivity.openDocument` (`MainActivity.kt:115-138`) writes decrypted document bytes to `cacheDir/nija_document_open` and leaves the most recently viewed file on disk until another document is opened.
    4. `MainActivity.captureSecretFromIntent` (`MainActivity.kt:140-156`) accepts generic `application/octet-stream` and `text/plain` `ACTION_VIEW` intents without strictly requiring `.nijas`.
  - **Solution**: Add `android:allowBackup="false"` + `dataExtractionRules`; enable `FLAG_SECURE` in `MainActivity.kt`; delete `nija_document_open` cache files in `onStop`/`onDestroy` (or after viewer return); and tighten `captureSecretFromIntent` MIME/extension checks.

- [x] **20.26 Route all sensitive copies through `SecureClipboard` & clear session caches**
  - **Finding**:
    1. `RecoveryScreen` (`onboarding_flow.dart:5885`), `password_generator_sheet.dart:344`, `add_vault_item_screen.dart:787`, and `encrypted_secret_viewer.dart:42,57` call `Clipboard.setData(...)` directly, bypassing `SecureClipboard.copySensitive` (20s auto-clear).
    2. `_passwordController.text` and `DefaultVaultService._unlockedSessions` (`default_vault_service.dart:2012-2024`) retain the raw master password string in memory for the entire unlocked session even after `vaultKey` is unwrapped, and `_manifestChunksCache` is never cleared on `clearUnlockedSession`.
  - **Solution**: Route all secret/password/recovery-phrase clipboard copies through `SecureClipboard.copySensitive`; clear `_manifestChunksCache` in `clearUnlockedSession`; and avoid retaining raw password strings in `_UnlockedVaultSession` once `vaultKey` is unwrapped.

- [x] **20.27 Strengthen recovery dictionary entropy, review plaintext recovery note & tighten Web CSP**
  - **Finding**:
    1. `RecoveryPhraseDictionary` (`lib/core/config/recovery_phrase_dictionary.dart`) contains only ~112 words (vs. 2048 in BIP-39), giving 12-word recovery phrases ~80.8 bits of entropy and 4-word + 2-digit `PasswordGenerator.generatePassphrase()` only ~33.8 bits.
    2. `OnboardingFlow` / `VaultAppShell` automatically seed the user's 12-word recovery phrase into a plaintext vault note (`note-recovery-phrase`), increasing exposure if an unlocked session is compromised, and `RecoveryScreen` uses `SelectableText`.
    3. `web/index.html` and `web/_headers` allow `'unsafe-inline'` in `script-src` and `style-src` CSP directives, weakening XSS defense-in-depth on Web.
  - **Solution**: Expand `RecoveryPhraseDictionary` to a standard 2048-word BIP-39 wordlist (keeping legacy word acceptance for existing vaults); make seeding `note-recovery-phrase` opt-in rather than automatic; and work toward removing `'unsafe-inline'` from `script-src` in `web/index.html` / `web/_headers` (moving inline bootstrap/scripts to external hashed/strict files).


## Section 21: Independent Review v2 — Pre-Release Findings & Solutions

Second-pass pre-release review conducted after completing Section 20 across all four perspectives (**User**, **Technical Validator & Tester**, **Performance Test Expert**, **Security Expert**).
- **Baseline Static Check (`flutter analyze`)**: 0 issues.
- **Baseline Test Run (`flutter test`)**: 256 / 256 tests passing.

---

### A) Findings as a User

- [x] **21.1 Fix local snapshot restore not updating UI & overwriting disk before confirmation**
  - **Finding**: In `lib/features/vault/presentation/vault_app_shell.dart` (`_confirmRestoreSnapshot`, line 3598), restoring a local snapshot calls `widget.onRestoreRawVaultContent!(content)` → `OnboardingFlow._restoreVaultFromRawContent` (`lib/features/onboarding/presentation/onboarding_flow.dart:4509`). That method:
    1. Passes `storageId: _vaultFilePath` and `stageRawContent: true`, overwriting `_vaultFilePath` on disk immediately before password verification, replacement confirmation, or conflict resolution.
    2. Passes `continueToUnlock: false`, so `_loadVaultData(...)` is never called after import. The user still sees pre-restore items/notes/folders in the UI, and their next edit overwrites the restored snapshot with stale in-memory state.
    3. Also breaks if the local snapshot is stored as a binary NIJA V2 container (`readSnapshotContent` reads UTF-8 string).
  - **Solution**: Stage snapshot restores in a temporary path (not `_vaultFilePath`), support both NIJA V2 binary containers and JSON snapshots, and reload `_loadVaultData(password)` + `_refreshVaultSize()` + `_refreshLocalSnapshots()` on successful restore.

- [x] **21.2 Fix `Settings -> Security & Encryption` showing `"Unknown"` / `"Unavailable"` in release builds**
  - **Finding**: `OnboardingFlow` (`lib/features/onboarding/presentation/onboarding_flow.dart:482`) passes `onReadVaultInternals: kDebugMode && !_isExploreDemoSession ? _readVaultInternals : null`. Because `kDebugMode` is `false` in release builds, `_SecurityEncryptionSheet` (`lib/features/vault/presentation/widgets/vault_settings_widgets.dart:614`) receives `null` and displays `"Unknown"` for `Format`, `Format version`, `Schema version`, `Storage layout`, `Created`, `Updated`, `Revision`, and `"Unavailable"` for `Recovery key wrapper`.
  - **Solution**: Provide a dedicated lightweight `onReadSecurityMetadata` callback (enabled in release builds too) that reads only `header.json` via `readVaultHeader` without exposing debug file trees or reading encrypted sections.

- [x] **21.3 Complete "Clear Data" across snapshots, `SharedPreferences`, Web IndexedDB & re-auth**
  - **Finding**: `OnboardingFlow._clearAllLocalVaultData` (`lib/features/onboarding/presentation/onboarding_flow.dart:4460`) deletes `vaults/<vaultId>` and `_vaultFilePath`, but:
    1. Leaves `nija_snapshots/<vaultId>` (local rolling snapshots) on disk.
    2. Leaves `SharedPreferences` keys (`nija_pref_*`, `nija_device_id_v1`, theme/language/auto-lock prefs) intact.
    3. On Web (`if (!kIsWeb)`), skips deleting the vault from IndexedDB (`nija_vault`), so "Clear Data" leaves the Web vault intact.
    4. Executes immediately on confirmation without requiring master-password verification.
  - **Solution**: Require master-password verification before wiping; delete `nija_snapshots/<vaultId>`, clear `nija_*` `SharedPreferences` keys, delete IndexedDB vault entries on Web, and reset all in-memory state.

- [x] **21.4 Fix Web local import of Mobile NIJA V2 `.nija` files (`FileReader.readAsText` corruption)**
  - **Finding**: `web/nija_browser_bridge.js` (`pickTextFile`, line 113) reads selected files with `FileReader.readAsText(file)`. When a Web user picks a binary NIJA V2 `.nija` file exported from Android/iOS/Desktop, non-UTF-8 bytes are corrupted into `U+FFFD` replacement characters before Dart sees them.
  - **Solution**: Read `.nija` files with `FileReader.readAsArrayBuffer(file)` (returning bytes or base64 to Dart), check `StreamingVaultContainer.isContainerBytes`, and convert via `StreamingVaultContainer.containerBytesToJsonSnapshot` when NIJA V2 is detected.

---

### B) Findings as a Technical Validator & Tester

- [x] **21.5 Wire `createLocalSnapshotFromFileWriter` into `VaultAppShell` local backups**
  - **Finding**: `AutomatedBackupService.createLocalSnapshotFromFileWriter` (`lib/application/services/automated_backup_service.dart:109`) is currently dead code; `VaultAppShell._handleLocalBackupNow` (line 3264) and `_runAutomatedBackup` (line 3290) still call `widget.onReadRawVaultContent!()`.
  - **Solution**: Pass an `onExportVaultToPath` callback from `OnboardingFlow` to `VaultAppShell` (calling `_vaultService.exportVault`) and invoke `createLocalSnapshotFromFileWriter` on non-web platforms.

- [x] **21.6 Use streaming `exportVault` for desktop/native `_exportCurrentVaultToLocal`**
  - **Finding**: `OnboardingFlow._exportCurrentVaultToLocal` (`lib/features/onboarding/presentation/onboarding_flow.dart:4197`) still calls `_vaultService.readRawVaultFile` instead of `_vaultService.exportVault`, even on Desktop where `FilePicker.platform.saveFile` returns a file path directly.
  - **Solution**: On native desktop (and temp-file-backed mobile flows), export directly with `_vaultService.exportVault(vaultId: ..., destinationPath: ...)` via `StreamingVaultContainer`.

- [x] **21.7 Reconcile `VaultLimits.maxDocumentBytes` (5 MB vs documented 25 MB)**
  - **Finding**: `VaultLimits.maxDocumentBytes` (`lib/core/config/vault_limits.dart:7`) is `5 * 1024 * 1024` (5 MB), contradicting `docs/todo.md:620` which states the document attachment ceiling was raised to 25 MB.
  - **Solution**: Align `VaultLimits.maxDocumentBytes` (e.g., `25 * 1024 * 1024` if intended for release) or update the UI copy/docs to match the enforced limit, and verify chunked upload/preview tests at the target ceiling.

- [x] **21.8 Close IndexedDB connections in `web/nija_browser_bridge.js`**
  - **Finding**: `web/nija_browser_bridge.js` (`openDb`, lines 23–63) opens an `IDBDatabase` connection on every `readIndexedText`, `writeIndexedText`, and `deleteIndexedText` call and never calls `db.close()` after the transaction completes, which can block future `versionchange` upgrades across tabs.
  - **Solution**: Call `db.close()` in `txn.oncomplete` / `txn.onerror` / `txn.onabort` (or reuse a single cached connection).

- [x] **21.9 Add tests for v2 uncovered flows**
  - **Finding**: Missing automated tests for `_restoreVaultFromRawContent` (local snapshot restore updating UI & disk), `_clearAllLocalVaultData`, `createLocalSnapshotFromFileWriter`, and `scheduleDailyBackup` handle cancellation.
  - **Solution**: Add unit and widget tests covering all four paths.

---

### C) Findings as a Performance Test Expert

- [x] **21.10 Eliminate full-vault `readVaultInternals` RAM spike**
  - **Finding**: `DefaultVaultService.readVaultInternals` (`lib/application/services/default_vault_service.dart:1221`) calls `_snapshotForHandle(filePath)`, reading **every** encrypted section (including all `document_*_chunk_*.enc` files), base64-encoding them, and `jsonEncode`-ing the entire snapshot just to return header metadata and `snapshotBytes`.
  - **Solution**: Compute `readVaultInternals` from `readVaultHeader` + `describeVault()` file sizes (estimating snapshot bytes from working store byte sizes without reading any document chunk bytes).

- [x] **21.11 Eliminate remaining full-vault `readRawVaultFile` RAM spikes in backup/export**
  - **Finding**: `VaultAppShell._handleLocalBackupNow`, `_runAutomatedBackup`, and `OnboardingFlow._exportCurrentVaultToLocal` still materialize the entire vault + base64 documents in RAM via `readRawVaultFile`.
  - **Solution**: Resolved together with `21.5` and `21.6` by streaming via `StreamingVaultContainer.packPrivateStoreToFile`.

- [x] **21.12 Offload large `items.enc` / `notes.enc` JSON serialization to background isolate**
  - **Finding**: While AES-GCM crypto uses the persistent worker isolate (`vault_document_isolate_worker_io.dart`), `jsonEncode`/`jsonDecode` and `utf8.encode`/`utf8.decode` for `items.enc` and `notes.enc` still run synchronously on the main UI isolate (`DefaultVaultService._payloadFromWorking`, `_sectionsForPayload`).
  - **Solution**: Move `jsonEncode`/`jsonDecode` + UTF-8 conversion for large section payloads onto the background worker isolate.

---

### D) Findings as a Security Expert

- [x] **21.13 Stop retaining raw plaintext master password in `_UnlockedVaultSession`**
  - **Finding**: `DefaultVaultService._unlockedSessions` (`lib/application/services/default_vault_service.dart:1834-1884, 2012-2024`) still stores the plaintext `password` string in `_UnlockedVaultSession.password` for the entire unlocked session even after `vaultKey` is unwrapped, and `_passwordController.text` keeps it in UI controller state.
  - **Solution**: Store a keyed/salted SHA-256 verifier (e.g., `Sha256(kdf.salt + password)`) in `_UnlockedVaultSession` instead of the raw password string, and clear `_passwordController` after unlock (relying on `vaultKey` in `_unlockedSessions` for session persistence).

- [x] **21.14 Make `note-recovery-phrase` seeding opt-in & harden `RecoveryScreen`**
  - **Finding**: `OnboardingFlow` (`lib/features/onboarding/presentation/onboarding_flow.dart:2303-2351`) and `VaultAppShell` (`lib/features/vault/presentation/vault_app_shell.dart:380-386`) automatically seed the 12-word recovery phrase as a plaintext note inside the vault, and `RecoveryScreen` exposes the phrase in `SelectableText`.
  - **Solution**: Make saving the recovery phrase as an in-vault note opt-in (default off with clear offline-storage guidance) and review `SelectableText` usage on `RecoveryScreen`.

- [x] **21.15 Enforce master-password re-authentication on "Clear Data" & complete Web/snapshot wipe**
  - **Finding**: Linked to `21.3`: `_clearAllLocalVaultData` does not require master-password confirmation before wiping, and leaves `nija_snapshots/<vaultId>`, `SharedPreferences` keys, and Web IndexedDB vault records behind.
  - **Solution**: Prompt for master password (or explicit destructive verification) before wiping and ensure complete removal across all local stores (native files, snapshots, `SharedPreferences`, and Web IndexedDB).

- [x] **21.16 Tighten Web CSP to remove `'unsafe-inline'` in `script-src`**
  - **Finding**: `web/index.html:26` and `web/_headers:2` include `'unsafe-inline'` in `script-src` and `style-src`, reducing XSS defense-in-depth for a browser-hosted password manager.
  - **Solution**: Move any inline scripts/styles to external files or explicit SHA-256 CSP hashes so `'unsafe-inline'` can be removed from `script-src`.

- [x] **21.17 Upgrade native biometric storage to hardware-bound biometric ACLs**
  - **Finding**: `BiometricCredentialStore` (`lib/core/security/biometric_credential_store.dart:13`) uses `AndroidOptions(encryptedSharedPreferences: true)` and `KeychainAccessibility.unlocked_this_device`, which protects credentials when the device is locked, but does not cryptographically bind key release to `BiometricPrompt` `CryptoObject` / Keychain `biometryCurrentSet`.
  - **Solution**: Evaluate migrating native biometric secret wrapping to a biometric-bound Android Keystore / iOS Keychain `biometryCurrentSet` item so OS-level unlock alone cannot release the stored master password.

- [x] **21.18 Review `Falcon` and `Owl` Argon2id memory parameters against OWASP minimums**
  - **Finding**: `GuardianProfiles` (`lib/core/config/guardian_profiles.dart`) configures `Falcon` (`4096 KB`, `1` iter) and `Owl` (`8192 KB`, `2` iters), which remain below OWASP Argon2id minimums (19–46 MiB).
  - **Solution**: Benchmark 19 MiB+ Argon2id parameters on target low/mid-end Android/iOS/Web devices and raise `Owl` (default) / `Falcon` minimums if unlock latency remains acceptable.


## Section 22: Independent Review v3 — E2E, Stress & Web/Android Release Findings & Solutions

Third-pass pre-release review with live **E2E UI/UX flow & stress testing** targeting **Web** and **Android** release readiness.
- **Baseline**: `flutter analyze` (0 issues), `flutter test` (259 / 259 passing).
- **Stress Benchmark (500 items, 100 notes, 50 folders, 15 MB chunked documents with real Argon2id + AES-256-GCM + `FilePrivateVaultStore`)**:
  - `createVault` (19 MiB Owl): 386 ms
  - `persistVaultDocumentStream` (15 MB / 15 chunks): 2,440 ms
  - `persistVaultPayload` (500 items): 463 ms; second `persistVaultPayload`: 303 ms
  - `readVaultInternals`: 4 ms; `exportVault` (NIJA V2): 55 ms
  - Cold `unlockVault` + `readVaultPayload`: 211 ms; `readVaultDocument` (5 MB): 479 ms

---

### A) UI/UX & User Findings (Web & Android)

- [x] **22.1 Fix 58 px `RenderFlex` horizontal overflow in `AddVaultItemScreen` and `DocumentUploadScreen` folder dropdowns**
  - **Finding**: On a `430×932` mobile viewport, `DropdownButtonFormField<String>` in `lib/features/vault/presentation/add_vault_item_screen.dart:625` (`item-folder-dropdown-default`) overflows horizontally by 58 px because `isExpanded: true` is missing and the `'Create new folder...'` `Row` item sizes the dropdown wider than its `Row`/`Expanded` container. The same missing `isExpanded: true` exists in `lib/features/vault/presentation/document_upload_screen.dart:297` (`document-folder-dropdown-$_selectedFolderId`).
  - **Solution**: Set `isExpanded: true` on both `DropdownButtonFormField<String>` widgets and verify zero layout overflow in mobile (`430×932`) widget tests.

- [x] **22.2 Add inline master-password requirement hint on `SetupScreen`**
  - **Finding**: In `SetupScreen` (`lib/features/onboarding/presentation/onboarding_flow.dart:5671`), `create-encrypted-vault-button` remains disabled until `VaultValidators.isStrongEnoughMasterPassword` passes (`>= 10` chars with letters and numbers), but `SetupScreen` does not show inline validation feedback on the password field, leaving users unsure why the button is disabled for passwords like `"password1"`.
  - **Solution**: Display inline `helperText` (`'Use 10+ characters with letters and numbers'`) when the entered password is non-empty and does not yet satisfy `VaultValidators.isStrongEnoughMasterPassword`.

- [x] **22.3 Clarify Web Cloud Backup & export-only storage behavior**
  - **Finding**: Local rolling snapshots are intentionally hidden on Web (`!kIsWeb`), and Web users only see the `Web storage` row under Settings -> Data. Adding a brief note under Web Cloud Backup/Settings clarifies that automatic local rolling snapshots are mobile/desktop-only.
  - **Solution**: Keep Web storage guidance clear and verify Web build (`flutter build web`) compiles cleanly without `dart:io` or `dart:isolate` errors.

---

### B) Technical Validator & Tester Findings (Web & Android)

- [x] **22.4 Update stale `integration_test/` selectors and verify Android/Web targets**
  - **Finding**: `integration_test/e2e_full_flow_test.dart` references outdated UI labels (`'Choose Guardian'`, `'Vault'`, `'Types'`) and omits `firstInstallWalkthroughCompletedOverride`. Additionally, `flutter test -d macos` is blocked on machines without Xcode, whereas **Web** and **Android** are the active release targets.
  - **Solution**: Update `integration_test/e2e_full_flow_test.dart` selectors to match current UI (`'Create your vault'`, `'Home'`, `'All Items'`, `'Folders'`, `'Settings'`) and verify Web (`flutter build web`) and Android (`flutter build apk --debug`) builds pass cleanly.

- [x] **22.5 Verify Google OAuth release configuration for Android & Web**
  - **Finding**: `GoogleOAuthConfig.nativeServerClientId` (`lib/core/config/google_oauth_config.dart:19-22`) defaults to `''`. Android Drive backup/restore requires the installed build's SHA-1 fingerprint and OAuth client configured in Google Cloud Console (`NIJA_GOOGLE_NATIVE_SERVER_ID` / `NIJA_GOOGLE_WEB_CLIENT_ID`).
  - **Solution**: Document and verify `--dart-define` / OAuth client setup in release build checks.

---

### C) Performance Test Findings

- [x] **22.6 Avoid one-off `compute()` isolate spawn jitter on medium JSON payloads & keep `_dashboardInputSignature` `O(1)` at 5,000+ items**
  - **Finding**: `DefaultVaultService._decryptSection` and `_encryptJson` spawn one-off `compute()` isolates for payloads > 32 KB / > 50 items instead of reusing the persistent worker or raising the threshold to avoid spawn jitter on 1s note autosaves. `VaultAppShell._dashboardInputSignature` (`vault_app_shell.dart:1750`) also hashes `_items` and `_notes` on builds (fast at 500 items, linear at 5,000+ items).
  - **Solution**: Raise the JSON `compute()` threshold to avoid spawning isolates for small/medium payloads (~100 KB / 200 entries) and invalidate `_dashboardDataCache` explicitly on in-place item/type mutations so `_dashboardInputSignature` stays `O(1)`.

---

### D) Security Findings (Web & Android)

- [x] **22.7 Evaluate Web CSP `script-src` `'unsafe-inline'` removal**
  - **Finding**: `web/index.html:26` and `web/_headers:2` removed `'unsafe-inline'` from `style-src` via `web/nija_boot.css`, while `script-src` retains `'unsafe-inline'` for Flutter's `flutter_bootstrap.js` loader.
  - **Solution**: Evaluate nonce/hash-based `flutter_bootstrap.js` configuration for hosting environments where strict `script-src` without `'unsafe-inline'` is supported.

- [x] **22.8 Evaluate Android Keystore `BiometricPrompt` `CryptoObject` binding & opt-in recovery note**
  - **Finding**: `BiometricCredentialStore` (`lib/core/security/biometric_credential_store.dart:13`) uses `AndroidOptions(encryptedSharedPreferences: true)` rather than a hardware `BiometricPrompt` `CryptoObject` key, and `RecoveryScreen` (`onboarding_flow.dart`) defaults `saveCopyInVault` to `true` for test compatibility.
  - **Solution**: Consider defaulting `saveCopyInVault` to `false` on new installs and migrating Android biometric credential wrapping to a `CryptoObject`-bound Keystore key in a future native security update.








