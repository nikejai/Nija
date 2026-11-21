import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/core/config/guardian_profiles.dart';
import 'package:nija/domain/models/vault_file.dart';
import 'package:nija/domain/models/vault_payload.dart';
import 'package:nija/domain/models/vault_transfer_result.dart';
import 'package:nija/infrastructure/adapters/file_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/private_vault_store.dart';
import 'package:nija/infrastructure/adapters/prototype_crypto_adapter.dart';
import 'package:nija/infrastructure/adapters/streaming_vault_container.dart';

void main() {
  group('StreamingVaultContainer', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('streaming_vault_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('packs and unpacks a vault roundtrip with exact binary sections', () async {
      final store = FilePrivateVaultStore(baseDirectory: tempDir);
      final vaultId = 'test-streaming-vault-id';

      // Create dummy header and sections
      final dummyHeader = VaultFile(
        format: 'Nija',
        formatVersion: 1,
        schemaVersion: 1,
        storageLayoutVersion: 1,
        manifestVersion: 1,
        vaultId: vaultId,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        vaultVersionId: 'version-1',
        revision: 1,
        guardian: const GuardianMetadata(id: 'owl', profile: 'owl'),
        kdf: const KdfMetadata(
          name: 'argon2id',
          version: 19,
          memoryKb: 65536,
          iterations: 3,
          parallelism: 1,
          salt: 'salt',
        ),
        recoveryKdf: const KdfMetadata(
          name: 'argon2id',
          version: 19,
          memoryKb: 65536,
          iterations: 3,
          parallelism: 1,
          salt: 'recoverySalt',
        ),
        cipher: const CipherMetadata(
          name: 'xchacha20poly1305',
          nonce: 'nonce',
        ),
        encryptedVaultKey: 'master',
        encryptedVaultKeyByRecovery: 'recovery',
      );
      await store.writeHeader(vaultId, dummyHeader);

      final dummyItems = utf8.encode('{"items":[{"id":"1","title":"Secret"}]}');
      final dummyNotes = utf8.encode('{"notes":[{"id":"n1","title":"Note"}]}');
      final dummyChunk = Uint8List.fromList(List<int>.generate(1024 * 64, (i) => i % 256));

      await store.writeSection(vaultId, 'items.enc', Uint8List.fromList(dummyItems));
      await store.writeSection(vaultId, 'notes.enc', Uint8List.fromList(dummyNotes));
      await store.writeSection(vaultId, 'document_doc1_chunk_000000.enc', dummyChunk);

      final testFile = File('${tempDir.path}/export.nija');
      await StreamingVaultContainer.packPrivateStoreToFile(
        store: store,
        vaultStoreId: vaultId,
        targetFile: testFile,
      );

      expect(await testFile.exists(), isTrue);
      expect(await StreamingVaultContainer.isContainerFile(testFile.path), isTrue);

      final unpackStore = FilePrivateVaultStore(
        baseDirectory: Directory('${tempDir.path}/unpacked'),
      );
      final targetStoreId = 'unpacked-vault-id';

      await StreamingVaultContainer.unpackFileToPrivateStore(
        sourceFile: testFile,
        store: unpackStore,
        targetStoreId: targetStoreId,
      );

      final unpackedItems = await unpackStore.readSection(targetStoreId, 'items.enc');
      final unpackedNotes = await unpackStore.readSection(targetStoreId, 'notes.enc');
      final unpackedChunk = await unpackStore.readSection(
        targetStoreId,
        'document_doc1_chunk_000000.enc',
      );

      expect(unpackedItems, equals(dummyItems));
      expect(unpackedNotes, equals(dummyNotes));
      expect(unpackedChunk, equals(dummyChunk));
    });

    test('peekHeaderFromFile extracts header from prefix without unpacking entire container', () async {
      final baseDir = Directory('${tempDir.path}/store');
      final store = FilePrivateVaultStore(baseDirectory: baseDir);
      final service = DefaultVaultService(
        storageAdapter: const FileVaultStorageAdapter(),
        cryptoAdapter: PrototypeCryptoAdapter(),
        privateVaultStore: store,
      );

      const password = 'Password123';
      const phrase = 'word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12';

      await service.createVault(
        filePath: '${tempDir.path}/created.nija',
        vaultId: 'created-vault-id',
        vaultName: 'My Streaming Vault',
        guardianProfileId: GuardianProfiles.owl.id,
        password: password,
        recoveryPhrase: phrase,
      );

      final exportPath = '${tempDir.path}/my_export.nija';
      final exportResult = await service.exportVault(
        vaultId: 'created-vault-id',
        destinationPath: exportPath,
      );
      expect(exportResult.status, ExportStatus.exported);

      final peeked = await StreamingVaultContainer.peekHeaderFromFile(exportPath);
      expect(peeked, isNotNull);
      expect(peeked!.vaultId, 'created-vault-id');
      expect(peeked.guardian.profile, GuardianProfiles.owl.id);
      expect(peeked.format, 'Nija');
    });

    test('exportVault produces streaming V2 container and importNijaFile imports it seamlessly', () async {
      final baseDir1 = Directory('${tempDir.path}/store1');
      final store1 = FilePrivateVaultStore(baseDirectory: baseDir1);
      final service1 = DefaultVaultService(
        storageAdapter: const FileVaultStorageAdapter(),
        cryptoAdapter: PrototypeCryptoAdapter(),
        privateVaultStore: store1,
      );

      const password = 'Password123';
      const phrase = 'word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12';

      await service1.createVault(
        filePath: '${tempDir.path}/source.nija',
        vaultId: 'source-vault-id',
        vaultName: 'Source Vault',
        guardianProfileId: GuardianProfiles.owl.id,
        password: password,
        recoveryPhrase: phrase,
      );

      await service1.persistVaultPayload(
        filePath: '${tempDir.path}/source.nija',
        password: password,
        payload: const VaultPayload(
          schemaVersion: 1,
          items: [
            {'id': 'item-1', 'title': 'Streaming Login Item', 'type': 'Login'},
          ],
          notes: [],
          tags: [],
          settings: {},
          audit: [],
        ),
      );

      final packagePath = '${tempDir.path}/package.nija';
      final exportRes = await service1.exportVault(
        vaultId: 'source-vault-id',
        destinationPath: packagePath,
      );
      expect(exportRes.status, ExportStatus.exported);
      expect(await StreamingVaultContainer.isContainerFile(packagePath), isTrue);

      final baseDir2 = Directory('${tempDir.path}/store2');
      final store2 = FilePrivateVaultStore(baseDirectory: baseDir2);
      final service2 = DefaultVaultService(
        storageAdapter: const FileVaultStorageAdapter(),
        cryptoAdapter: PrototypeCryptoAdapter(),
        privateVaultStore: store2,
      );

      final importRes = await service2.importNijaFile(
        filePath: packagePath,
        unlockCredential: password,
      );
      expect(importRes.status, ImportStatus.imported);
      expect(importRes.vaultId, 'source-vault-id');

      final unlockedPayload = await service2.readVaultPayload(
        filePath: packagePath,
        password: password,
      );
      expect(unlockedPayload.items.single['title'], 'Streaming Login Item');
    });

    test('legacy json vault files continue to import without errors', () async {
      final store = FilePrivateVaultStore(baseDirectory: tempDir);
      final service = DefaultVaultService(
        storageAdapter: const FileVaultStorageAdapter(),
        cryptoAdapter: PrototypeCryptoAdapter(),
        privateVaultStore: store,
      );

      const password = 'Password123';
      const phrase = 'word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12';

      // Create a legacy snapshot file (JSON)
      final legacyService = DefaultVaultService(
        storageAdapter: InMemoryVaultStorageAdapter(),
        cryptoAdapter: PrototypeCryptoAdapter(),
        privateVaultStore: InMemoryPrivateVaultStore(),
      );
      await legacyService.createVault(
        filePath: 'legacy.nija',
        vaultId: 'legacy-id',
        vaultName: 'Legacy Vault',
        guardianProfileId: GuardianProfiles.owl.id,
        password: password,
        recoveryPhrase: phrase,
      );
      final legacyRaw = await legacyService.readRawVaultFile(filePath: 'legacy.nija');

      final legacyFile = File('${tempDir.path}/legacy.nija');
      await legacyFile.writeAsString(legacyRaw);

      expect(await StreamingVaultContainer.isContainerFile(legacyFile.path), isFalse);

      final importRes = await service.importNijaFile(
        filePath: legacyFile.path,
        unlockCredential: password,
      );
      expect(importRes.status, ImportStatus.imported);
      expect(importRes.vaultId, 'legacy-id');
    });

    test('rejects path-traversal section filenames in container stream', () async {
      final unpackStore = FilePrivateVaultStore(
        baseDirectory: Directory('${tempDir.path}/traversal_out'),
      );
      final maliciousName = utf8.encode('../escaped.txt');
      final payload = utf8.encode('pwned');
      final bytes = BytesBuilder();
      bytes.add(StreamingVaultContainer.magicBytes);
      final meta = ByteData(4 + maliciousName.length + 8);
      meta.setUint32(0, maliciousName.length, Endian.big);
      for (var i = 0; i < maliciousName.length; i++) {
        meta.setUint8(4 + i, maliciousName[i]);
      }
      meta.setUint64(4 + maliciousName.length, payload.length, Endian.big);
      bytes.add(meta.buffer.asUint8List());
      bytes.add(payload);
      bytes.add(Uint8List(4));

      await expectLater(
        StreamingVaultContainer.unpackStreamToPrivateStore(
          stream: Stream<List<int>>.value(bytes.toBytes()),
          store: unpackStore,
          targetStoreId: 'target-vault',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(File('${tempDir.path}/traversal_out/vaults/escaped.txt').existsSync(), isFalse);
    });

    test('rejects oversized section name length before allocating buffer', () async {
      final unpackStore = FilePrivateVaultStore(
        baseDirectory: Directory('${tempDir.path}/oversized_out'),
      );
      final bytes = BytesBuilder();
      bytes.add(StreamingVaultContainer.magicBytes);
      final nameLen = ByteData(4)..setUint32(0, 1024 * 1024, Endian.big);
      bytes.add(nameLen.buffer.asUint8List());

      await expectLater(
        StreamingVaultContainer.unpackStreamToPrivateStore(
          stream: Stream<List<int>>.value(bytes.toBytes()),
          store: unpackStore,
          targetStoreId: 'target-vault',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('containerBytesToJsonSnapshot converts NIJA V2 bytes for Web import', () async {
      final store = FilePrivateVaultStore(baseDirectory: tempDir);
      final service = DefaultVaultService(
        storageAdapter: const FileVaultStorageAdapter(),
        cryptoAdapter: PrototypeCryptoAdapter(),
        privateVaultStore: store,
      );
      const password = 'Password123';
      const phrase = 'word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12';
      await service.createVault(
        filePath: '${tempDir.path}/mobile.nija',
        vaultId: 'mobile-to-web-id',
        vaultName: 'Mobile Vault',
        guardianProfileId: GuardianProfiles.owl.id,
        password: password,
        recoveryPhrase: phrase,
      );
      final exportPath = '${tempDir.path}/mobile_export.nija';
      await service.exportVault(
        vaultId: 'mobile-to-web-id',
        destinationPath: exportPath,
      );
      final bytes = await File(exportPath).readAsBytes();
      final peeked = StreamingVaultContainer.peekHeaderFromBytes(bytes);
      expect(peeked?.vaultId, 'mobile-to-web-id');

      final jsonSnapshot = StreamingVaultContainer.containerBytesToJsonSnapshot(bytes);
      final webStorage = InMemoryVaultStorageAdapter();
      await webStorage.write(filePath: 'web_import.nija', content: jsonSnapshot);
      final webService = DefaultVaultService(
        storageAdapter: webStorage,
        cryptoAdapter: PrototypeCryptoAdapter(),
        privateVaultStore: InMemoryPrivateVaultStore(),
      );
      final importRes = await webService.importNijaFile(
        filePath: 'web_import.nija',
        unlockCredential: password,
      );
      expect(importRes.status, ImportStatus.imported);
      expect(importRes.vaultId, 'mobile-to-web-id');
    });
  });
}
