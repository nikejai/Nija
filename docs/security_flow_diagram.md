# Nija Security Flow (Text + Diagrams)

This document explains how Nija security works in simple flow-by-flow form.

## 1) Big Picture

Nija protects data with one random vault key and two unlock paths:

- Path A: Master password
- Path B: Recovery phrase

Both paths unlock the same vault key.

```text
Master Password -----> [Argon2id] -----> Password Key ----\
                                                           \
                                                            -> decrypt wrapped Vault Key -> decrypt Vault Data
                                                           /
Recovery Phrase -----> [Argon2id] -----> Recovery Key ----/
```

## 2) Vault Creation Flow

When user creates a vault:

1. App generates a random 32-byte Vault Key (DEK).
2. App creates password-derived key using Argon2id.
3. App creates recovery-derived key using Argon2id.
4. App encrypts Vault Key with password-derived key.
5. App encrypts Vault Key with recovery-derived key.
6. App encrypts vault payload with Vault Key using AES-256-GCM.
7. App stores encrypted file + metadata.

```text
              +----------------------+
              |  Random Vault Key    |
              |      (32 bytes)      |
              +----------+-----------+
                         |
                         | encrypt payload with AES-256-GCM
                         v
                +-------------------+
                | Encrypted Payload |
                +-------------------+

Password --> Argon2id --> Password Key --> Encrypt Vault Key --> EncryptedVaultKey
Recovery --> Argon2id --> Recovery Key --> Encrypt Vault Key --> EncryptedVaultKeyByRecovery
```

## 3) Unlock with Master Password

1. Read vault file.
2. Use stored password KDF metadata (`salt`, `memoryKb`, `iterations`, `parallelism`).
3. Derive password key using Argon2id.
4. Decrypt `EncryptedVaultKey`.
5. Use decrypted Vault Key to decrypt encrypted payload.

```text
Input: Master Password
          |
          v
     Argon2id(KDF metadata from file)
          |
          v
     Password Key
          |
          v
Decrypt EncryptedVaultKey  ---> Vault Key
          |
          v
Decrypt EncryptedPayload   ---> Plain Vault Data
```

## 4) Recover with Recovery Phrase

If user forgets master password:

1. Read vault file.
2. Use stored recovery KDF metadata.
3. Derive recovery key using phrase.
4. Decrypt `EncryptedVaultKeyByRecovery`.
5. Decrypt payload with Vault Key.

```text
Input: Recovery Phrase
          |
          v
     Argon2id(recovery KDF metadata)
          |
          v
      Recovery Key
          |
          v
Decrypt EncryptedVaultKeyByRecovery ---> Vault Key
          |
          v
Decrypt EncryptedPayload            ---> Plain Vault Data
```

## 5) What is stored in vault file

Main fields in `VaultFile`:

- `kdf`: password KDF metadata
- `recoveryKdf`: recovery KDF metadata
- `encryptedVaultKey`: vault key wrapped by password key
- `encryptedVaultKeyByRecovery`: vault key wrapped by recovery key
- `encryptedPayload`: full vault payload ciphertext
- `cipher`: cipher metadata

```text
VaultFile
├── kdf
├── recoveryKdf
├── encryptedVaultKey
├── encryptedVaultKeyByRecovery
├── encryptedPayload
└── cipher
```

## 6) Why this model is used

- Vault data is encrypted only once with Vault Key.
- Password changes or recovery operations can re-wrap the key, not re-encrypt all user data.
- Recovery phrase is independent fallback path.

## 7) Current platform behavior

- Android/iOS/desktop: file-backed adapter is used.
- Web: currently uses in-memory adapter fallback (runtime-safe, not durable persistence yet).

## 8) Current security baseline

- KDF: Argon2id
- Encryption: AES-256-GCM
- Vault key: random 32 bytes

## 9) Remaining hardening (before final release)

- Password reset UX that re-wraps vault key.
- Recovery phrase rotation flow.
- Web durable storage adapter.
- Secure-memory handling and full migration/versioning strategy.
