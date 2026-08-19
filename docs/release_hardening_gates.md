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
- [ ] Android release builds use production signing, R8/ProGuard, resource shrinking where safe, and private debug-symbol archival.
- [ ] Client bundles contain no secrets, entitlement bypasses, debug endpoints, or sensitive constants.

## 3) WebApp Release Gates

- [ ] Web release build steps are documented and reproducible.
- [ ] Web app is installable on iOS Safari and Android Chrome with production icons, manifest, theme color, and mobile viewport behavior.
- [ ] Web app starts and unlocks previously created encrypted vault data while offline after the first successful load.
- [ ] Service worker/cache strategy does not cache decrypted vault contents, recovery phrases, master passwords, or raw secret exports.
- [ ] IndexedDB/local web storage contains only encrypted vault data and non-secret app preferences.
- [ ] HTTPS-only deployment is enforced with appropriate security headers, including CSP.
- [ ] Browser visibility/background behavior locks or protects sensitive vault surfaces consistently with native app expectations.

## 4) Final Validation Matrix

Run all checks:

```bash
./scripts/release_hardening_gate.sh
```

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
