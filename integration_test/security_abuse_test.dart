import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/core/config/guardian_profiles.dart';
import 'package:nija/domain/models/vault_payload.dart';
import 'package:nija/domain/models/vault_transfer_result.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/private_vault_store.dart';
import 'package:nija/infrastructure/adapters/secure_crypto_adapter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const recoveryPhrase =
      'anchor apple arrow atlas beacon breeze canyon cedar cobalt ember harbor willow';
  const password = 'CorrectPass123';

  Future<Directory> tempStoreDirectory() async {
    final dir = await Directory.systemTemp.createTemp('nija-security-abuse-');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    return dir;
  }

  Future<DefaultVaultService> createService({
    InMemoryVaultStorageAdapter? storage,
    PrivateVaultStore? privateStore,
  }) async {
    return DefaultVaultService(
      storageAdapter: storage ?? InMemoryVaultStorageAdapter(),
      cryptoAdapter: SecureCryptoAdapter(),
      privateVaultStore:
          privateStore ??
          FilePrivateVaultStore(baseDirectory: await tempStoreDirectory()),
    );
  }

  Future<void> createVault(DefaultVaultService service, String filePath) {
    return service.createVault(
      filePath: filePath,
      vaultId: '$filePath-id',
      vaultName: '$filePath vault',
      guardianProfileId: GuardianProfiles.owl.id,
      password: password,
      recoveryPhrase: recoveryPhrase,
    );
  }

  test(
    'tampered document chunks fail closed without breaking vault payload',
    () async {
      final privateStore = FilePrivateVaultStore(
        baseDirectory: await tempStoreDirectory(),
      );
      final service = await createService(privateStore: privateStore);

      await createVault(service, 'tampered-document.nija');
      final sectionName = await service.persistVaultDocument(
        filePath: 'tampered-document.nija',
        password: password,
        documentId: 'doc-1',
        bytes: utf8.encode('sensitive document bytes'),
      );
      await service.persistVaultPayload(
        filePath: 'tampered-document.nija',
        password: password,
        payload: VaultPayload(
          schemaVersion: 1,
          items: [
            {
              'id': 'doc-1',
              'type': 'Documents',
              'title': 'Sensitive Document',
              'documentSection': sectionName,
            },
          ],
          notes: const [],
          tags: const [],
          settings: const {},
          audit: const [],
        ),
      );

      await privateStore.writeSection(
        'tampered-document.nija-id',
        'document_doc-1_chunk_000000.enc',
        Uint8List.fromList([1, 2, 3, 4]),
      );

      expect(
        () => service.readVaultDocument(
          filePath: 'tampered-document.nija',
          password: password,
          sectionName: sectionName,
        ),
        throwsA(anything),
      );
      final payload = await service.readVaultPayload(
        filePath: 'tampered-document.nija',
        password: password,
      );
      expect(payload.items.single['id'], 'doc-1');
    },
  );

  test(
    'document ids are sanitized before becoming private store filenames',
    () async {
      final privateStore = FilePrivateVaultStore(
        baseDirectory: await tempStoreDirectory(),
      );
      final service = await createService(privateStore: privateStore);

      await createVault(service, 'path-sanitize.nija');
      final sectionName = await service.persistVaultDocument(
        filePath: 'path-sanitize.nija',
        password: password,
        documentId: '../outside/evil:name',
        bytes: utf8.encode('sandboxed bytes'),
      );
      final files = Map<String, dynamic>.from(
        (await privateStore.describeVault('path-sanitize.nija-id'))['files']
            as Map,
      );

      expect(sectionName, startsWith('document_'));
      expect(sectionName, endsWith('.manifest.enc'));
      expect(sectionName, isNot(contains('..')));
      expect(sectionName, isNot(contains('/')));
      expect(sectionName, isNot(contains(r'\')));
      expect(files.keys, contains(sectionName));
      expect(
        files.keys.every((name) => !name.toString().contains('/')),
        isTrue,
      );
    },
  );

  test(
    'unconfirmed newer import and wrong credential leave active vault unchanged',
    () async {
      final storage = InMemoryVaultStorageAdapter();
      final service = await createService(storage: storage);

      await createVault(service, 'active-import.nija');
      await service.persistVaultPayload(
        filePath: 'active-import.nija',
        password: password,
        payload: const VaultPayload(
          schemaVersion: 1,
          items: [
            {'id': 'local-item', 'type': 'Login', 'title': 'Local Item'},
          ],
          notes: [],
          tags: [],
          settings: {},
          audit: [],
        ),
      );

      final raw = await storage.read(filePath: 'active-import.nija');
      final incoming = Map<String, dynamic>.from(jsonDecode(raw) as Map)
        ..['revision'] = 999
        ..['vaultVersionId'] = '00000000-0000-4000-8000-999999999999';
      await storage.write(
        filePath: 'incoming-newer-abuse.nija',
        content: jsonEncode(incoming),
      );

      final unconfirmed = await service.importNijaFile(
        filePath: 'incoming-newer-abuse.nija',
        unlockCredential: password,
      );
      expect(unconfirmed.status, ImportStatus.failed);

      final wrongCredential = await service.importNijaFile(
        filePath: 'incoming-newer-abuse.nija',
        unlockCredential: 'WrongPass123',
        confirmReplace: true,
      );
      expect(wrongCredential.status, ImportStatus.failed);

      final payload = await service.readVaultPayload(
        filePath: 'active-import.nija',
        password: password,
      );
      expect(payload.items.single['id'], 'local-item');
    },
  );

  test(
    'debug internals do not expose plaintext item or document content',
    () async {
      final service = await createService();

      await createVault(service, 'internals-redaction.nija');
      final sectionName = await service.persistVaultDocument(
        filePath: 'internals-redaction.nija',
        password: password,
        documentId: 'doc-1',
        bytes: utf8.encode('TOP_SECRET_DOCUMENT_BYTES'),
      );
      await service.persistVaultPayload(
        filePath: 'internals-redaction.nija',
        password: password,
        payload: VaultPayload(
          schemaVersion: 1,
          items: [
            {
              'id': 'secret-login',
              'type': 'Login',
              'title': 'TOP_SECRET_ITEM_TITLE',
              'fields': [
                {'label': 'password', 'value': 'TOP_SECRET_PASSWORD_VALUE'},
              ],
              'documentSection': sectionName,
            },
          ],
          notes: const [],
          tags: const [],
          settings: const {},
          audit: const [],
        ),
      );

      final internals = jsonEncode(
        await service.readVaultInternals(filePath: 'internals-redaction.nija'),
      );

      expect(internals, isNot(contains('TOP_SECRET_ITEM_TITLE')));
      expect(internals, isNot(contains('TOP_SECRET_PASSWORD_VALUE')));
      expect(internals, isNot(contains('TOP_SECRET_DOCUMENT_BYTES')));
    },
  );
}
