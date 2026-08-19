import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/core/config/guardian_profiles.dart';
import 'package:nija/domain/models/vault_payload.dart';
import 'package:nija/infrastructure/adapters/file_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/private_vault_store.dart';
import 'package:nija/infrastructure/adapters/secure_crypto_adapter.dart';
import 'package:nija/infrastructure/adapters/vault_storage_adapter.dart';

const _basePhrase =
    'anchor apple arrow atlas beacon breeze canyon cedar cobalt ember harbor willow';

class _FailAfterFirstSnapshotWriteAdapter implements VaultStorageAdapter {
  _FailAfterFirstSnapshotWriteAdapter(this._delegate);

  final VaultStorageAdapter _delegate;
  var snapshotWrites = 0;

  @override
  Future<String> read({required String filePath}) {
    return _delegate.read(filePath: filePath);
  }

  @override
  Future<void> write({
    required String filePath,
    required String content,
  }) async {
    snapshotWrites++;
    if (snapshotWrites > 1) {
      throw StateError('snapshot write failed');
    }
    await _delegate.write(filePath: filePath, content: content);
  }
}

Future<DefaultVaultService> _createWebLikeService({
  required InMemoryVaultStorageAdapter storage,
}) async {
  return DefaultVaultService(
    storageAdapter: storage,
    cryptoAdapter: SecureCryptoAdapter(),
    privateVaultStore: InMemoryPrivateVaultStore(),
  );
}

Future<void> _createSampleVault(
  DefaultVaultService service, {
  required String filePath,
  required String vaultId,
}) async {
  await service.createVault(
    filePath: filePath,
    vaultId: vaultId,
    vaultName: 'Sample Vault',
    guardianProfileId: GuardianProfiles.owl.id,
    password: 'CorrectPass123',
    recoveryPhrase: _basePhrase,
  );
}

Future<VaultPayload> _reloadPayload({
  required VaultStorageAdapter storage,
  required PrivateVaultStore privateVaultStore,
  required String filePath,
}) async {
  final reloaded = DefaultVaultService(
    storageAdapter: storage,
    cryptoAdapter: SecureCryptoAdapter(),
    privateVaultStore: privateVaultStore,
  );
  await reloaded.unlockVault(
    filePath: filePath,
    password: 'CorrectPass123',
  );
  return reloaded.readVaultPayload(
    filePath: filePath,
    password: 'CorrectPass123',
  );
}

