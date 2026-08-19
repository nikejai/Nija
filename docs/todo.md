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
  - Show backup entry as disabled in free mode.
  - Show hint text: `Available in paid version`.
  - Android cloud backup is gated by the Google Play expanded-storage entitlement; `NIJA_PAID_BUILD` remains a development override.
  - Implemented paid-build `Backup now` action via native share sheet to save encrypted vault file into Google Drive/iCloud Drive.
  - Centralized cloud-backup and expanded-storage capability checks in `AppFeatures`, and added free-build regression coverage for the Settings gate.
- [x] Move paid feature unlocks from build-only flags to runtime entitlements.
  - Paid features must be toggleable at runtime based on a locally cached entitlement and the latest Play Billing purchase state.
  - Keep build flags only for development/testing overrides, not as the production source of truth.
  - Centralize runtime entitlement state so Settings UI, backup actions, storage limits, and future paid features all read the same source.
  - Default to free features until a trusted runtime entitlement is loaded.
  - Add tests proving paid UI/actions can unlock and relock without rebuilding the app.
  - Web storage limits are currently client-enforced: new/small vaults cap at 100 MB, and legacy vaults already above 100 MB can continue up to 1 GB until runtime entitlement exists.
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
  - Show current vault crypto metadata in a sanitized form:
    - guardian profile,
    - KDF name (`Argon2id`),
    - KDF memory / iterations / parallelism,
    - cipher name (`AES-256-GCM`),
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
  - Add tests for the Settings row opening the new surface and for sanitized metadata/status rendering.
  - Added bottom sheet with security model explanation, sanitized vault crypto/format metadata, status checks, and security actions.
  - Added recovery-phrase rotation dialog entry point from the security surface.
  - Added widget coverage that verifies sanitized metadata rendering and excludes raw working-store/internal fields.
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
  - Scope: create vault, unlock, lock, recovery unlock, password reset, master/recovery rotation, CRUD persistence after restart, import/export, encrypted secret open-with, document open/share, and paid cloud backup/restore.
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
- [ ] Add WebApp release build steps.
  - Goal: document and validate repeatable release steps for the web app.
  - Scope: add commands for clean Flutter web release build, build artifact location, hosting assumptions, cache headers/service-worker behavior, and release smoke checks.
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
    - `flutter build web --release`,
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
- [ ] Move shared small vault widgets into a common widget file.
  - Goal: reduce noise in shell and reuse visual primitives consistently.
  - Scope: move `_EntryMetadataPanel`, `_EntryMetadataLine`, `_EmptyState`, `_TinyChip`, `_SectionHeader`, `_DebugInfoCard`, `_HomeTypeCard`, `_AllItemsSelectionActionBar`, `_SelectionActionNavItem`, `_AllItemsFiltersOverlay`, `_ActiveFilterChip`, icon/color helpers, and metadata timestamp helpers into focused widget/helper files.
- [ ] Re-run format, analyzer, and targeted widget tests after each split.
  - Goal: keep every extraction behavior-preserving.
  - Scope: run `dart format`, `flutter analyze`, and the most relevant `flutter test` target after each moved group.
