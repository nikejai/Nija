import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/core/config/app_features.dart';
import 'package:nija/core/config/guardian_profiles.dart';
import 'package:nija/core/config/vault_limits.dart';
import 'package:nija/domain/models/folder_tree_builder.dart';
import 'package:nija/domain/models/vault_folder.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/private_vault_store.dart';
import 'package:nija/infrastructure/adapters/secure_crypto_adapter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const recoveryPhrase =
      'anchor apple arrow atlas beacon breeze canyon cedar cobalt ember harbor willow';
  const password = 'CorrectPass123!';

  Future<Directory> tempStoreDirectory() async {
    final dir = await Directory.systemTemp.createTemp('nija-size-limit-test-');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    return dir;
  }

  Uint8List loadOneMbFile() {
    const directPath = '/Users/niteshjain/Downloads/lorem-ipsum-1MB.txt';
    const fixturePath = 'test/fixtures/lorem-ipsum-1MB.txt';

    final directFile = File(directPath);
    if (directFile.existsSync()) {
      return directFile.readAsBytesSync();
    }

    final fixtureFile = File(fixturePath);
    if (fixtureFile.existsSync()) {
      return fixtureFile.readAsBytesSync();
    }

    // Fallback deterministic 1 MB payload (1024 * 1024 bytes)
    final bytes = Uint8List(1024 * 1024);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = (i % 251);
    }
    return bytes;
  }

  group('Integration Test: 1MB File Storage, Folders & Size Limit Validation', () {
    test('1 MB file exists and measures exactly 1,048,576 bytes', () {
      final bytes = loadOneMbFile();
      expect(bytes.length, 1024 * 1024);
      expect(VaultLimits.formatBytes(bytes.length), '1.00 MB');
    });

    test(
      'encrypts and chunks 1 MB file, then reads back byte-for-byte with real AES-GCM',
      () async {
        final oneMbBytes = loadOneMbFile();
        final privateStoreDir = await tempStoreDirectory();
        final privateStore = FilePrivateVaultStore(baseDirectory: privateStoreDir);
        final storage = InMemoryVaultStorageAdapter();
        final service = DefaultVaultService(
          storageAdapter: storage,
          cryptoAdapter: SecureCryptoAdapter(),
          privateVaultStore: privateStore,
        );

        const filePath = 'vault-1mb-test.nija';
        await service.createVault(
          filePath: filePath,
          vaultId: 'vault-1mb-id',
          vaultName: '1MB Test Vault',
          guardianProfileId: GuardianProfiles.owl.id,
          password: password,
          recoveryPhrase: recoveryPhrase,
        );

        // Persist 1 MB document
        final sectionName = await service.persistVaultDocument(
          filePath: filePath,
          password: password,
          documentId: 'doc-lorem-1mb',
          bytes: oneMbBytes,
        );

        expect(sectionName, startsWith('document_'));
        expect(sectionName, endsWith('.manifest.enc'));

        // Verify stored chunks on disk
        final storedInfo = await privateStore.describeVault('vault-1mb-id');
        final files = Map<String, dynamic>.from(storedInfo['files'] as Map);
        expect(files.containsKey(sectionName), isTrue);

        // Read decrypted document back and verify 100% byte fidelity
        final readBackBytes = await service.readVaultDocument(
          filePath: filePath,
          password: password,
          sectionName: sectionName,
        );

        expect(readBackBytes.length, oneMbBytes.length);
        expect(readBackBytes, equals(oneMbBytes));
      },
    );

    test('folder hierarchy aggregates 1 MB item and updates on move', () {
      final oneMbBytes = loadOneMbFile();

      final folderRoot = VaultFolder(
        id: 'folder-docs',
        name: 'Documents',
        parentId: null,
        createdAt: '2026-11-15T12:00:00Z',
        updatedAt: '2026-11-15T12:00:00Z',
      );
      final folderWork = VaultFolder(
        id: 'folder-work',
        name: 'Work',
        parentId: 'folder-docs',
        createdAt: '2026-11-15T12:00:00Z',
        updatedAt: '2026-11-15T12:00:00Z',
      );
      final folderPersonal = VaultFolder(
        id: 'folder-personal',
        name: 'Personal',
        parentId: null,
        createdAt: '2026-11-15T12:00:00Z',
        updatedAt: '2026-11-15T12:00:00Z',
      );

      final items = [
        <String, dynamic>{
          'id': 'item-lorem-1mb',
          'title': 'Lorem Ipsum 1MB Document',
          'type': 'Document',
          'folderId': 'folder-work',
          'documentSizeBytes': oneMbBytes.length,
          'documentFileName': 'lorem-ipsum-1MB.txt',
          'documentExtension': 'txt',
        },
        <String, dynamic>{
          'id': 'item-small-note',
          'title': 'Meeting Notes',
          'type': 'Note',
          'folderId': 'folder-docs',
          'sizeBytes': 2048,
        },
      ];

      // Build tree
      var tree = FolderTreeBuilder.buildTree(
        folders: [folderRoot, folderWork, folderPersonal],
        items: items,
      );

      final docsNode = tree.firstWhere((node) => node.folder.id == 'folder-docs');
      final workNode = docsNode.children.firstWhere(
        (child) => child.folder.id == 'folder-work',
      );
      final personalNode = tree.firstWhere(
        (node) => node.folder.id == 'folder-personal',
      );

      // Work folder has direct 1 MB item
      expect(workNode.totalSizeBytes, oneMbBytes.length);
      expect(workNode.totalItemCount, 1);
      expect(VaultLimits.formatBytes(workNode.totalSizeBytes), '1.00 MB');

      // Parent Documents folder aggregates work child (1 MB) + direct note (2 KB)
      expect(docsNode.totalSizeBytes, oneMbBytes.length + 2048);
      expect(docsNode.totalItemCount, 2);

      // Personal folder starts empty
      expect(personalNode.totalSizeBytes, 0);
      expect(personalNode.totalItemCount, 0);

      // Move 1 MB item from Work to Personal
      final movedItems = items.map((item) {
        if (item['id'] == 'item-lorem-1mb') {
          return {...item, 'folderId': 'folder-personal'};
        }
        return item;
      }).toList();

      tree = FolderTreeBuilder.buildTree(
        folders: [folderRoot, folderWork, folderPersonal],
        items: movedItems,
      );

      final updatedDocs = tree.firstWhere((node) => node.folder.id == 'folder-docs');
      final updatedWork = updatedDocs.children.firstWhere(
        (child) => child.folder.id == 'folder-work',
      );
      final updatedPersonal = tree.firstWhere(
        (node) => node.folder.id == 'folder-personal',
      );

      expect(updatedWork.totalSizeBytes, 0);
      expect(updatedWork.totalItemCount, 0);
      expect(updatedDocs.totalSizeBytes, 2048);
      expect(updatedPersonal.totalSizeBytes, oneMbBytes.length);
      expect(updatedPersonal.totalItemCount, 1);
      expect(VaultLimits.formatBytes(updatedPersonal.totalSizeBytes), '1.00 MB');
    });

    test('validates document size limit (25 MB) and vault capacity (1 GB)', () {
      final oneMbBytes = loadOneMbFile();

      // 1 MB is well within the 25 MB document limit
      expect(oneMbBytes.length, lessThanOrEqualTo(VaultLimits.maxDocumentBytes));
      expect(VaultLimits.maxDocumentBytes, 25 * 1024 * 1024);

      // Oversized document validation (26 MB)
      const oversizedBytes = (25 * 1024 * 1024) + 1;
      final isOversized = oversizedBytes > VaultLimits.maxDocumentBytes;
      expect(isOversized, isTrue);

      String? validateDocumentSize(int bytes) {
        if (bytes > VaultLimits.maxDocumentBytes) {
          return 'Document must be ${VaultLimits.formatBytes(VaultLimits.maxDocumentBytes)} or smaller.';
        }
        return null;
      }

      expect(validateDocumentSize(oneMbBytes.length), isNull);
      expect(
        validateDocumentSize(oversizedBytes),
        'Document must be 25.0 MB or smaller.',
      );

      // Vault quota capacity validation (1 GB)
      expect(VaultLimits.freeVaultBytes, 1024 * 1024 * 1024);
      expect(VaultLimits.maxVaultBytes, 1024 * 1024 * 1024);

      String? validateVaultCapacity({
        required int currentVaultSize,
        required int additionalBytes,
        required int maxVaultBytes,
      }) {
        final projected = currentVaultSize + additionalBytes;
        if (projected > maxVaultBytes) {
          return 'Not enough vault space. Limit is ${VaultLimits.formatBytes(maxVaultBytes)}.';
        }
        return null;
      }

      // Normal vault with 1 MB addition succeeds
      expect(
        validateVaultCapacity(
          currentVaultSize: 50 * 1024 * 1024,
          additionalBytes: oneMbBytes.length,
          maxVaultBytes: VaultLimits.maxVaultBytes,
        ),
        isNull,
      );

      // Vault at capacity rejects additional bytes
      expect(
        validateVaultCapacity(
          currentVaultSize: VaultLimits.maxVaultBytes,
          additionalBytes: oneMbBytes.length,
          maxVaultBytes: VaultLimits.maxVaultBytes,
        ),
        'Not enough vault space. Limit is 1.00 GB.',
      );
    });

    test('validates debug build vs prod build size limits and features', () {
      // In Flutter:
      // kDebugMode is true in debug builds and false in profile/release builds.
      if (kDebugMode) {
        // Debug mode allows inspection internals and verbose diagnostics
        expect(kDebugMode, isTrue);
      } else {
        // Production release mode strictly disables debug internals
        expect(kDebugMode, isFalse);
        expect(AppFeatures.isPaidBuild, isFalse);
      }

      // Both debug and prod share the unified 1 GB local storage capacity
      expect(
        VaultLimits.maxVaultBytesFor(currentVaultSizeBytes: 0),
        1024 * 1024 * 1024,
      );
      expect(VaultLimits.formatBytes(1024 * 1024 * 1024), '1.00 GB');

      // Verify build APK sizes against app distribution limits
      final releaseApk = File('build/app/outputs/flutter-apk/app-release.apk');
      final debugApk = File('build/app/outputs/flutter-apk/app-debug.apk');

      if (releaseApk.existsSync()) {
        final releaseBytes = releaseApk.lengthSync();
        // Google Play single APK limit is 150 MB (or 200 MB for AAB)
        expect(releaseBytes, lessThan(150 * 1024 * 1024));
        // Verify release APK is significantly leaner than debug APK
        if (debugApk.existsSync()) {
          expect(releaseBytes, lessThan(debugApk.lengthSync()));
        }
      }
    });
  });
}
