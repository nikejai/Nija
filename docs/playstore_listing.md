# Nija — Google Play Store Listing & ASO Reference

This document stores the Google Play Store metadata, ASO/SEO copy, screenshot mapping, and release checklist for **Nija** (`com.nija`).

---

## 1. App Title & Short Description (Subtext)

### App Name (Max 30 characters)

- **Primary**: `Nija: Offline Password Vault` *(29 chars)*
- **Alternative 1**: `Nija – Private Vault & Notes` *(28 chars)*
- **Alternative 2**: `Nija: Encrypted Local Vault` *(27 chars)*

### Short Description / Subtext (Max 80 characters)

- **Primary**: `Local-first encrypted password manager, secure notes, IDs & PDF document vault.` *(79 chars)*
- **Alternative 1**: `Offline AES-256 & Argon2id vault for passwords, notes, cards & private files.` *(77 chars)*
- **Alternative 2**: `No account needed. Own your encrypted passwords, notes & documents locally.` *(75 chars)*

---

## 2. Full Description — Play Console Ready (Supported HTML `<b>` + `•` Lists, 3,017 / 4,000 characters)

> Google Play Console supports `<b>...</b>` (bold) and `•` bullet lists in Full Description. Copy everything inside the block below directly into Play Console.

```text
<b>Your Digital Life. Protected Locally.</b>

Nija (निज) is a local-first, zero-account encrypted vault for your passwords, secure notes, identity documents, payment cards, and private files.

Unlike cloud-only password managers that store your secrets on company servers, Nija keeps your encrypted vault on your device—and gives you full ownership of your portable .nija vault file.

<b>WHY NIJA?</b>
• <b>No Account, No Tracking:</b> Start immediately without creating an account, email login, or subscription.
• <b>True Local-First Privacy:</b> Your data is encrypted on your device before anything is saved or exported.
• <b>Strong Modern Cryptography:</b> Protected by Argon2id key derivation and AES-256-GCM authenticated encryption.
• <b>You Own Your Vault File:</b> Export, move, or back up your encrypted .nija vault anywhere—with zero vendor lock-in.

<b>EVERYTHING IN ONE SECURE VAULT</b>
• <b>Password Manager:</b> Save logins, bank accounts, Wi-Fi credentials, SSH keys, API keys, and license keys with an integrated strong password & passphrase generator.
• <b>Secure Notes:</b> Write formatted rich-text notes with tags, favorites, and instant search.
• <b>Encrypted Document & PDF Vault:</b> Store and preview sensitive PDFs, ID photos, passports, and attachments (up to 25 MB per file) in encrypted storage chunks.
• <b>Smart Folders & Explorer:</b> Organize entries with nested folders, List/Grid/Tree views, bulk move/copy, and fast tag/type filtering.
• <b>Custom Templates:</b> Create your own item categories and custom fields for any type of secret.

<b>FAST ACCESS & ZERO-TRUST PROTECTION</b>
• <b>Biometric & PIN Unlock:</b> Unlock quickly with fingerprint or face biometrics, or an encrypted app PIN with brute-force lockout protection.
• <b>Auto-Lock & Clipboard Clear:</b> Automatically locks after inactivity or backgrounding, and clears copied passwords from your clipboard.
• <b>Screenshot Protection:</b> Prevents sensitive vault screens from appearing in screenshots or recent-app previews on Android.
• <b>Offline 12-Word Recovery:</b> Recover access to your vault or rotate your master password anytime with your private recovery phrase.

<b>PORTABLE BACKUPS & ENCRYPTED SHARING</b>
• <b>Encrypted Secret Sharing (.nijas):</b> Share individual passwords, notes, or documents as password-protected .nijas files over any messaging app.
• <b>Local Rolling Snapshots:</b> Keep local recovery snapshots on your device and restore with a tap.
• <b>Optional Google Drive Backup & Sync:</b> Back up your encrypted vault to your personal Google Drive (Wi-Fi-only option supported) and merge changes across devices with 3-way conflict resolution.

<b>FREE FOREVER CORE + OPTIONAL PRO UPGRADE</b>
• <b>Free:</b> Unlimited passwords & notes, 151 MB encrypted vault storage, manual .nija export/import, and Google Drive backup/restore.
• <b>Pro (One-Time Upgrade):</b> Expands vault storage to 1 GB and unlocks automated daily local backups.

Take back control of your digital privacy with Nija.
```

