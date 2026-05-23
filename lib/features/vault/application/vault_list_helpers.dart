import '../../../core/config/vault_item_templates.dart';

class VaultListHelpers {
  VaultListHelpers._();

  static List<String> allTypeFilterOptions({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> customTypeDefinitions,
  }) {
    final options = <String>{'Notes'};

    for (final item in items) {
      final type = item['type']?.toString().trim();
      if (type != null && type.isNotEmpty) {
        options.add(type);
      }
    }

    for (final template in VaultItemTemplates.builtIn) {
      final type = template.type.trim();
      if (type.isNotEmpty) {
        options.add(type);
      }
    }

    for (final definition in customTypeDefinitions) {
      final type = definition['name']?.toString().trim();
      if (type != null && type.isNotEmpty) {
        options.add(type);
      }
    }

    final sorted = options.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }
}
