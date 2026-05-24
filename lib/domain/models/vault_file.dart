class VaultFile {
  const VaultFile({
    required this.format,
    required this.formatVersion,
    this.schemaVersion = 1,
    this.storageLayoutVersion = 1,
    this.manifestVersion = 1,
    required this.vaultId,
    required this.createdAt,
    required this.updatedAt,
    this.vaultVersionId = '',
    this.revision = 0,
    this.vaultName,
    this.lastModifiedByDeviceId,
    required this.guardian,
    required this.kdf,
    required this.recoveryKdf,
    required this.cipher,
    required this.encryptedVaultKey,
    required this.encryptedVaultKeyByRecovery,
    this.encryptedPayload,
    this.encryptedManifest,
    this.encryptedSections = const <String, String>{},
  });

  final String format;
  final int formatVersion;
  final int schemaVersion;
  final int storageLayoutVersion;
  final int manifestVersion;
  final String vaultId;
  final String? vaultName;
  final String createdAt;
  final String updatedAt;
  final String vaultVersionId;
  final int revision;
  final String? lastModifiedByDeviceId;
  final GuardianMetadata guardian;
  final KdfMetadata kdf;
  final KdfMetadata recoveryKdf;
  final CipherMetadata cipher;
  final String encryptedVaultKey;
  final String encryptedVaultKeyByRecovery;
  final String? encryptedPayload;
  final String? encryptedManifest;
  final Map<String, String> encryptedSections;

  Map<String, dynamic> toJson() => {
    'format': format,
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'storageLayoutVersion': storageLayoutVersion,
    'manifestVersion': manifestVersion,
    'vaultId': vaultId,
    if (vaultName != null && vaultName!.trim().isNotEmpty)
      'vaultName': vaultName,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'vaultVersionId': vaultVersionId,
    'revision': revision,
    if (lastModifiedByDeviceId != null &&
        lastModifiedByDeviceId!.trim().isNotEmpty)
      'lastModifiedByDeviceId': lastModifiedByDeviceId,
    'guardian': guardian.toJson(),
    'kdf': kdf.toJson(),
    'recoveryKdf': recoveryKdf.toJson(),
    'cipher': cipher.toJson(),
    'encryptedVaultKey': encryptedVaultKey,
    'encryptedVaultKeyByRecovery': encryptedVaultKeyByRecovery,
    if (encryptedPayload != null) 'encryptedPayload': encryptedPayload,
    if (encryptedManifest != null) 'encryptedManifest': encryptedManifest,
    if (encryptedSections.isNotEmpty)
      'encryptedSections': Map<String, String>.from(encryptedSections),
  };

  factory VaultFile.fromJson(Map<String, dynamic> json) {
    final encryptedSectionsRaw = json['encryptedSections'];
    return VaultFile(
      format: json['format'] as String? ?? 'Nija',
      formatVersion: json['formatVersion'] as int? ?? 1,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      storageLayoutVersion: json['storageLayoutVersion'] as int? ?? 1,
      manifestVersion: json['manifestVersion'] as int? ?? 1,
      vaultId: json['vaultId'] as String,
      vaultName: (json['vaultName'] as String?)?.trim().isNotEmpty == true
          ? (json['vaultName'] as String).trim()
          : null,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      vaultVersionId:
          json['vaultVersionId'] as String? ?? 'legacy-${json['updatedAt']}',
      revision: json['revision'] as int? ?? 0,
      lastModifiedByDeviceId: json['lastModifiedByDeviceId'] as String?,
      guardian: GuardianMetadata.fromJson(
        Map<String, dynamic>.from(json['guardian'] as Map),
      ),
      kdf: KdfMetadata.fromJson(Map<String, dynamic>.from(json['kdf'] as Map)),
      recoveryKdf: json['recoveryKdf'] == null
          ? KdfMetadata.fromJson(Map<String, dynamic>.from(json['kdf'] as Map))
          : KdfMetadata.fromJson(
              Map<String, dynamic>.from(json['recoveryKdf'] as Map),
            ),
      cipher: CipherMetadata.fromJson(
        Map<String, dynamic>.from(json['cipher'] as Map),
      ),
      encryptedVaultKey: json['encryptedVaultKey'] as String,
      encryptedVaultKeyByRecovery:
          json['encryptedVaultKeyByRecovery'] as String? ??
          json['encryptedVaultKey'] as String,
      encryptedPayload: json['encryptedPayload'] as String?,
      encryptedManifest: json['encryptedManifest'] as String?,
      encryptedSections: encryptedSectionsRaw is Map
          ? encryptedSectionsRaw.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
    );
  }

  VaultFile copyWith({
    int? formatVersion,
    int? schemaVersion,
    int? storageLayoutVersion,
    int? manifestVersion,
    String? vaultVersionId,
    int? revision,
    String? updatedAt,
    String? lastModifiedByDeviceId,
    String? vaultName,
    GuardianMetadata? guardian,
    KdfMetadata? kdf,
    KdfMetadata? recoveryKdf,
    CipherMetadata? cipher,
    String? encryptedVaultKey,
    String? encryptedVaultKeyByRecovery,
    String? encryptedPayload,
    String? encryptedManifest,
    Map<String, String>? encryptedSections,
    bool clearVaultName = false,
  }) {
    return VaultFile(
      format: format,
      formatVersion: formatVersion ?? this.formatVersion,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      storageLayoutVersion: storageLayoutVersion ?? this.storageLayoutVersion,
      manifestVersion: manifestVersion ?? this.manifestVersion,
      vaultId: vaultId,
      vaultName: clearVaultName ? null : vaultName ?? this.vaultName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vaultVersionId: vaultVersionId ?? this.vaultVersionId,
      revision: revision ?? this.revision,
      lastModifiedByDeviceId:
          lastModifiedByDeviceId ?? this.lastModifiedByDeviceId,
      guardian: guardian ?? this.guardian,
      kdf: kdf ?? this.kdf,
      recoveryKdf: recoveryKdf ?? this.recoveryKdf,
      cipher: cipher ?? this.cipher,
      encryptedVaultKey: encryptedVaultKey ?? this.encryptedVaultKey,
      encryptedVaultKeyByRecovery:
          encryptedVaultKeyByRecovery ?? this.encryptedVaultKeyByRecovery,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      encryptedManifest: encryptedManifest ?? this.encryptedManifest,
      encryptedSections: encryptedSections ?? this.encryptedSections,
    );
  }
}

