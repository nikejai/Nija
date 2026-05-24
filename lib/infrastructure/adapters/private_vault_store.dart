import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/models/vault_file.dart';
import '../../domain/models/vault_registry_entry.dart';

abstract class PrivateVaultStore {
  Future<bool> vaultExists(String vaultStoreId);
  Future<VaultFile> readHeader(String vaultStoreId);
  Future<Uint8List> readSection(String vaultStoreId, String fileName);
  Future<void> commitVault({
    required String vaultStoreId,
    required VaultFile header,
    required Map<String, Uint8List> sections,
  });
  Future<String> stageVault({
    required String vaultStoreId,
    required VaultFile header,
    required Map<String, Uint8List> sections,
  });
  Future<void> promoteStagedVault({
    required String stagedVaultStoreId,
    required String vaultStoreId,
  });
  Future<void> discardVault(String vaultStoreId);
  Future<Map<String, dynamic>> describeVault(String vaultStoreId);
}

abstract class VaultRegistryStore {
  Future<List<VaultRegistryEntry>> readAll();
  Future<void> upsert(VaultRegistryEntry entry);
  Future<VaultRegistryEntry?> findActiveByVaultId(String vaultId);
}

class InMemoryPrivateVaultStore implements PrivateVaultStore {
  final Map<String, Map<String, Uint8List>> _vaults =
      <String, Map<String, Uint8List>>{};

  @override
  Future<bool> vaultExists(String vaultStoreId) async {
    return _vaults.containsKey(vaultStoreId);
  }

  @override
  Future<VaultFile> readHeader(String vaultStoreId) async {
    final raw = _vaults[vaultStoreId]?['header.json'];
    if (raw == null) {
      throw StateError('Working vault not found: $vaultStoreId');
    }
    return VaultFile.fromJson(
      Map<String, dynamic>.from(jsonDecode(utf8.decode(raw)) as Map),
    );
  }

  @override
  Future<Uint8List> readSection(String vaultStoreId, String fileName) async {
    final raw = _vaults[vaultStoreId]?[fileName];
    if (raw == null) {
      throw StateError('Working vault section not found: $fileName');
    }
    return Uint8List.fromList(raw);
  }

  @override
  Future<void> commitVault({
    required String vaultStoreId,
    required VaultFile header,
    required Map<String, Uint8List> sections,
  }) async {
    final next = <String, Uint8List>{};
    for (final entry in sections.entries) {
      next[entry.key] = Uint8List.fromList(entry.value);
    }
    next['header.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode(header.toJson())),
    );
    _vaults[vaultStoreId] = next;
  }

  @override
  Future<String> stageVault({
    required String vaultStoreId,
    required VaultFile header,
    required Map<String, Uint8List> sections,
  }) async {
    final stagedId = '$vaultStoreId.incoming';
    await commitVault(
      vaultStoreId: stagedId,
      header: header,
      sections: sections,
    );
    return stagedId;
  }

  @override
  Future<void> promoteStagedVault({
    required String stagedVaultStoreId,
    required String vaultStoreId,
  }) async {
    final staged = _vaults[stagedVaultStoreId];
    if (staged == null) {
      throw StateError('Staged vault not found: $stagedVaultStoreId');
    }
    _vaults[vaultStoreId] = Map<String, Uint8List>.from(staged);
    _vaults.remove(stagedVaultStoreId);
  }

  @override
  Future<void> discardVault(String vaultStoreId) async {
    _vaults.remove(vaultStoreId);
  }

  @override
  Future<Map<String, dynamic>> describeVault(String vaultStoreId) async {
    final files = _vaults[vaultStoreId] ?? const <String, Uint8List>{};
    return <String, dynamic>{
      'type': 'memory',
      'root': 'memory://vaults/$vaultStoreId',
      'files': files.map(
        (name, bytes) => MapEntry<String, int>(name, bytes.length),
      ),
    };
  }
}

class FilePrivateVaultStore implements PrivateVaultStore {
  const FilePrivateVaultStore({required this.baseDirectory});

  final Directory baseDirectory;

