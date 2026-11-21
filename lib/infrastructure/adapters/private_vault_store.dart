import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/models/vault_file.dart';
import '../../domain/models/vault_registry_entry.dart';

abstract class PrivateVaultStore {
  Future<bool> vaultExists(String vaultStoreId);
  Future<VaultFile> readHeader(String vaultStoreId);
  Future<Uint8List> readSection(String vaultStoreId, String fileName);
  Stream<List<int>> openSectionRead(String vaultStoreId, String fileName);
  Future<void> writeHeader(String vaultStoreId, VaultFile header);
  Future<void> writeSection(
    String vaultStoreId,
    String fileName,
    Uint8List bytes,
  );
  Future<void> writeSectionStream(
    String vaultStoreId,
    String fileName,
    Stream<List<int>> stream,
  );
  Future<void> commitVault({
    required String vaultStoreId,
    required VaultFile header,
    required Map<String, Uint8List> sections,
    Set<String>? keepExistingFiles,
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
  Stream<List<int>> openSectionRead(String vaultStoreId, String fileName) {
    final raw = _vaults[vaultStoreId]?[fileName];
    if (raw == null) {
      throw StateError('Working vault section not found: $fileName');
    }
    return Stream<List<int>>.value(raw);
  }

  @override
  Future<void> writeHeader(String vaultStoreId, VaultFile header) async {
    final vault = _vaults.putIfAbsent(
      vaultStoreId,
      () => <String, Uint8List>{},
    );
    vault['header.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode(header.toJson())),
    );
  }

  @override
  Future<void> writeSection(
    String vaultStoreId,
    String fileName,
    Uint8List bytes,
  ) async {
    final vault = _vaults.putIfAbsent(
      vaultStoreId,
      () => <String, Uint8List>{},
    );
    vault[fileName] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> writeSectionStream(
    String vaultStoreId,
    String fileName,
    Stream<List<int>> stream,
  ) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    await writeSection(vaultStoreId, fileName, Uint8List.fromList(bytes));
  }

  @override
  Future<void> commitVault({
    required String vaultStoreId,
    required VaultFile header,
    required Map<String, Uint8List> sections,
    Set<String>? keepExistingFiles,
  }) async {
    final existing = _vaults[vaultStoreId] ?? const <String, Uint8List>{};
    final next = <String, Uint8List>{};
    if (keepExistingFiles != null) {
      for (final fileName in keepExistingFiles) {
        final bytes = existing[fileName];
        if (bytes != null) {
          next[fileName] = Uint8List.fromList(bytes);
        }
      }
    }
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

  Directory _dir(String vaultStoreId) {
    _validateStoreSegment(vaultStoreId, label: 'vaultStoreId');
    return Directory(
      '${baseDirectory.path}${Platform.pathSeparator}vaults'
      '${Platform.pathSeparator}$vaultStoreId',
    );
  }

  File _sectionFile(String vaultStoreId, String fileName) {
    _validateSectionName(fileName);
    return File('${_dir(vaultStoreId).path}${Platform.pathSeparator}$fileName');
  }

  static bool _isValidStoreSegment(String value) {
    return !(value.isEmpty ||
        value == '.' ||
        value == '..' ||
        value.contains('/') ||
        value.contains('\\') ||
        value.contains('\x00') ||
        value.contains('..'));
  }

  static void _validateStoreSegment(String value, {required String label}) {
    if (!_isValidStoreSegment(value)) {
      throw ArgumentError.value(value, label, 'Invalid storage identifier.');
    }
  }

  static void _validateSectionName(String fileName) {
    if (fileName.isEmpty ||
        fileName == '.' ||
        fileName == '..' ||
        fileName.contains('/') ||
        fileName.contains('\\') ||
        fileName.contains('\x00') ||
        fileName.contains('..') ||
        fileName.endsWith('.tmp') ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(fileName)) {
      throw ArgumentError.value(fileName, 'fileName', 'Invalid section name.');
    }
  }

  @override
  Future<bool> vaultExists(String vaultStoreId) async {
    if (!_isValidStoreSegment(vaultStoreId)) return false;
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
    final file = _sectionFile(vaultStoreId, fileName);
    if (!await file.exists()) {
      throw StateError('Working vault section not found: $fileName');
    }
    return file.readAsBytes();
  }

  @override
  Stream<List<int>> openSectionRead(String vaultStoreId, String fileName) {
    final file = _sectionFile(vaultStoreId, fileName);
    if (!file.existsSync()) {
      throw StateError('Working vault section not found: $fileName');
    }
    return file.openRead();
  }

  @override
  Future<void> writeHeader(String vaultStoreId, VaultFile header) async {
    final dir = _dir(vaultStoreId);
    await dir.create(recursive: true);
    final cleanHeader = header.copyWith(
      encryptedSections: const <String, String>{},
      encryptedPayload: null,
    );
    await _atomicWriteBytes(
      File('${dir.path}${Platform.pathSeparator}header.json'),
      Uint8List.fromList(utf8.encode(jsonEncode(cleanHeader.toJson()))),
    );
  }

  @override
  Future<void> writeSection(
    String vaultStoreId,
    String fileName,
    Uint8List bytes,
  ) async {
    final dir = _dir(vaultStoreId);
    await dir.create(recursive: true);
    await _atomicWriteBytes(
      _sectionFile(vaultStoreId, fileName),
      bytes,
    );
  }

  @override
  Future<void> writeSectionStream(
    String vaultStoreId,
    String fileName,
    Stream<List<int>> stream,
  ) async {
    final dir = _dir(vaultStoreId);
    await dir.create(recursive: true);
    final target = _sectionFile(vaultStoreId, fileName);
    final temp = File(
      '${dir.path}${Platform.pathSeparator}$fileName.stream.tmp',
    );
    final sink = temp.openWrite();
    try {
      await sink.addStream(stream);
      await sink.flush();
      await sink.close();
      if (await target.exists()) {
        await target.delete();
      }
      await temp.rename(target.path);
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      if (await temp.exists()) {
        await temp.delete();
      }
      rethrow;
    }
  }

  @override
  Future<void> commitVault({
    required String vaultStoreId,
    required VaultFile header,
    required Map<String, Uint8List> sections,
    Set<String>? keepExistingFiles,
  }) async {
    final dir = _dir(vaultStoreId);
    await dir.create(recursive: true);

    for (final entry in sections.entries) {
      await _atomicWriteBytes(
        _sectionFile(vaultStoreId, entry.key),
        entry.value,
      );
    }
    final cleanHeader = header.copyWith(
      encryptedSections: const <String, String>{},
      encryptedPayload: null,
    );
    await _atomicWriteBytes(
      File('${dir.path}${Platform.pathSeparator}header.json'),
      Uint8List.fromList(utf8.encode(jsonEncode(cleanHeader.toJson()))),
    );
    final retained = <String>{
      ...sections.keys,
      'header.json',
      ...?keepExistingFiles,
    };
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.endsWith('.tmp') || retained.contains(name)) continue;
      await entity.delete();
    }
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
