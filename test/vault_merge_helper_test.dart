import 'package:flutter_test/flutter_test.dart';
import 'package:nija/application/services/vault_merge_helper.dart';
import 'package:nija/domain/models/vault_payload.dart';

void main() {
  const helper = VaultMergeHelper();

  test('builds conflict plan by stable item and note ids', () {
    const current = VaultPayload(
      schemaVersion: 1,
      items: [
        {'id': 'shared', 'title': 'Email', 'type': 'Login', 'version': 1},
        {'id': 'current-only', 'title': 'Bank', 'type': 'Login'},
      ],
      notes: [
        {'id': 'same-note', 'title': 'Note', 'delta': []},
      ],
      tags: [],
      settings: {},
      audit: [],
    );
    const imported = VaultPayload(
      schemaVersion: 1,
      items: [
        {'id': 'shared', 'title': 'Email', 'type': 'Login', 'version': 2},
        {'id': 'imported-only', 'title': 'Wi-Fi', 'type': 'Password'},
      ],
      notes: [
        {'id': 'same-note', 'title': 'Note', 'delta': []},
      ],
      tags: [],
      settings: {},
      audit: [],
    );

    final plan = helper.buildPlan(current: current, imported: imported);

    expect(plan.totalCount, 4);
    expect(plan.conflictCount, 2);
    expect(plan.identicalCount, 1);
    expect(
      plan.entries.where(
        (entry) => entry.status == VaultMergeEntryStatus.conflict,
      ),
      hasLength(1),
    );
  });

  test('imported-only additions do not need manual resolution', () {
    const current = VaultPayload(
      schemaVersion: 1,
      items: [
        {'id': 'shared', 'title': 'Email', 'type': 'Login'},
      ],
      notes: [],
      tags: [],
      settings: {},
      audit: [],
    );
    const imported = VaultPayload(
      schemaVersion: 1,
      items: [
        {'id': 'shared', 'title': 'Email', 'type': 'Login'},
        {'id': 'new-cloud-item', 'title': 'Cloud item', 'type': 'Login'},
      ],
      notes: [],
      tags: [],
      settings: {},
      audit: [],
    );

    final plan = helper.buildPlan(current: current, imported: imported);
    final addition = plan.entries.singleWhere(
      (entry) => entry.key == 'item:new-cloud-item',
    );

    expect(plan.conflictCount, 0);
    expect(addition.status, VaultMergeEntryStatus.importedOnly);
    expect(addition.needsResolution, isFalse);

    final merged = helper.merge(
      current: current,
      imported: imported,
      selections: const <String, VaultMergeSource>{},
    );
    expect(
      merged.items.map((entry) => entry['id']),
      contains('new-cloud-item'),
    );
  });

  test('merge applies selected imported and current entries', () {
    const current = VaultPayload(
      schemaVersion: 1,
      items: [
        {'id': 'shared', 'title': 'Current Email', 'type': 'Login'},
        {'id': 'current-only', 'title': 'Bank', 'type': 'Login'},
      ],
      notes: [],
      tags: ['local'],
      settings: {'customTypeDefinitions': []},
      audit: [],
    );
    const imported = VaultPayload(
      schemaVersion: 1,
      items: [
        {'id': 'shared', 'title': 'Imported Email', 'type': 'Login'},
        {'id': 'imported-only', 'title': 'Wi-Fi', 'type': 'Password'},
      ],
      notes: [],
      tags: ['remote'],
      settings: {},
      audit: [],
    );

    final merged = helper.merge(
      current: current,
      imported: imported,
      selections: const <String, VaultMergeSource>{
        'item:shared': VaultMergeSource.imported,
        'item:current-only': VaultMergeSource.current,
        'item:imported-only': VaultMergeSource.imported,
      },
    );

    expect(
      merged.items.map((entry) => entry['title']),
      contains('Imported Email'),
    );
    expect(merged.items.map((entry) => entry['title']), contains('Bank'));
    expect(merged.items.map((entry) => entry['title']), contains('Wi-Fi'));
    expect(merged.tags, ['local', 'remote']);
    expect(merged.settings, current.settings);
  });
}