  Directory _dir(String vaultStoreId) => Directory(
    '${baseDirectory.path}${Platform.pathSeparator}vaults'
    '${Platform.pathSeparator}$vaultStoreId',
  );

  @override
  Future<bool> vaultExists(String vaultStoreId) async {
    return File(
      '${_dir(vaultStoreId).path}${Platform.pathSeparator}header.json',
    ).exists();
  }

  @override
  Future<VaultFile> readHeader(String vaultStoreId) async {
    final file = File(
      '${_dir(vaultStoreId).path}${Platform.pathSeparator}header.json',
    );
    if (!await file.exists()) {
      throw StateError('Working vault not found: $vaultStoreId');
    }
    return VaultFile.fromJson(
      Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map),
    );
  }

  @override
  Future<Uint8List> readSection(String vaultStoreId, String fileName) async {
    final file = File(
      '${_dir(vaultStoreId).path}${Platform.pathSeparator}$fileName',
    );
    if (!await file.exists()) {
      throw StateError('Working vault section not found: $fileName');
    }
    return file.readAsBytes();
  }

  @override
  Future<void> commitVault({
    required String vaultStoreId,
    required VaultFile header,
    required Map<String, Uint8List> sections,
  }) async {
    final dir = _dir(vaultStoreId);
    await dir.create(recursive: true);

    for (final entry in sections.entries) {
      await _atomicWriteBytes(
        File('${dir.path}${Platform.pathSeparator}${entry.key}'),
        entry.value,
      );
    }
    await _atomicWriteBytes(
      File('${dir.path}${Platform.pathSeparator}header.json'),
      Uint8List.fromList(utf8.encode(jsonEncode(header.toJson()))),
    );
  }

  @override
  Future<String> stageVault({
    required String vaultStoreId,
    required VaultFile header,
    required Map<String, Uint8List> sections,
  }) async {
    final stagedId = '$vaultStoreId.incoming';
    await discardVault(stagedId);
    await commitVault(
      vaultStoreId: stagedId,
      header: header,
      sections: sections,
    );
    return stagedId;
  }

  @override
  Future<void> promoteStagedVault({
    required String stagedVaultStoreId,
    required String vaultStoreId,
  }) async {
    final staged = _dir(stagedVaultStoreId);
    if (!await staged.exists()) {
      throw StateError('Staged vault not found: $stagedVaultStoreId');
    }
    final target = _dir(vaultStoreId);
    final backup = Directory('${target.path}.rollback');
    if (await backup.exists()) {
      await backup.delete(recursive: true);
    }
    if (await target.exists()) {
      await target.rename(backup.path);
    }
    try {
      await staged.rename(target.path);
      if (await backup.exists()) {
        await backup.delete(recursive: true);
      }
    } catch (_) {
      if (await backup.exists() && !await target.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
  }

  @override
  Future<void> discardVault(String vaultStoreId) async {
    final dir = _dir(vaultStoreId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<Map<String, dynamic>> describeVault(String vaultStoreId) async {
    final dir = _dir(vaultStoreId);
    final files = <String, int>{};
    if (await dir.exists()) {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        files[entity.uri.pathSegments.last] = await entity.length();
      }
    }
    return <String, dynamic>{'type': 'file', 'root': dir.path, 'files': files};
  }

  Future<void> _atomicWriteBytes(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await temp.rename(file.path);
  }
}

class InMemoryVaultRegistryStore implements VaultRegistryStore {
  final Map<String, VaultRegistryEntry> _entries =
      <String, VaultRegistryEntry>{};

  @override
  Future<List<VaultRegistryEntry>> readAll() async {
    return _entries.values.toList(growable: false);
  }

  @override
  Future<void> upsert(VaultRegistryEntry entry) async {
    _entries[entry.id] = entry;
  }

  @override
  Future<VaultRegistryEntry?> findActiveByVaultId(String vaultId) async {
    for (final entry in _entries.values) {
      if (entry.vaultId == vaultId && !entry.isConflict) {
        return entry;
      }
    }
    return null;
  }
}
