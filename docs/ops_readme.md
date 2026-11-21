# Nija Ops Runbook

Concise operational guide for **Nija** (`com.nija`) covering Google Drive OAuth, Android release signing, Google Play Billing, and pre-release checks.

> **Core rule:** Nija is local-first. Only encrypted `.nija` vaults and `.nijas` secrets leave the device. Never log, upload, or commit plaintext secrets, master passwords, recovery phrases, keystores, or `android/key.properties`.

---

## 1. Google Cloud Console & Drive OAuth

Nija uses one Google Cloud project for Google Drive backup/restore (`drive.appdata` and `drive.file` scopes).

### Required Setup
1. **Enable API:** In Google Cloud Console → **APIs & Services** → enable **Google Drive API**.
2. **OAuth Consent Screen:**
   - **Testing mode:** Only explicitly listed test users can sign in.
   - **Production mode:** Required for public Play Store / Web users (switch **Publishing status** to **In production**).
3. **OAuth 2.0 Client IDs (Android + Web):**

   | Client Type | Identifier / Config | Purpose |
   | --- | --- | --- |
   | **Android** (Debug) | Package `com.nija` + Debug SHA-1 | `flutter run` local dev |
   | **Android** (Upload / Local Release) | `698262730675-pn8ol0m6ijgvtaoa9sh09cqq5cm0n0jo.apps.googleusercontent.com` (Package `com.nija` + Upload SHA-1 `8B:3D:...`) | Local `--release` APK testing |
   | **Android** (Play App Signing) | `698262730675-ko1gnfqi0rq1rvdco8o6nbv4asct1b9t.apps.googleusercontent.com` (Package `com.nija` + **Play App Signing SHA-1**) | **Required for Play Store release** |
   | **Web application** | `698262730675-ui2upcjqi4c3mpu8lm9ci3bv1okrbp2v.apps.googleusercontent.com` + Authorized JS origins | Web Drive OAuth & native `serverClientId` |

### Why Play Store Installs Fail Without Play App Signing SHA-1
- You do **not** put Android OAuth Client IDs into Flutter code. Google Play Services automatically matches the installed APK's `com.nija` package name + **SHA-1 signing certificate** against your Google Cloud **Android OAuth Client IDs**.
- Google Play re-signs `.aab` uploads with Google's **App signing key** (different from your local upload keystore).

### Local Testing Fingerprints (Local Dev & Local Release APK Only)
Run from `android/`:
```bash
./gradlew signingReport
```
Current local fingerprints for `com.nija` (**for local testing only**):
- **Debug SHA-1** (`flutter run`): `97:E7:92:C9:81:E0:30:74:18:96:81:F4:52:10:16:F0:80:02:6D:F3`
- **Upload/Release SHA-1** (local `app-release.apk`): `8B:3D:36:2F:FF:EA:44:19:C5:C5:A3:89:56:CB:57:E8:36:25:C2:50`

