# Encryption, Recovery, and Password Reset

This document explains how vault encryption is designed to work, what recovery phrase means, and how password reset should work in a production-grade implementation.

## 1) Current App State (As Implemented Today)

The current app is still in MVP/prototype stage.

- Recovery phrase is currently sourced from a configured template, not generated per-user at random.
- Unlock flow currently depends on master password in app logic.
- Recovery is currently a UX flow and note/document experience, not a fully implemented cryptographic recovery pipeline.

This is useful for product flow iteration, but not yet final security architecture.

## 2) Security Model (Target Real-World Design)

Use envelope encryption with a data-encryption key (DEK).

1. Generate a random `DEK` (32-byte symmetric key) when creating a vault.
2. Encrypt all vault data using `DEK` with AEAD (for example: XChaCha20-Poly1305 or AES-256-GCM).
3. Derive a key from master password using Argon2id (`K_master`).
4. Encrypt/wrap `DEK` with `K_master` -> store as `wrappedDekByPassword`.
5. Generate random recovery secret (or BIP-39 style mnemonic + optional passphrase) -> derive `K_recovery`.
6. Encrypt/wrap same `DEK` with `K_recovery` -> store as `wrappedDekByRecovery`.

Vault payload stays encrypted by `DEK`; password/recovery only unlock `DEK`.

## 3) Why Master Password and Recovery Phrase Both Exist

- Master password:
  - Primary day-to-day unlock factor.
  - Can be changed without re-encrypting each field individually (only re-wrap `DEK`).
- Recovery phrase:
  - Emergency unlock path when master password is forgotten.
  - Lets user recover vault access by unwrapping `DEK`, then setting a new master password.

They are separate credentials with separate purpose.

## 4) Vault Creation Flow (Target)

1. User enters and confirms master password.
2. App generates random `DEK`.
3. App derives `K_master` using Argon2id (with random salt and calibrated cost params).
4. App wraps `DEK` with `K_master`.
5. App generates unique random recovery phrase/secret.
6. App derives `K_recovery` and wraps `DEK` again.
7. App stores:
   - encrypted vault blob,
   - `wrappedDekByPassword`,
   - `wrappedDekByRecovery`,
   - KDF metadata/salts/versioning.
8. App shows recovery phrase once and asks user to save offline.

## 5) Unlock Flow (Normal)

1. User enters master password.
2. App derives `K_master` from stored salt/params.
3. App attempts to unwrap `DEK` using `wrappedDekByPassword`.
4. If unwrap succeeds, app decrypts vault data in memory.
5. On lock/close/background policy, clear sensitive memory and require unlock again.

## 6) Recovery Flow (Forgot Password)

1. User selects `Recover vault` on unlock screen.
2. User enters recovery phrase.
3. App derives `K_recovery`.
4. App unwraps `DEK` using `wrappedDekByRecovery`.
5. If success, user can access reset screen to set new master password.
6. App derives new `K_master_new` and re-wraps same `DEK`.
7. Replace `wrappedDekByPassword` with new wrapper.
8. Keep recovery wrapper unless user explicitly rotates recovery phrase.

Important: password reset does not require decrypting/re-encrypting each item when using envelope encryption; only key wrappers change.

## 7) Password Reset vs Recovery Phrase Rotation

- Reset master password:
  - Re-wrap `DEK` with new password-derived key.
  - Fast operation.
- Rotate recovery phrase:
  - Generate new recovery secret/phrase.
  - Re-wrap `DEK` with new recovery-derived key.
  - Invalidate old recovery wrapper after successful write.

These are independent operations and can be done separately.

## 8) Cryptographic and Storage Recommendations

- KDF: Argon2id with per-vault random salt and versioned params.
- AEAD: XChaCha20-Poly1305 or AES-256-GCM with unique nonces.
- RNG: cryptographically secure RNG for DEK, salts, nonces, recovery entropy.
- Metadata versioning: store algorithm + params for migrations.
- Integrity: authenticate ciphertext and metadata where needed.
- Secure storage:
  - local encrypted vault file or platform app storage,
  - sensitive key material zeroized from memory where feasible.
- Brute-force mitigation:
  - optional exponential delay / attempt throttling on unlock failures.

## 9) UX Requirements for Recovery Phrase

- Show phrase only during creation and explicit recovery settings entry.
- Provide copy control with clear warning and optional clipboard auto-clear.
- Encourage offline storage (paper/hardware encrypted backup).
- Never send phrase to network services.
- Never store phrase in plaintext alongside vault data.

## 10) Implementation Notes for This Codebase

To move from MVP behavior to real-world behavior in this project:

1. Replace template phrase with per-user random phrase generation.
2. Introduce `VaultKeyManager` service:
   - generate/wrap/unwrap/rotate `DEK`,
   - manage KDF params and metadata.
3. Update unlock UI:
   - add `Recover with phrase` path.
4. Add reset flow:
   - `Recover -> Set new master password -> re-wrap DEK`.
5. Persist wrappers + metadata in vault file format.
6. Add tests:
   - create/unlock/recover/reset/rotate key wrapper round-trips,
   - wrong password/phrase failure paths,
   - migration/version compatibility.

---

In short: master password is the primary unlock secret, recovery phrase is the emergency unlock/reset secret, and both should only ever be used to unwrap the same randomly generated vault key.
