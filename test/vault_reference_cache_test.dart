import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nija/domain/models/vault_reference.dart';
import 'package:nija/infrastructure/adapters/vault_reference_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('vault reference cache persists source description', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = VaultReferenceCache();

    await cache.upsert(
      const VaultReference(
        id: 'web-private-vault.nija',
        label: 'Personal Vault',
        addedAtEpochMs: 10,
        lastOpenedAtEpochMs: 20,
        sourceDescription:
            'Browser private storage · selected file personal.nija',
      ),
    );

    final references = await cache.readAll();

    expect(references, hasLength(1));
    expect(references.first.sourceDescription, contains('Browser private'));
    expect(references.first.sourceDescription, contains('personal.nija'));
  });

  test('vault reference cache reads older entries without source metadata', () async {
    SharedPreferences.setMockInitialValues({
      'nija_vault_references_v1': jsonEncode([
        {
          'id': 'legacy.nija',
          'label': 'Legacy',
          'addedAtEpochMs': 1,
          'lastOpenedAtEpochMs': 2,
        },
      ]),
    });

    final references = await VaultReferenceCache().readAll();

    expect(references, hasLength(1));
    expect(references.first.sourceDescription, isEmpty);
  });
}
