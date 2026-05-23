# Nija — MVP Architecture & Wireframes

## 1. Product Definition

### Brand

# Nija

### Tagline

> Your private digital vault.

### Brand Positioning

Nija is designed to feel:

* Calm
* Private
* Minimal
* Premium
* Personal
* Trustworthy

The product should avoid aggressive cybersecurity branding and instead focus on user ownership, privacy, and simplicity.

**Nija** is a local-first, user-owned encrypted vault app.

The app is not the source of truth. The **vault file** is the source of truth.

The app helps users create, unlock, read, edit, search, and back up their encrypted vault.

### Core Promise

> One encrypted file for your digital life. Store it anywhere. Only you can unlock it.

---

## 2. MVP Scope

### Included in MVP

* Create new vault
* Open existing vault
* Guardian-based protection profile selection
* Master password setup
* Recovery phrase setup
* Unlock vault
* Biometric unlock placeholder
* Vault dashboard
* Search vault items
* Store login credentials
* Store card details
* Store identity details
* Store rich secure notes/documents
* View/hide sensitive fields
* Copy secure fields
* Categories/types screen
* Settings screen
* Export/backup placeholder
* Auto-lock concept

### Not Included in MVP

* Browser extension
* Autofill
* Real-time sync
* Custom backend
* Team sharing
* Passkeys
* Breach monitoring
* Attachments
* AI assistant
* Enterprise admin

---

## 3. Product Architecture

```text
Mobile App
  |
  |-- UI Layer
  |     |-- Onboarding
  |     |-- Unlock
  |     |-- Dashboard
  |     |-- Vault Items
  |     |-- Rich Notes
  |     |-- Settings
  |
  |-- Application Services
  |     |-- VaultService
  |     |-- ItemService
  |     |-- NoteService
  |     |-- SearchService
  |     |-- BackupService
  |     |-- SecurityService
  |
  |-- Domain Layer
  |     |-- Vault
  |     |-- GuardianProfile
  |     |-- VaultItem
  |     |-- SecureNoteDocument
  |     |-- Field
  |
  |-- Infrastructure Layer
        |-- CryptoAdapter
        |-- FileStorageAdapter
        |-- SecureDeviceStorageAdapter
        |-- ClipboardAdapter
        |-- BiometricAdapter
```

### Recommended App Architecture

Use a **modular monolith** inside the mobile app.

Avoid backend-first or microservice architecture. The MVP should be simple, local-first, and maintainable.

---

## 4. Recommended Tech Stack

### Mobile App

**Flutter** is recommended for production MVP.

Why:

* One codebase for Android and iOS
* Strong mobile UI performance
* Good file access support
* Good biometric support
* Good long-term maintainability
* Faster MVP than fully native builds

Alternative: React Native, only if the team is much stronger in TypeScript.

### Web Prototype

Use React for prototyping only.

The current web prototype is useful for validating:

* Navigation
* Information architecture
* Guardian onboarding
* Notes model
* Vault item UX

It should not define the final production architecture.

### Storage

* Vault data: encrypted vault file
* Temporary metadata: in-memory only where possible
* Device-bound unlock helper: iOS Keychain / Android Keystore
* Avoid storing decrypted vault contents in SQLite

### Crypto

Recommended:

* Key derivation: Argon2id
* Encryption: XChaCha20-Poly1305
* Random vault key
* Master-password-derived key wraps the vault key
* Authenticated encryption for tamper detection

---

## 5. Vault File Architecture

The vault is a single portable file.

Example filename:

```text
my-vault.nija
```

### File Structure

```json
{
  "format": "Nija",
  "formatVersion": 1,
  "vaultId": "uuid",
  "createdAt": "2026-05-06T10:00:00Z",
  "updatedAt": "2026-05-06T10:00:00Z",
  "guardian": {
    "id": "owl",
    "profile": "owl_v1"
  },
  "kdf": {
    "name": "argon2id",
    "version": 19,
    "memoryKb": 65536,
    "iterations": 4,
    "parallelism": 2,
    "salt": "base64"
  },
  "cipher": {
    "name": "xchacha20-poly1305",
    "nonce": "base64"
  },
  "encryptedVaultKey": "base64",
  "encryptedPayload": "base64"
}
```

### Important Rule

The header is not secret.

It may safely store:

* Vault format version
* Guardian profile
* KDF parameters
* Salt
* Cipher name
* Nonce
* Encrypted vault key