class GuardianMetadata {
  const GuardianMetadata({required this.id, required this.profile});

  final String id;
  final String profile;

  Map<String, dynamic> toJson() => {'id': id, 'profile': profile};

  factory GuardianMetadata.fromJson(Map<String, dynamic> json) {
    return GuardianMetadata(
      id: json['id'] as String,
      profile: json['profile'] as String,
    );
  }
}

class KdfMetadata {
  const KdfMetadata({
    required this.name,
    required this.version,
    required this.memoryKb,
    required this.iterations,
    required this.parallelism,
    required this.salt,
  });

  final String name;
  final int version;
  final int memoryKb;
  final int iterations;
  final int parallelism;
  final String salt;

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version,
    'memoryKb': memoryKb,
    'iterations': iterations,
    'parallelism': parallelism,
    'salt': salt,
  };

  factory KdfMetadata.fromJson(Map<String, dynamic> json) {
    return KdfMetadata(
      name: json['name'] as String,
      version: json['version'] as int,
      memoryKb: json['memoryKb'] as int,
      iterations: json['iterations'] as int,
      parallelism: json['parallelism'] as int,
      salt: json['salt'] as String,
    );
  }
}

class CipherMetadata {
  const CipherMetadata({required this.name, required this.nonce});

  final String name;
  final String nonce;

  Map<String, dynamic> toJson() => {'name': name, 'nonce': nonce};

  factory CipherMetadata.fromJson(Map<String, dynamic> json) {
    return CipherMetadata(
      name: json['name'] as String,
      nonce: json['nonce'] as String,
    );
  }
}
