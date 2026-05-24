class VaultMigrator {
  VaultMigrator._();

  static const int currentVaultFormatVersion = 2;
  static const int currentPayloadSchemaVersion = 1;
  static const int currentStorageLayoutVersion = 1;
  static const int currentManifestVersion = 1;

  static Map<String, dynamic> migrateVaultFileJson(Map<String, dynamic> input) {
    final working = Map<String, dynamic>.from(input);
    final version = working['formatVersion'] as int? ?? 0;

    if (version > currentVaultFormatVersion) {
      throw UnsupportedError(
        'Vault format version $version is not supported by this app build.',
      );
    }

    if (version == 0) {
      // Legacy files did not always include explicit recovery KDF wrapper metadata.
      working['formatVersion'] = currentVaultFormatVersion;
      working['recoveryKdf'] ??= working['kdf'];
      working['encryptedVaultKeyByRecovery'] ??= working['encryptedVaultKey'];
      working['schemaVersion'] ??= currentPayloadSchemaVersion;
      working['storageLayoutVersion'] ??= currentStorageLayoutVersion;
      working['manifestVersion'] ??= currentManifestVersion;
      working['revision'] ??= 0;
      working['vaultVersionId'] ??=
          'legacy-${working['updatedAt'] ?? 'unknown'}';
      return working;
    }

    working['formatVersion'] = currentVaultFormatVersion;
    working['schemaVersion'] ??= currentPayloadSchemaVersion;
    working['storageLayoutVersion'] ??= currentStorageLayoutVersion;
    working['manifestVersion'] ??= currentManifestVersion;
    working['revision'] ??= version < 2 ? 0 : 1;
    working['vaultVersionId'] ??= 'legacy-${working['updatedAt'] ?? 'unknown'}';
    working['recoveryKdf'] ??= working['kdf'];
    working['encryptedVaultKeyByRecovery'] ??= working['encryptedVaultKey'];
    return working;
  }

  static Map<String, dynamic> migratePayloadJson(Map<String, dynamic> input) {
    final working = Map<String, dynamic>.from(input);
    final version = working['schemaVersion'] as int? ?? 0;

    if (version > currentPayloadSchemaVersion) {
      throw UnsupportedError(
        'Vault payload schema version $version is not supported by this app build.',
      );
    }

    if (version == 0) {
      working['schemaVersion'] = 1;
      working['items'] ??= const <dynamic>[];
      working['notes'] ??= const <dynamic>[];
      working['tags'] ??= const <dynamic>[];
      working['settings'] ??= const <String, dynamic>{};
      working['audit'] ??= const <dynamic>[];
      return working;
    }

    working['schemaVersion'] = currentPayloadSchemaVersion;
    return working;
  }
}