### Play Store Release Certificates (Actual Play Store & Internal Testing)
#### Step 1: Find Your Certificates in Google Play Console
1. Open [Google Play Console](https://play.google.com/console) and select **Nija**.
2. Navigate to **Test and release → Setup → App integrity** (or **Protected with Play → Play Store protection → Manage Play app signing**, depending on your console view).
3. Under the **App signing** tab, you will see:
   - **App signing key certificate:** Contains the **Classical key** (RSA/ECDSA) and optionally a **Post-quantum cryptography key** (beta). **Always use the Classical key SHA-1** for Google OAuth—ignore the Post-quantum SHA-1.
   - **Previous app signing keys / Internal App Sharing:** If you rotated keys (e.g., Quantum-ready upgrade) or use Internal App Sharing, Play Console also lists previous or internal-sharing certificates on that page.
   - **Upload key certificate:** Contains the fingerprints for your local keystore used to upload `.aab` builds.

#### Step 2: Match or Create the Android OAuth Client in Google Cloud Console
1. Open [Google Cloud Console](https://console.cloud.google.com/) and select the **Nija** project.
2. Go to **APIs & Services → Credentials** (or **Google Auth Platform → Clients**).
3. Either **edit** an existing Android OAuth 2.0 Client ID or click **+ Create credentials → OAuth client ID**:
   - **Application type:** `Android`
   - **Name:** e.g. `Nija Android (Play App Signing)` (keep separate clients for Debug, Upload/Local Release, Play App Signing, and Internal App Sharing if used)
   - **Package name:** `com.nija`
   - **SHA-1 certificate fingerprint:** Paste the **App signing key certificate SHA-1** from Play Console.
   - **Active Play Store Release Client ID:** `698262730675-ko1gnfqi0rq1rvdco8o6nbv4asct1b9t.apps.googleusercontent.com`
4. Click **Save / Create**. Changes propagate within a few minutes—no `.aab` rebuild is required.

### Testing Play-Signed vs. Local APKs on Device
- **Test Play-signed APK locally:** In Play Console → **Test and release → App bundle explorer** → select version → **Downloads** → download **Signed, universal APK**, then install with `adb install -r <path-to-universal.apk>` (or install from your Play Internal Testing link).
- **Switching between Play and local builds:** Uninstall first (`adb uninstall com.nija`) before installing the other build, otherwise `adb install -r` fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.

### Validate APK / Installed App SHA-1 Against Console
- **Check an APK file:**
  ```bash
  $ANDROID_HOME/build-tools/$(ls $ANDROID_HOME/build-tools | tail -n 1)/apksigner verify --print-certs <path-to-app.apk>
  ```
- **Check the app currently installed on a connected phone (e.g., from Play Store):**
  ```bash
  APK_PATH=$(adb shell pm path com.nija | head -n 1 | cut -d: -f2 | tr -d '\r')
  adb pull "$APK_PATH" /tmp/nija-installed.apk
  $ANDROID_HOME/build-tools/$(ls $ANDROID_HOME/build-tools | tail -n 1)/apksigner verify --print-certs /tmp/nija-installed.apk
  ```
- **Check a local `.aab` (Upload key):**
  ```bash
  keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | grep -E "SHA1|SHA256"
  ```
- Compare **`Signer #1 certificate SHA-1 digest`** (note: `apksigner` prints lowercase without colons, while Google Cloud/Play Console shows uppercase with colons) against your Android OAuth client in Google Cloud Console.

### Debug & Troubleshooting (OAuth / Drive Sign-In)
- **Play Store restore fails / `ApiException: 10` / `DEVELOPER_ERROR`:**
  - Verify the installed APK's **`Signer #1 certificate SHA-1 digest`** (not `Source Stamp Signer`) is registered on an Android OAuth Client for `com.nija`.
  - Use the **Classical key** SHA-1 (not the Post-quantum key SHA-1).
  - If Play Console lists both a current `In use` key and a **Previous app signing key** (or **Internal app sharing** key), you can create separate Android OAuth Client IDs for `com.nija` for **each** SHA-1 in the same Google Cloud project—Google Play Services will match whichever signed the APK on the device.
  - Ensure `NIJA_GOOGLE_NATIVE_SERVER_CLIENT_ID` was **not** set to an Android Client ID (omit it or pass the **Web** Client ID `...1okrbp2v...`).
  - Confirm **Google Auth Platform → Audience** is **In production** (or the tester's email is under **Test users** while in **Testing**).
- **After updating OAuth clients:** Wait **5–10 minutes** for propagation, then clear Nija's app cache (**Settings → Apps → Nija → Storage → Clear cache**) or reinstall from Play.
- **Inspect live sign-in errors via USB:**
  ```bash
  adb logcat | grep -i -E "nija|google|signin|oauth|apiexception"
  ```
- **Drive API `403`:** OAuth succeeded, but **Google Drive API** is not enabled in the project.
- **Web `origin_mismatch`:** Exact `scheme://host[:port]` missing from Web OAuth Client **Authorized JavaScript origins**.

---

## 2. Android Release Signing & Build

### Signing Configuration (`android/key.properties`, gitignored)
```properties
storePassword=<store-password>
keyPassword=<key-password>
keyAlias=nija-release
storeFile=/Users/<you>/nija-release.jks
```
Keep `android/key.properties` and the `.jks` keystore backed up offline outside git.

### Release App Bundle (`.aab`) for Play Store
Always bump `version:` in `pubspec.yaml` (`+<versionCode>`) and pass the **Web** OAuth Client ID (never an Android Client ID) as `NIJA_GOOGLE_NATIVE_SERVER_CLIENT_ID`:

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols \
  --dart-define=NIJA_GOOGLE_NATIVE_SERVER_CLIENT_ID=698262730675-ui2upcjqi4c3mpu8lm9ci3bv1okrbp2v.apps.googleusercontent.com
```

> - **Important:** `NIJA_GOOGLE_NATIVE_SERVER_CLIENT_ID` must be the **Web application** Client ID (`...1okrbp2v...`), **not** an Android Client ID (`...cm0n0jo...` or `...asct1b9t...`). Passing an Android Client ID as `serverClientId` causes Google Sign-In to fail (`ApiException: 10`).
> - Do **not** pass `--dart-define=NIJA_PAID_BUILD=true` to Play Store builds (`NIJA_PAID_BUILD` is a dev-only override).

---

## 3. Google Play Billing (Pro Entitlement)

- **Managed Product ID (non-consumable):** `nija_expanded_vault_lifetime`
- **Free tier:** Unlimited passwords & notes, **151 MB** vault storage, manual `.nija` export/import, and Google Drive backup/restore.
- **Pro tier (one-time purchase):** Expands vault storage to **1 GB** and unlocks **automated daily local backups**.
- **Behavior:** App auto-checks past Play purchases on startup (`NijaEntitlementService`), caches verified state in `FlutterSecureStorage` for offline starts, and exposes **Upgrade to Pro** and **Restore purchase** in **Settings → Storage**.
- **Testing:** Purchase/restore flows require an `.aab` uploaded to a Play Console testing track (Internal/Closed) installed via the Play test link with a License Tester account.

---

## 4. iOS & Web Notes

- **iOS:** Uses iCloud Drive ubiquity container (`Documents/vaults/<vaultId>/`). Configure iCloud capability for the Bundle ID in Apple Developer / Xcode.
- **Web:** Uses the Web OAuth Client ID (`GoogleOAuthConfig.webClientId`, overridable via `NIJA_GOOGLE_WEB_CLIENT_ID`) and requires `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` headers configured in `web/_headers`.

---

## 5. Pre-Release Validation

```bash
flutter pub get
flutter analyze lib test integration_test
flutter test
```
