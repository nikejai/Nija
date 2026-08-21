# Nija App Info

Use this page as the source copy for app store listings, website metadata, app
descriptions, review forms, and launch material.

## App Name

Nija

## Short Description

Private encrypted vault for passwords, notes, documents, and recovery data.

## Tagline

Your private vault, encrypted locally and always under your control.

## Full Description

Nija is a local-first private vault for storing sensitive information on your
own device. Create an encrypted vault for passwords, secure notes, identities,
documents, recovery details, and custom records without relying on a central
server to hold your data.

Your vault is protected by your master password and recovery phrase. App PIN and
biometric unlock can provide faster access on supported devices, while the
underlying vault data remains encrypted. Nija also supports encrypted vault
import/export and encrypted secret sharing so you can move or share protected
data without exposing plain text.

On Android, Nija can back up encrypted vault files to Google Drive when the
expanded-storage entitlement is active. Cloud backup is treated as encrypted
file portability, not server-side sync: the backup payload remains encrypted
before it leaves the app.

Nija is built for phones, foldables, tablets, desktop, and web with a responsive
interface that keeps the same vault workflow across device sizes.

## Key Features

- Local-first encrypted vaults
- Password, note, identity, document, and custom item storage
- Master password and recovery phrase protection
- App PIN unlock
- Biometric unlock on supported devices
- Encrypted vault import and export
- Encrypted secret sharing with `.nijas` files
- Search, favorites, tags, sorting, and filters
- Custom templates for flexible records
- Android Google Drive encrypted backup and restore with entitlement
- Responsive phone, foldable, tablet, desktop, and web layouts

## Privacy And Security Copy

Nija is designed so your vault content stays encrypted locally. Master passwords,
recovery phrases, PINs, and decrypted vault contents should not be stored in
plain text or sent to Nija servers. Cloud backup uploads encrypted vault files
only.

## Privacy Policy URL

Use the deployed web app URL with this path:

```text
https://<your-production-domain>/privacy.html
```

## Store Listing Notes

- App category: Productivity
- Secondary category: Tools
- Target audience: people who want a simple private vault for personal sensitive
  data
- Content rating expectation: suitable for general audiences
- Data safety summary: encrypted user-provided vault data is stored locally;
  optional Android cloud backup uploads encrypted vault files to the user's
  Google Drive account

## Store Assets

- Google Play app icon: `assets/store/play_store_icon.png`
  - 512x512 PNG
  - under 1024 KB
  - square artwork; Google Play applies the final mask and shadow
- Google Play feature graphic: `assets/store/play_feature_graphic.jpg`
  - 1024x500 JPEG
  - RGB/sRGB
  - no alpha channel

## Keywords

password vault, secure notes, encrypted vault, private storage, local-first,
document vault, recovery phrase, biometric unlock, PIN unlock, encrypted backup,
Google Drive backup

## Version 0.1.1 Release Notes

Nija 0.1.1 improves Android purchase and cloud restore reliability.

- Added Google Play expanded-storage purchase and restore support
- Made cloud backup and restore available in the free app
- Improved Google Drive restore/import failure guidance
- Fixed Android Play Billing purchase launch issues
- Added clearer Google Play account guidance before purchase and restore
- Improved PDF preview loading behavior
- Added secure secret sharing to onboarding

### Google Play Release Notes

Improved Android purchase and cloud restore reliability. Added clearer Google
Play account guidance, fixed expanded-storage purchase launch issues, improved
cloud restore/import messages, and refined PDF preview loading.

## Version 0.0.1 Release Notes

Initial public release of Nija.

- Create and unlock encrypted local vaults
- Store passwords, notes, identities, documents, and custom items
- Recover vault access with a recovery phrase
- Use App PIN and biometric unlock where supported
- Import and export encrypted vault files
- Share encrypted `.nijas` secret files
- Back up and restore encrypted vault files with Google Drive on Android
- Search, favorite, tag, sort, and filter vault items
- Use responsive layouts across phones, foldables, tablets, desktop, and web