void main() {
  group('web-like snapshot persistence', () {
    test('persisted payload survives fresh in-memory working store', () async {
      final storage = InMemoryVaultStorageAdapter();
      final service = await _createWebLikeService(storage: storage);
      await _createSampleVault(
        service,
        filePath: 'web-like.nija',
        vaultId: 'web-like-id',
      );
      await service.persistVaultPayload(
        filePath: 'web-like.nija',
        password: 'CorrectPass123',
        payload: const VaultPayload(
          schemaVersion: 1,
          items: [
            {'id': 'item-1', 'type': 'Login', 'title': 'Saved Login'},
          ],
          notes: [],
          tags: [],
          settings: {},
          audit: [],
        ),
      );

      final payload = await _reloadPayload(
        storage: storage,
        privateVaultStore: InMemoryPrivateVaultStore(),
        filePath: 'web-like.nija',
      );

      expect(payload.items.single['title'], 'Saved Login');
    });

    test('sequential payload persists accumulate items in snapshot', () async {
      final storage = InMemoryVaultStorageAdapter();
      final service = await _createWebLikeService(storage: storage);
      await _createSampleVault(
        service,
        filePath: 'web-sequential.nija',
        vaultId: 'web-sequential-id',
      );

      await service.persistVaultPayload(
        filePath: 'web-sequential.nija',
        password: 'CorrectPass123',
        payload: const VaultPayload(
          schemaVersion: 1,
          items: [
            {'id': 'item-1', 'type': 'Login', 'title': 'First Login'},
          ],
          notes: [],
          tags: [],
          settings: {},
          audit: [],
        ),
      );
      await service.persistVaultPayload(
        filePath: 'web-sequential.nija',
        password: 'CorrectPass123',
        payload: const VaultPayload(
          schemaVersion: 1,
          items: [
            {'id': 'item-1', 'type': 'Login', 'title': 'First Login'},
            {'id': 'item-2', 'type': 'Login', 'title': 'Second Login'},
          ],
          notes: [],
          tags: [],
          settings: {},
          audit: [],
        ),
      );

      final payload = await _reloadPayload(
        storage: storage,
        privateVaultStore: InMemoryPrivateVaultStore(),
        filePath: 'web-sequential.nija',
      );

      expect(
        payload.items.map((item) => item['title']).toList(),
        ['First Login', 'Second Login'],
      );
    });

    test('snapshot write uses vault file handle when vault id differs', () async {
      final storage = InMemoryVaultStorageAdapter();
      final service = await _createWebLikeService(storage: storage);
      await _createSampleVault(
        service,
        filePath: 'web-handle.nija',
        vaultId: 'different-vault-id',
      );
      await service.persistVaultPayload(
        filePath: 'web-handle.nija',
        password: 'CorrectPass123',
        payload: const VaultPayload(
          schemaVersion: 1,
          items: [
            {'id': 'item-1', 'type': 'Login', 'title': 'Handle Mapped Login'},
          ],
          notes: [],
          tags: [],
          settings: {},
          audit: [],
        ),
      );

      final raw = await storage.read(filePath: 'web-handle.nija');
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      expect(decoded['vaultId'], 'different-vault-id');
      expect(decoded['revision'], greaterThan(1));

      final payload = await _reloadPayload(
        storage: storage,
        privateVaultStore: InMemoryPrivateVaultStore(),
        filePath: 'web-handle.nija',
      );
      expect(payload.items.single['title'], 'Handle Mapped Login');
    });

    test('persistVaultPayload surfaces snapshot write failures', () async {
      final storage = _FailAfterFirstSnapshotWriteAdapter(
        InMemoryVaultStorageAdapter(),
      );
      final service = DefaultVaultService(
        storageAdapter: storage,
        cryptoAdapter: SecureCryptoAdapter(),
        privateVaultStore: InMemoryPrivateVaultStore(),
      );
      await _createSampleVault(
        service,
        filePath: 'web-fail.nija',
        vaultId: 'web-fail-id',
      );

      await expectLater(
        service.persistVaultPayload(
          filePath: 'web-fail.nija',
          password: 'CorrectPass123',
          payload: const VaultPayload(
            schemaVersion: 1,
            items: [
              {'id': 'item-1', 'type': 'Login', 'title': 'Should Fail Snapshot'},
            ],
            notes: [],
            tags: [],
            settings: {},
            audit: [],
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(storage.snapshotWrites, 2);
    });
  });

  group('mobile-like private store persistence', () {
    test(
      'private store and .nija snapshot both survive service reload',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'nija-mobile-persist-',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final nijaPath = '${tempDir.path}/nija_vault.nija';
        final privateStore = FilePrivateVaultStore(baseDirectory: tempDir);
        final service = DefaultVaultService(
          storageAdapter: FileVaultStorageAdapter(),
          cryptoAdapter: SecureCryptoAdapter(),
          privateVaultStore: privateStore,
        );

        await service.createVault(
          filePath: nijaPath,
          vaultId: 'mobile-vault-id',
          vaultName: 'Mobile Vault',
          guardianProfileId: GuardianProfiles.owl.id,
          password: 'CorrectPass123',
          recoveryPhrase: _basePhrase,
        );
        await service.persistVaultPayload(
          filePath: nijaPath,
          password: 'CorrectPass123',
          payload: const VaultPayload(
            schemaVersion: 1,
            items: [
              {'id': 'item-1', 'type': 'Login', 'title': 'Mobile Login'},
            ],
            notes: [],
            tags: [],
            settings: {},
            audit: [],
          ),
        );

        expect(await File(nijaPath).exists(), isTrue);
        expect(await privateStore.vaultExists('mobile-vault-id'), isTrue);
        final header = await privateStore.readHeader('mobile-vault-id');
        expect(header.revision, 2);

        final payload = await _reloadPayload(
          storage: FileVaultStorageAdapter(),
          privateVaultStore: FilePrivateVaultStore(baseDirectory: tempDir),
          filePath: nijaPath,
        );
        expect(payload.items.single['title'], 'Mobile Login');
      },
    );

    test('private store commit happens before snapshot write on persist', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nija-mobile-order-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final nijaPath = '${tempDir.path}/ordered.nija';
      final privateStore = FilePrivateVaultStore(baseDirectory: tempDir);
      final service = DefaultVaultService(
        storageAdapter: FileVaultStorageAdapter(),
        cryptoAdapter: SecureCryptoAdapter(),
        privateVaultStore: privateStore,
      );

      await service.createVault(
        filePath: nijaPath,
        vaultId: 'ordered-vault-id',
        vaultName: 'Ordered Vault',
        guardianProfileId: GuardianProfiles.owl.id,
        password: 'CorrectPass123',
        recoveryPhrase: _basePhrase,
      );
      await service.persistVaultPayload(
        filePath: nijaPath,
        password: 'CorrectPass123',
        payload: const VaultPayload(
          schemaVersion: 1,
          items: [
            {'id': 'item-1', 'type': 'Login', 'title': 'Ordered Login'},
          ],
          notes: [],
          tags: [],
          settings: {},
          audit: [],
        ),
      );

      final privateFiles = Map<String, dynamic>.from(
        (await privateStore.describeVault('ordered-vault-id'))['files'] as Map,
      );
      expect(privateFiles.containsKey('items.enc'), isTrue);

      final raw = await File(nijaPath).readAsString();
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      expect(decoded['revision'], 2);
      expect(decoded['encryptedSections'], isNotEmpty);
    });

    test('reload prefers hydrated private store over stale snapshot header', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nija-mobile-hydrated-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final nijaPath = '${tempDir.path}/hydrated.nija';
      final privateStore = FilePrivateVaultStore(baseDirectory: tempDir);
      final service = DefaultVaultService(
        storageAdapter: FileVaultStorageAdapter(),
        cryptoAdapter: SecureCryptoAdapter(),
        privateVaultStore: privateStore,
      );

      await service.createVault(
        filePath: nijaPath,
        vaultId: 'hydrated-vault-id',
        vaultName: 'Hydrated Vault',
        guardianProfileId: GuardianProfiles.owl.id,
        password: 'CorrectPass123',
        recoveryPhrase: _basePhrase,
      );
      await service.persistVaultPayload(
        filePath: nijaPath,
        password: 'CorrectPass123',
        payload: const VaultPayload(
          schemaVersion: 1,
          items: [
            {'id': 'item-1', 'type': 'Login', 'title': 'Hydrated Login'},
          ],
          notes: [],
          tags: [],
          settings: {},
          audit: [],
        ),
      );

      final reloaded = DefaultVaultService(
        storageAdapter: FileVaultStorageAdapter(),
        cryptoAdapter: SecureCryptoAdapter(),
        privateVaultStore: FilePrivateVaultStore(baseDirectory: tempDir),
      );
      await reloaded.unlockVault(
        filePath: nijaPath,
        password: 'CorrectPass123',
      );
      final payload = await reloaded.readVaultPayload(
        filePath: nijaPath,
        password: 'CorrectPass123',
      );

      expect(payload.items.single['title'], 'Hydrated Login');
      expect(await privateStore.vaultExists('hydrated-vault-id'), isTrue);
    });
  });
}