It must never store:

* Master password
* Raw derived key
* Raw vault key
* Recovery phrase
* Decrypted data

---

## 6. Encryption Flow

### Create Vault

```text
User chooses Guardian
User creates master password
Generate random vault key
Derive password key using Argon2id
Encrypt vault key with password key
Encrypt vault payload with vault key
Write vault header + encrypted payload to file
```

### Unlock Vault

```text
Read vault header
Identify Guardian profile
Read KDF parameters
User enters master password
Derive password key
Decrypt vault key
Decrypt payload
Load vault data into memory
```

### Change Master Password

```text
Unlock vault with old password
Derive new password key
Re-encrypt vault key with new password key
Update vault header
Save vault file
```

This avoids re-encrypting every vault item.

---

## 7. Guardian Profiles

Guardians are user-friendly names for versioned crypto profiles.

They are not secrets and should not be required for unlock.

| Guardian | Purpose       | Profile   | User Meaning                 |
| -------- | ------------- | --------- | ---------------------------- |
| Owl      | Default       | owl_v1    | Balanced everyday protection |
| Lion     | High security | lion_v1   | Maximum protection           |
| Falcon   | Fast access   | falcon_v1 | Faster daily unlock          |

### Example Profile Mapping

```json
{
  "owl_v1": {
    "kdf": "argon2id",
    "memoryKb": 65536,
    "iterations": 4,
    "parallelism": 2,
    "cipher": "xchacha20-poly1305"
  },
  "lion_v1": {
    "kdf": "argon2id",
    "memoryKb": 262144,
    "iterations": 5,
    "parallelism": 2,
    "cipher": "xchacha20-poly1305"
  },
  "falcon_v1": {
    "kdf": "argon2id",
    "memoryKb": 32768,
    "iterations": 3,
    "parallelism": 2,
    "cipher": "xchacha20-poly1305"
  }
}
```

---

## 8. Domain Data Model

### Vault Payload

Encrypted payload after unlock:

```json
{
  "schemaVersion": 1,
  "items": [],
  "notes": [],
  "tags": [],
  "settings": {},
  "audit": []
}
```

### Vault Item

```json
{
  "id": "uuid",
  "type": "login",
  "title": "Google Account",
  "subtitle": "personal@gmail.com",
  "fields": [
    {
      "id": "uuid",
      "label": "Username",
      "value": "personal@gmail.com",
      "sensitive": false
    },
    {
      "id": "uuid",
      "label": "Password",
      "value": "secret",
      "sensitive": true
    }
  ],
  "tags": ["personal"],
  "createdAt": "date",
  "updatedAt": "date"
}
```

### Rich Secure Note

Do not store rich notes as raw HTML.

Store them as structured blocks.

```json
{
  "id": "uuid",
  "type": "document",
  "title": "Private Travel Checklist",
  "preview": "Passport, backup card, insurance...",
  "blocks": [
    {
      "type": "heading",
      "text": "Private Travel Checklist"
    },
    {
      "type": "paragraph",
      "text": "Keep encrypted vault backup before travel."
    },
    {
      "type": "check",
      "text": "Passport copy",
      "checked": true
    },
    {
      "type": "bullet",
      "text": "Backup card"
    },
    {
      "type": "quote",
      "text": "Do not store recovery phrase in screenshots."
    }
  ],
  "createdAt": "date",
  "updatedAt": "date"
}
```

---

## 9. Security Architecture

### Threat Model

Assume attacker may have:

* The vault file
* Cloud backup copy
* Lost/stolen phone
* App binary
* Knowledge of vault format

The attacker should still not decrypt data without the master password or recovery key.

### Protect Against

* Stolen vault file
* Cloud provider breach
* Offline brute force
* Casual phone theft
* Accidental plaintext export
* Clipboard exposure
* Screenshot/app switcher leaks

### Hard to Protect Against Fully

* Rooted/jailbroken devices
* Malware/keyloggers
* Compromised OS
* Active memory inspection
* Shoulder surfing

### Security Controls

* Argon2id key derivation
* XChaCha20-Poly1305 authenticated encryption
* Random vault key
* Device keystore/keychain for biometric unlock helper
* Auto-lock on background
* Clipboard auto-clear
* Screenshot protection where supported
* No plaintext backups
* No sensitive logs
* No secrets in crash reports

---

## 10. MVP User Flows

### Flow 1 — Create Vault

