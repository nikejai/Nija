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
- [x] Add release hardening gates.
  - Security review checklist.
  - Production configuration checks (logging, debug flags, crash surfaces).
  - Final pre-release validation pass across Android/iOS/Web.
- [x] Add multi-vault selection and import flow.
  - Added vault picker before unlock when user taps `Open existing vault`.
  - Added known-vault cache persisted in app storage.
  - Added vault import/add flow per platform (web upload, mobile/desktop file picker).
- [x] Add vault last-opened metadata and sorting in vault picker.
  - Vault references now persist `lastOpenedAt` and vault picker list is sorted by most recently opened first.

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

- [ ] Add app-level feature gating boolean(s) for `free` vs `paid` version behavior.
  - Centralize in config so UI + actions can check the same source of truth.
  - Keep paid features disabled by default unless paid mode is enabled.
- [ ] Add first paid feature: Google backup integration (paid-only).
  - Show backup entry as disabled in free mode.
  - Show hint text: `Available in paid version`.
  - Added build-gated cloud-backup toggle in Settings (`NIJA_PAID_BUILD`): Android label `Backup to Google Drive`, iOS label `Backup to iCloud`, disabled in free build with paid hint text.
  - Implemented paid-build `Backup now` action via native share sheet to save encrypted vault file into Google Drive/iCloud Drive.

## 12) Mobile Share-Into-Notes Flow

- [ ] Add mobile text share-intent ingestion so Nija appears in share sheet and can import shared text into the selected vault as a note.
  - When user shares text to Nija, create a note with:
    - Title format: `Shared from <ApplicationName> datetime`.
    - Tag will be application name , shared 
    - Body containing the full shared text.
    - Timestamp metadata (shared/import time).
  - Route to vault selection when needed, then save into the chosen vault.

## 13) Release Readiness Fixes

- [x] Clean up `vault_app_shell.dart` analyzer issues.
  - Goal: `flutter analyze` passes with zero issues.
  - Scope: unused fields/methods, deprecated `WillPopScope`, unnecessary casts, and related analyzer warnings.
- [ ] Fix onboarding create-vault/recovery widget tests.
  - Goal: onboarding tests reliably reach `Recovery phrase` and `I saved my phrase`.
  - Scope: update test helpers or UI flow assumptions around vault-name/password fields and async create flow.
- [ ] Fix note editor widget test localization setup.
  - Goal: note editor tests pass without `MissingFlutterQuillLocalizationException`.
  - Scope: add `FlutterQuillLocalizations.delegate` to test app setup or shared test harness.
- [ ] Update stale vault shell widget tests for current UI.
  - Goal: `test/vault_shell_test.dart` passes against the current app navigation/actions.
  - Scope: update tests expecting old `Custom templates`, `All types`, note action keys, selection/share actions, and related labels.
- [ ] Re-run release readiness gates.
  - Goal: `./scripts/release_hardening_gate.sh`, `flutter test`, and `flutter build apk --release` all pass.

## 14) Vault App Shell File Split

- [x] Move encrypted import/share UI out of `vault_app_shell.dart`.
  - Goal: keep vault shell focused on orchestration, not import bundle screens.
  - Scope: move `_EncryptedShareChoice`, `_EncryptedImportEntry`, `_PreparedVaultImport`, `_EncryptedShareInputDialog`, `_EncryptedImportBundleScreen`, `_EncryptedImportEntryPreviewScreen`, `_ImportPreviewHeader`, `_ImportPreviewRow`, and import preview helpers into `lib/features/vault/presentation/widgets/encrypted_import_widgets.dart` or a dedicated `encrypted_import/` folder.
- [ ] Move custom template manager into its own screen file.
  - Goal: isolate custom template CRUD from shell navigation.
  - Scope: move `_CustomTemplateManagerScreen` and related state into `lib/features/vault/presentation/custom_template_manager_screen.dart`.
- [ ] Move settings widgets and dialogs into settings-focused files.
  - Goal: keep settings layout reusable and easier to test.
  - Scope: move `_SettingsSection`, `_SettingsRow`, `_SettingsActionRow`, `_AutoLockSecondsSheet`, `_RenameVaultDialog`, `_PasswordStrengthMeter`, and related formatting helpers into `lib/features/vault/presentation/widgets/vault_settings_widgets.dart`.
- [ ] Move document detail UI into a dedicated screen file.
  - Goal: separate document rendering/export logic from the shell.
  - Scope: move `_DocumentDetailScreen`, `_DocumentHeader`, `_DocumentPreviewMessage`, document filename/extension/size/mime helpers, and document payload helpers into `lib/features/vault/presentation/document_detail_screen.dart`.
- [ ] Move item detail and identity photo UI into dedicated files.
  - Goal: separate item viewing/editing and identity photo viewing from shell state.
  - Scope: move `_ItemDetailScreen`, `_IdentityPhotosSection`, `_IdentityFullPhoto`, `_IdentityPhotoPreview`, and identity photo size helpers into `lib/features/vault/presentation/item_detail_screen.dart` plus optional identity photo widget file.
- [ ] Move shared small vault widgets into a common widget file.
  - Goal: reduce noise in shell and reuse visual primitives consistently.
  - Scope: move `_EntryMetadataPanel`, `_EntryMetadataLine`, `_EmptyState`, `_TinyChip`, `_SectionHeader`, `_DebugInfoCard`, `_HomeTypeCard`, `_AllItemsSelectionActionBar`, `_SelectionActionNavItem`, `_AllItemsFiltersOverlay`, `_ActiveFilterChip`, icon/color helpers, and metadata timestamp helpers into focused widget/helper files.
- [ ] Re-run format, analyzer, and targeted widget tests after each split.
  - Goal: keep every extraction behavior-preserving.
  - Scope: run `dart format`, `flutter analyze`, and the most relevant `flutter test` target after each moved group.