---

## 3. ASO & SEO Metadata

- **Primary Category**: `Productivity` (secondary option: `Tools`)
- **Play Store Tags (up to 5)**: `Password manager`, `Security`, `Privacy`, `Notes`, `File manager`
- **Target Keyword Clusters**:
  - *Primary*: `offline password manager`, `encrypted vault`, `password vault`, `local password manager`
  - *Secondary*: `secure notes`, `document vault`, `encrypted pdf storage`, `no account password manager`, `argon2id`, `aes-256`, `google drive encrypted backup`

---

## 4. Screenshots & Suggested Frame Captions

All 8 phone screenshots (`1075×2330` px) are stored in `docs/playstore_screenshots/`:

| #   | File                                                  | Screen                  | Suggested Play Store Caption                    |
| --- | ----------------------------------------------------- | ----------------------- | ----------------------------------------------- |
| 1   | `docs/playstore_screenshots/01_walkthrough.png`       | Onboarding Walkthrough  | *100% Local-First Encrypted Vault*              |
| 2   | `docs/playstore_screenshots/02_welcome_entry.png`     | Welcome & Entry         | *No Account Required. Own Your* `.nija` *File.* |
| 3   | `docs/playstore_screenshots/03_recovery_phrase.png`   | 12-Word Recovery Phrase | *Offline 12-Word Recovery Phrase*               |
| 4   | `docs/playstore_screenshots/04_home_dashboard.png`    | Home Dashboard          | *Passwords, Notes, IDs & PDFs in One Place*     |
| 5   | `docs/playstore_screenshots/05_all_items.png`         | All Items & Search      | *Instant Search, Tags & Custom Templates*       |
| 6   | `docs/playstore_screenshots/06_folders_explorer.png`  | Folders & File Explorer | *Organize Secrets & Documents in Folders*       |
| 7   | `docs/playstore_screenshots/07_settings_security.png` | Settings & Security     | *Biometric, PIN & Auto-Lock Protection*         |
| 8   | `docs/playstore_screenshots/08_add_login_item.png`    | Add Login Item          | *Structured Templates & Folder Organization*    |

---

## 5. Google Play Data Safety & Release Checklist

### Data Safety Form

- **Data collected by developer**: None (no Nija user accounts, no analytics SDKs, no crash/ad trackers).
- **Optional Google Drive Backup**: User-initiated encrypted `.nija` backups uploaded to the user's own Google Drive `appDataFolder`.
- **Encryption**: All vault data is encrypted locally before storage or upload (`Argon2id` + `AES-256-GCM`); network traffic uses HTTPS/TLS.
- **Deletion**: Users can delete local vaults on-device or delete the Google Drive backup from their Google account.

### Release Build Checklist (`com.nija`)

- [ ] `android/key.properties` configured for release signing (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`).
- [ ] Release / Play App Signing **SHA-1** registered in Google Cloud Console for `com.nija`.
- [ ] Build command includes `--dart-define=NIJA_GOOGLE_NATIVE_SERVER_CLIENT_ID=<web-client-id>` (and `--dart-define=NIJA_PAID_BUILD=true` for paid builds if applicable).
- [ ] Privacy Policy URL published and linked in Play Console (mirrors `web/privacy.html`).
- [ ] Release AAB built with obfuscation & split debug symbols:
  ```bash
  flutter build appbundle --release --obfuscate --split-debug-info=build/symbols \
    --dart-define=NIJA_GOOGLE_NATIVE_SERVER_CLIENT_ID=<your-web-client-id>
  ```