```text
Welcome
  ↓
Choose Guardian
  ↓
Create Master Password
  ↓
Save Recovery Phrase
  ↓
Vault Created
  ↓
Unlock Vault
  ↓
Dashboard
```

### Flow 2 — Open Existing Vault

```text
Welcome
  ↓
Open Existing Vault
  ↓
Select Vault File
  ↓
Read Header
  ↓
Show Guardian
  ↓
Enter Master Password
  ↓
Dashboard
```

### Flow 3 — Add Login Item

```text
Dashboard
  ↓
Add Button
  ↓
Choose Login
  ↓
Enter title, username, password, website
  ↓
Save
  ↓
Encrypted payload updated
```

### Flow 4 — Add Secure Note Document

```text
Notes Tab
  ↓
Add Note
  ↓
Document Editor
  ↓
Use rich blocks
  ↓
Save
  ↓
Encrypted payload updated
```

### Flow 5 — View Sensitive Field

```text
Item Detail
  ↓
Sensitive field masked
  ↓
Tap view
  ↓
Reveal value
  ↓
Optional copy
  ↓
Clipboard auto-clears
```

---

## 11. Wireframes

### 11.1 Welcome

```text
┌─────────────────────────┐
│ ◆                       │
│                         │
│ Private vault           │
│                         │
│ Your digital life,      │
│ locked in one file.     │
│                         │
│ A portable encrypted    │
│ vault for passwords,    │
│ notes, cards, identity. │
│                         │
│ ✓ Zero-knowledge        │
│ ✓ Local-first           │
│ ✓ Portable vault file   │
│                         │
│ [ Create vault ]        │
│ [ Open existing vault ] │
└─────────────────────────┘
```

### 11.2 Guardian Setup

```text
┌─────────────────────────┐
│ Step 1 of 2             │
│ Choose Guardian         │
│                         │
│ ┌─────────────────────┐ │
│ │ 🦉 Owl              │ │
│ │ Balanced protection │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ 🦁 Lion             │ │
│ │ Maximum protection  │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ 🦅 Falcon           │ │
│ │ Fast daily unlock   │ │
│ └─────────────────────┘ │
│                         │
│ Master password         │
│ Confirm password        │
│                         │
│ [ Create encrypted vault ]
└─────────────────────────┘
```

### 11.3 Recovery Phrase

```text
┌─────────────────────────┐
│ Step 2 of 2             │
│ Recovery phrase         │
│                         │
│ Save this offline.      │
│                         │
│ ┌─────────────────────┐ │
│ │ 1. orbit  2. stone  │ │
│ │ 3. river  4. falcon │ │
│ │ ...                 │ │
│ └─────────────────────┘ │
│                         │
│ Never store in screenshots.
│                         │
│ [ I saved my phrase ]   │
│ [ Print recovery sheet ]│
└─────────────────────────┘
```

### 11.4 Unlock

```text
┌─────────────────────────┐
│                         │
│          🦉             │
│                         │
│      Unlock vault       │
│  Protected by Owl       │
│                         │
│ Master password         │
│                         │
│ [ Unlock ]              │
│ [ Use biometrics ]      │
│                         │
│ Vault auto-locks in bg. │
└─────────────────────────┘
```

### 11.5 Dashboard

```text
┌─────────────────────────┐
│ Owl Guardian        ⚙   │
│ Vault                   │
│                         │
│ Search                  │
│                         │
│ ┌─────────────────────┐ │
│ │ Vault health: Good  │ │
│ │ Recovery not printed│ │
│ └─────────────────────┘ │
│                         │
│ Items                3  │
│ ┌─────────────────────┐ │
│ │ ⌘ Google Account    │ │
│ │ personal@gmail.com  │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ 💳 Primary Card     │ │
│ │ Visa ending 4208    │ │
│ └─────────────────────┘ │
│                         │
│      [+]                │
│ Vault Notes Types Settings
└─────────────────────────┘
```

### 11.6 Item Detail

```text
┌─────────────────────────┐
│ ‹                   Edit│
│                         │
│ ⌘                       │
│ Google Account          │
│ Login · Updated Today   │
│                         │
│ Username                │
│ personal@gmail.com   ⧉  │
│                         │
│ Password                │
│ ••••••••••••   👁   ⧉  │
│                         │
│ Website                 │
│ accounts.google.com ⧉  │
│                         │
│ Clipboard clears in 30s │
└─────────────────────────┘
```

### 11.7 Notes List

