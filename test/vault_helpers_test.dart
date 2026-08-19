import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/config/vault_item_templates.dart';
import 'package:nija/features/vault/application/vault_home_demo_data.dart';
import 'package:nija/features/vault/application/vault_list_helpers.dart';
import 'package:nija/features/vault/application/vault_text_serializers.dart';
import 'package:nija/features/vault/presentation/widgets/vault_entry_list.dart';

void main() {
  test(
    'built-in vault item templates are centralized and include core types',
    () {
      final types = VaultItemTemplates.builtIn.map((template) => template.type);

      expect(types, containsAll(<String>['Login', 'Card', 'Identity']));
      expect(
        VaultItemTemplates.builtIn
            .firstWhere((template) => template.type == 'Login')
            .fields
            .map((field) => field.label),
        contains('Password'),
      );
    },
  );

  test(
    'all type filter options merge notes, built-ins, items, and custom types',
    () {
      final options = VaultListHelpers.allTypeFilterOptions(
        items: const <Map<String, dynamic>>[
          {'type': 'Login'},
          {'type': 'Membership'},
        ],
        customTypeDefinitions: const <Map<String, dynamic>>[
          {'name': 'Crypto Wallet'},
        ],
      );

      expect(options, containsAll(<String>['Notes', 'Login', 'Card']));
      expect(options, containsAll(<String>['Membership', 'Crypto Wallet']));
      expect(
        options,
        orderedEquals(
          options.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
        ),
      );
    },
  );

  test('item plain text skips empty fields', () {
    final text = VaultTextSerializers.itemPlainText(const <String, dynamic>{
      'title': 'Email',
      'type': 'Login',
      'fields': [
        {'label': 'Username', 'value': 'me@example.com'},
        {'label': 'Notes', 'value': '   '},
      ],
    });

    expect(text, contains('Email'));
    expect(text, contains('Type: Login'));
    expect(text, contains('Username: me@example.com'));
    expect(text, isNot(contains('Notes:')));
  });

  test('document list adapter shows extension time and size metadata', () {
    const adapter = VaultDocumentListEntryAdapter();
    final row = <String, dynamic>{
      'kind': 'item',
      'updatedLabel': '3d ago',
      'entry': <String, dynamic>{
        'type': 'Documents',
        'title': 'Health Insurance Card',
        'documentExtension': 'pdf',
        'documentSizeBytes': 1258291,
      },
    };

    final entry = adapter.adapt(row);

    expect(adapter.canAdapt(row), isTrue);
    expect(entry.title, 'Health Insurance Card');
    expect(entry.type, 'PDF');
    expect(entry.updated, '3d ago · 1.2 MB');
  });

  test('homepage demo data covers dashboard item cases', () {
    final itemTypes = VaultHomeDemoData.items
        .map((item) => item['type']?.toString())
        .toSet();

    expect(
      itemTypes,
      containsAll(<String>['Login', 'Identity', 'Card', 'Documents']),
    );
    expect(VaultHomeDemoData.notes, hasLength(1));
    expect(VaultHomeDemoData.folders, hasLength(4));

    const itemAdapter = VaultItemListEntryAdapter();
    for (final item in VaultHomeDemoData.items) {
      final row = <String, dynamic>{'kind': 'item', 'entry': item};
      expect(itemAdapter.canAdapt(row), isTrue);
      final entry = itemAdapter.adapt(row);
      expect(entry.title, isNotEmpty);
      expect(entry.updated, isNotEmpty);
    }

    const noteAdapter = VaultNoteListEntryAdapter();
    final noteRow = <String, dynamic>{
      'kind': 'note',
      'entry': VaultHomeDemoData.notes.single,
    };
    expect(noteAdapter.canAdapt(noteRow), isTrue);
    expect(noteAdapter.adapt(noteRow).title, 'Recovery Phrase');
  });

  test('note plain text preserves rich delta markers', () {
    final text = VaultTextSerializers.notePlainText(const <String, dynamic>{
      'title': 'Plan',
      'preview': 'fallback',
      'delta': [
        {'insert': 'Buy milk'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {
          'insert': 'Important',
          'attributes': {'bold': true},
        },
        {'insert': ' task'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ],
    });

    expect(text, contains('Plan'));
    expect(text, contains('1. Buy milk'));
    expect(text, contains('• **Important** task'));
  });
}
