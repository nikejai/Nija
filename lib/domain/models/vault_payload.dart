import '../../application/services/vault_migrator.dart';
import 'vault_folder.dart';

class VaultPayload {
  const VaultPayload({
    required this.schemaVersion,
    required this.items,
    required this.notes,
    required this.tags,
    required this.settings,
    required this.audit,
  });

  final int schemaVersion;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> notes;
  final List<String> tags;
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> audit;

  List<VaultFolder> get folders {
    final raw = settings['folders'];
    if (raw is! List) return const <VaultFolder>[];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((entry) => VaultFolder.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  VaultPayload copyWithFolders(List<VaultFolder> newFolders) {
    final updatedSettings = Map<String, dynamic>.from(settings);
    updatedSettings['folders'] = newFolders.map((f) => f.toJson()).toList();
    return VaultPayload(
      schemaVersion: schemaVersion,
      items: items,
      notes: notes,
      tags: tags,
      settings: updatedSettings,
      audit: audit,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'items': items,
    'notes': notes,
    'tags': tags,
    'settings': settings,
    'audit': audit,
  };

  factory VaultPayload.fromJson(Map<String, dynamic> json) {
    return VaultPayload(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      notes: (json['notes'] as List<dynamic>? ?? const <dynamic>[])
          .map((note) => Map<String, dynamic>.from(note as Map))
          .toList(),
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((tag) => tag.toString())
          .toList(),
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
      audit: (json['audit'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList(),
    );
  }

  static VaultPayload empty() {
    return const VaultPayload(
      schemaVersion: VaultMigrator.currentPayloadSchemaVersion,
      items: <Map<String, dynamic>>[],
      notes: <Map<String, dynamic>>[],
      tags: <String>[],
      settings: <String, dynamic>{},
      audit: <Map<String, dynamic>>[],
    );
  }
}