```text
┌─────────────────────────┐
│ Encrypted writing    +  │
│ Notes                   │
│                         │
│ Search notes            │
│                         │
│ Notes are stored inside │
│ the encrypted vault.    │
│                         │
│ ┌─────────────────────┐ │
│ │ Recovery Instructions│ │
│ │ Keep printed sheet...│ │
│ │ Updated 3 days ago  │ │
│ └─────────────────────┘ │
│                         │
│ Vault Notes Types Settings
└─────────────────────────┘
```

### 11.8 Rich Note Detail

```text
┌─────────────────────────┐
│ ‹                   Edit│
│                         │
│ ✎                       │
│ Recovery Instructions   │
│ Rich Secure Document    │
│                         │
│ ┌─────────────────────┐ │
│ │ Recovery Instructions│ │
│ │                     │ │
│ │ Keep printed sheet. │ │
│ │ ☑ Print sheet       │ │
│ │ ☐ Store sealed copy │ │
│ │                     │ │
│ │ ❝ If password lost...│ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

### 11.9 Rich Note Editor

```text
┌─────────────────────────┐
│ ‹                   Save│
│                         │
│ Document title          │
│                         │
│ [H] [B] [I] [•] [☑] [❝]│
│                         │
│ ┌─────────────────────┐ │
│ │ Heading             │ │
│ │                     │ │
│ │ Start writing...    │ │
│ │ • Add bullet points │ │
│ │ ☐ Add checklist     │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

### 11.10 Settings

```text
┌─────────────────────────┐
│ Vault preferences       │
│ Settings                │
│                         │
│ Security              › │
│ Vault Backup          › │
│ Biometric Unlock      › │
│ Recovery Phrase       › │
│ Auto Lock             › │
│ Export Vault          › │
│ Danger Zone           › │
│                         │
│ Vault Notes Types Settings
└─────────────────────────┘
```

---

## 12. MVP Engineering Modules

### VaultService

Responsibilities:

* Create vault
* Open vault
* Lock vault
* Unlock vault
* Save vault
* Change password
* Read vault header
* Validate vault version

### CryptoService

Responsibilities:

* Generate vault key
* Derive password key
* Encrypt vault key
* Decrypt vault key
* Encrypt payload
* Decrypt payload
* Verify authentication tag

### ItemService

Responsibilities:

* Create item
* Edit item
* Delete item
* Read item
* Toggle sensitive field visibility in UI state

### NoteService

Responsibilities:

* Create document note
* Edit document note
* Render blocks
* Validate block structure
* Generate note preview

### SearchService

Responsibilities:

* In-memory search after unlock
* Search item titles, subtitles, fields
* Search note titles, previews, body text
* Do not persist plaintext index in MVP

### SecurityService

Responsibilities:

* Auto-lock timer
* Lock on app background
* Clipboard auto-clear
* Screenshot protection
* Biometric unlock state

### StorageService

Responsibilities:

* Read vault file
* Write vault file atomically
* Export vault file
* Import vault file
* Detect file conflicts later

---

## 13. Save Strategy

Use atomic writes.

```text
1. Encrypt updated payload
2. Write to temp file
3. Verify temp file can be read
4. Replace old vault file
5. Keep last known good backup pointer
```

This reduces corruption risk.

---

## 14. Backup Strategy

MVP backup should be simple:

* Export encrypted vault file
* Let user choose location
* Never export plaintext
* Show last backup time
* Warn if no backup exists

Future:

* iCloud/Google Drive/Dropbox picker
* Conflict detection
* Version history
* Encrypted recovery kit

---

## 15. Recommended MVP Build Order

### Phase 1 — Core Vault

1. Vault file format
2. Crypto profile registry
3. Create vault
4. Unlock vault
5. Save encrypted payload
6. Lock vault

### Phase 2 — Data Features

1. Vault items CRUD
2. Sensitive field reveal/copy
3. Search
4. Rich secure notes
5. Categories/types

### Phase 3 — Security UX

1. Auto-lock
2. Clipboard clear
3. Biometric unlock
4. Screenshot protection
5. Recovery phrase flow

### Phase 4 — Backup

1. Export vault
2. Import vault
3. Local file picker
4. Backup reminders

---

## 16. Key Product Decisions

### Decision 1 — Single Vault File

Best for privacy, ownership, portability, and low operating cost.

### Decision 2 — No Backend in MVP

Avoids trust burden, cost, and complexity.

