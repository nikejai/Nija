class VaultFile {
  const VaultFile({
    required this.format,
    required this.formatVersion,
    required this.vaultId,
    required this.vaultName,
    required this.createdAt,
    required this.updatedAt,
    required this.guardian,
    required this.kdf,
    required this.recoveryKdf,
    required this.cipher,
    required this.encryptedVaultKey,
    required this.encryptedVaultKeyByRecovery,
    required this.encryptedPayload,
  });

  final String format;
  final int formatVersion;
  final String vaultId;
  final String vaultName;
  final String createdAt;
  final String updatedAt;
  final GuardianMetadata guardian;
  final KdfMetadata kdf;
  final KdfMetadata recoveryKdf;
  final CipherMetadata cipher;
  final String encryptedVaultKey;
  final String encryptedVaultKeyByRecovery;
  final String encryptedPayload;

  Map<String, dynamic> toJson() => {
        'format': format,
        'formatVersion': formatVersion,
        'vaultId': vaultId,
        'vaultName': vaultName,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'guardian': guardian.toJson(),
        'kdf': kdf.toJson(),
        'recoveryKdf': recoveryKdf.toJson(),
        'cipher': cipher.toJson(),
        'encryptedVaultKey': encryptedVaultKey,
        'encryptedVaultKeyByRecovery': encryptedVaultKeyByRecovery,
        'encryptedPayload': encryptedPayload,
      };

  factory VaultFile.fromJson(Map<String, dynamic> json) {
    return VaultFile(
      format: json['format'] as String? ?? 'Nija',
      formatVersion: json['formatVersion'] as int? ?? 1,
      vaultId: json['vaultId'] as String,
      vaultName:
          (json['vaultName'] as String?)?.trim().isNotEmpty == true
          ? (json['vaultName'] as String).trim()
          : json['vaultId'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      guardian: GuardianMetadata.fromJson(Map<String, dynamic>.from(json['guardian'] as Map)),
      kdf: KdfMetadata.fromJson(Map<String, dynamic>.from(json['kdf'] as Map)),
      recoveryKdf: json['recoveryKdf'] == null
          ? KdfMetadata.fromJson(Map<String, dynamic>.from(json['kdf'] as Map))
          : KdfMetadata.fromJson(Map<String, dynamic>.from(json['recoveryKdf'] as Map)),
      cipher: CipherMetadata.fromJson(Map<String, dynamic>.from(json['cipher'] as Map)),
      encryptedVaultKey: json['encryptedVaultKey'] as String,
      encryptedVaultKeyByRecovery: json['encryptedVaultKeyByRecovery'] as String? ?? json['encryptedVaultKey'] as String,
      encryptedPayload: json['encryptedPayload'] as String,
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'nonce': nonce,
      };

  factory CipherMetadata.fromJson(Map<String, dynamic> json) {
    return CipherMetadata(
      name: json['name'] as String,
      nonce: json['nonce'] as String,
    );
  }
}
