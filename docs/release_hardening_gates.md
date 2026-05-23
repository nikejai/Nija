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

## 3) Final Validation Matrix

Run all checks:

```bash
./scripts/release_hardening_gate.sh
```

Platform run validation:

- [ ] Web: create -> unlock -> lock -> unlock -> recovery unlock -> reset password.
- [ ] Android: create -> unlock -> lock -> unlock -> recovery unlock -> reset password.
- [ ] iOS: create -> unlock -> lock -> unlock -> recovery unlock -> reset password.
- [ ] Rotation validation on each platform:
  - [ ] master-password rotation
  - [ ] recovery phrase rotation
- [ ] CRUD persistence validation on each platform after app restart.