### Decision 3 — Guardians as Profiles

Good UX abstraction without compromising cryptographic transparency.

### Decision 4 — Rich Notes as Blocks

Avoid raw HTML. Structured blocks are safer, cleaner, searchable, and easier to migrate.

### Decision 5 — Search Only After Unlock

Keeps MVP simpler and avoids plaintext search index leakage.

---

## 17. Final Product Decisions

### Decision 1 — Recovery Phrase Model

Use the recovery phrase as a **secondary key-wrapping method**.

The recovery phrase should be able to decrypt the vault key if the master password is forgotten.

Recommended structure:

```text
Random Vault Key
  ├─ encrypted by password-derived key
  └─ encrypted by recovery-phrase-derived key
```

This means the recovery phrase is powerful and must be treated like the master password.

UX copy:

> Anyone with this recovery phrase can unlock your vault. Store it offline.

---

### Decision 2 — Guardian Profiles

A vault should use one active Guardian profile at a time.

Future upgrades should be handled through **profile migration**.

Example:

```text
owl_v1 → owl_v2
lion_v1 → lion_v2
```

Do not allow multiple active Guardians in MVP. It creates unnecessary complexity.

---

### Decision 3 — Notes and Items Navigation

Use separate bottom tabs:

```text
Vault | Notes | Types | Settings
```

Reason:

* Password/card items are action-oriented.
* Notes are reading/writing-oriented.
* Separate tabs reduce clutter.
* Unified search can come later.

---

### Decision 4 — Storage in First Production MVP

Support:

* Local app storage
* Manual export
* Manual import
* User-selected file location if platform allows

Delay direct Google Drive, iCloud, Dropbox, and OneDrive integrations until after the core vault is reliable.

Reason:

* Cloud picker/sync creates conflict and support complexity.
* The strongest MVP promise is local-first ownership.

---

### Decision 5 — Web App

Delay production web app.

Use web only for prototype and product validation.

Reason:

* Mobile is the natural first-use context.
* Web vault handling increases attack surface.
* Browser security expectations are higher.
* Desktop/web can come after mobile trust is established.

---

## 18. Final MVP Feature List

### Onboarding

* Welcome screen
* Create vault
* Open existing vault placeholder
* Guardian selection
* Master password setup
* Recovery phrase display
* Vault created confirmation

### Unlock & Security

* Master password unlock
* Biometric unlock placeholder
* Auto-lock messaging
* Guardian display on unlock
* Sensitive value reveal/hide
* Clipboard copy action
* Clipboard clear reminder

### Vault Items

* Login item
* Card item
* Identity item
* Custom fields later
* Item detail view
* Masked sensitive fields
* Copy field value
* Edit placeholder

### Rich Secure Notes

* Notes list
* Notes search
* Rich document detail
* Rich document editor placeholder
* Supported blocks:

  * Heading
  * Paragraph
  * Bullet
  * Checklist
  * Quote

### Organization

* Types/categories screen
* Dashboard search
* Notes search

### Settings

* Security
* Vault backup
* Biometric unlock
* Recovery phrase
* Auto lock
* Export vault
* Danger zone

---

## 19. Screen Acceptance Criteria

### Welcome

* User understands the app stores data in a portable encrypted vault file.
* Primary CTA is Create Vault.
* Secondary CTA is Open Existing Vault.

### Guardian Setup

* User can choose Owl, Lion, or Falcon.
* Guardian profile details are visible.
* Master password and confirmation fields are present.
* User is warned that password/recovery loss means data loss.

### Recovery Phrase

* User sees a recovery phrase.
* User is warned not to screenshot or store it digitally.
* User must confirm they saved it before proceeding.

### Unlock

* User sees which Guardian protects the vault.
* User can enter master password.
* Biometric unlock is visible as future/optional path.

### Dashboard

* User sees vault health.
* User can search vault items.
* User can open an item.
* User can add a new item.

### Item Detail

* Sensitive fields are masked by default.
* User can reveal/hide each sensitive field.
* User can copy each field.
* Clipboard safety message is visible.

### Notes

* User can see secure notes/documents.
* User can search notes.
* User can open note detail.
* User can create a new rich note.

### Rich Note Detail

* User sees structured document blocks.
* Heading, paragraph, checklist, bullet, and quote blocks render clearly.
* User understands notes are encrypted inside the vault.

### Settings

* User can access security, backup, biometric, recovery, auto-lock, export, and danger-zone settings.

---

## 20. Flutter Production Stack

### Core App

* Flutter
* Dart
* Riverpod or Bloc for state management
* GoRouter for navigation

Recommended default: **Riverpod + GoRouter**.

Reason:

* Simple dependency management
* Testable services
* Clean navigation
* Good fit for modular monolith architecture

### Crypto

Recommended approach:

* Use vetted native crypto bindings or audited packages.
* Prefer libsodium-compatible XChaCha20-Poly1305 support.
* Use Argon2id implementation with configurable memory/iterations.

Avoid:

* Custom crypto implementation
* Hand-rolled random generation
* Storing keys in shared preferences

### Device Security

* iOS Keychain
* Android Keystore
* local_auth for biometric prompt
* flutter_secure_storage for small device-bound secrets only

### File Storage

* path_provider
* file_picker
* permission_handler only if required
* Atomic file write utility

### UI

* Native Flutter widgets
* Minimal custom design system
* No heavy UI framework initially

### Testing

* Unit tests for crypto profile registry
* Unit tests for vault file parser
* Unit tests for note block validation
* Widget tests for unlock/dashboard/item detail
* Golden tests later for critical screens

---

## 21. Beta Security Checklist

Before any beta release:

### Crypto

* [ ] No custom crypto algorithms
* [ ] Argon2id parameters are stored in vault header
* [ ] Salt is unique per vault
* [ ] Nonce is unique per encryption
* [ ] Vault key is random
* [ ] Payload uses authenticated encryption
* [ ] Tampered vault fails to unlock
* [ ] Wrong password fails safely

### Secrets

* [ ] Master password is never stored
* [ ] Raw vault key is never persisted unwrapped
* [ ] Recovery phrase is never logged
* [ ] Decrypted payload is not written to disk
* [ ] Crash reports exclude sensitive values

### Runtime

* [ ] Vault locks when app backgrounds
* [ ] Clipboard clears after timeout
* [ ] Screenshot protection enabled where supported
* [ ] App switcher preview is blurred/hidden
* [ ] Sensitive fields are masked by default

### Storage

* [ ] Export is always encrypted
* [ ] Import validates format version
* [ ] Atomic write prevents corrupt vault replacement
* [ ] Last known good vault backup strategy exists

### UX

* [ ] Recovery warning is clear
* [ ] User understands company cannot restore lost vault
* [ ] Guardian details are transparent enough for trust
* [ ] No “unhackable” marketing language

---

## 22. Final Build Plan

### Milestone 1 — Vault Core

* Implement vault schema
* Implement Guardian registry
* Implement create vault
* Implement unlock vault
* Implement save/load encrypted payload

### Milestone 2 — MVP Data

* Implement vault item model
* Implement item CRUD
* Implement rich note block model
* Implement note CRUD
* Implement dashboard and notes search

### Milestone 3 — Security UX

* Auto-lock
* Clipboard clear
* Biometric unlock helper
* Screenshot/app switcher protection
* Recovery phrase flow

### Milestone 4 — Backup & Release Readiness

* Export encrypted vault
* Import encrypted vault
* Atomic writes
* Corruption handling
* Beta security checklist
* Internal test release

---

## 23. Final Recommendation

## 23. Brand Identity

### Product Name

# Nija

### Tagline

> Your private digital vault.

### Tone

The app tone should feel:

* Calm
* Reassuring
* Minimal
* Human
* Quiet confidence

Avoid:

* “Military-grade” language
* Hacker/cyberpunk branding
* Fear-based messaging
* Overly technical onboarding copy

### UI Direction

Preferred visual style:

* Warm black
* Soft white
* Muted slate grays
* Minimal accent colors
* Rounded corners
* Clean typography
* Spacious layouts

### Product Positioning

Nija is not positioned primarily as a password manager.

Nija is positioned as:

> A private encrypted vault for your digital life.

### Guardian Positioning

Guardians remain protection profiles inside Nija.

Examples:

```text
Protected by Owl Guardian
inside Nija
```

```text
Nija
Protected by Lion Guardian
```

---

## 24. Final Recommendation

Proceed with the MVP as:

> A Flutter mobile app with a single encrypted portable vault file, Guardian-based crypto profiles, password/card/identity storage, rich secure notes, local-first backup/export, and no backend.

This is the simplest version that delivers real customer value while preserving the strongest product differentiator: **user-owned encrypted data**.
