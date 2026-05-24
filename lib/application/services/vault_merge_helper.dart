import 'dart:convert';

import '../../domain/models/vault_payload.dart';

enum VaultMergeSource { current, imported }

enum VaultMergeEntryStatus { identical, currentOnly, importedOnly, conflict }

class VaultMergeEntry {
  const VaultMergeEntry({
    required this.key,
    required this.kind,
    required this.title,
    required this.type,
    required this.status,
    this.current,
    this.imported,
  });

  final String key;
  final String kind;
  final String title;
  final String type;
  final VaultMergeEntryStatus status;
  final Map<String, dynamic>? current;
  final Map<String, dynamic>? imported;

  bool get needsResolution =>
      status == VaultMergeEntryStatus.conflict ||
      status == VaultMergeEntryStatus.currentOnly;
}

class VaultMergePlan {
  const VaultMergePlan({
    required this.entries,
    required this.conflictCount,
    required this.identicalCount,
  });

  final List<VaultMergeEntry> entries;
  final int conflictCount;
  final int identicalCount;

  int get totalCount => entries.length;
}

class VaultMergeHelper {
  const VaultMergeHelper();

  VaultMergePlan buildPlan({
    required VaultPayload current,
    required VaultPayload imported,
  }) {
    final entries =
        <VaultMergeEntry>[
          ..._compareEntries(
            kind: 'item',
            currentEntries: current.items,
            importedEntries: imported.items,
          ),
          ..._compareEntries(
            kind: 'note',
            currentEntries: current.notes,
            importedEntries: imported.notes,
          ),
        ]..sort((a, b) {
          final statusCompare = _statusRank(
            a.status,
          ).compareTo(_statusRank(b.status));
          if (statusCompare != 0) return statusCompare;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });

    return VaultMergePlan(
      entries: entries,
      conflictCount: entries.where((entry) => entry.needsResolution).length,
      identicalCount: entries
          .where((entry) => entry.status == VaultMergeEntryStatus.identical)
          .length,
    );
  }

  VaultPayload merge({
    required VaultPayload current,
    required VaultPayload imported,
    required Map<String, VaultMergeSource> selections,
  }) {
    final plan = buildPlan(current: current, imported: imported);
    final mergedItems = <Map<String, dynamic>>[];
    final mergedNotes = <Map<String, dynamic>>[];

    for (final entry in plan.entries) {
      final selected = selections[entry.key] ?? _defaultSource(entry);
      final chosen = selected == VaultMergeSource.imported
          ? entry.imported
          : entry.current;
      if (chosen == null) continue;
      final copy = Map<String, dynamic>.from(chosen);
      if (entry.kind == 'note') {
        mergedNotes.add(copy);
      } else {
        mergedItems.add(copy);
      }
    }

    return VaultPayload(
      schemaVersion: current.schemaVersion >= imported.schemaVersion
          ? current.schemaVersion
          : imported.schemaVersion,
      items: mergedItems,
      notes: mergedNotes,
      tags: <String>{...current.tags, ...imported.tags}.toList()..sort(),
      settings: Map<String, dynamic>.from(current.settings),
      audit: const <Map<String, dynamic>>[],
    );
  }

  List<VaultMergeEntry> _compareEntries({
    required String kind,
    required List<Map<String, dynamic>> currentEntries,
    required List<Map<String, dynamic>> importedEntries,
  }) {
    final currentById = _byStableId(currentEntries);
    final importedById = _byStableId(importedEntries);
    final keys = <String>{...currentById.keys, ...importedById.keys}.toList()
      ..sort();

    return keys.map((id) {
      final current = currentById[id];
      final imported = importedById[id];
      final sample = imported ?? current ?? const <String, dynamic>{};
      final status = current == null
          ? VaultMergeEntryStatus.importedOnly
          : imported == null
          ? VaultMergeEntryStatus.currentOnly
          : _canonical(current) == _canonical(imported)
          ? VaultMergeEntryStatus.identical
          : VaultMergeEntryStatus.conflict;
      return VaultMergeEntry(
        key: '$kind:$id',
        kind: kind,
        title: sample['title']?.toString().trim().isNotEmpty == true
            ? sample['title'].toString().trim()
            : kind == 'note'
            ? 'Untitled note'
            : 'Untitled item',
        type: kind == 'note'
            ? 'Note'
            : (sample['type']?.toString().trim().isNotEmpty == true
                  ? sample['type'].toString().trim()
                  : 'Item'),
        status: status,
        current: current,
        imported: imported,
      );
    }).toList();
  }

  Map<String, Map<String, dynamic>> _byStableId(
    List<Map<String, dynamic>> entries,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final id = entry['id']?.toString().trim();
      byId[id == null || id.isEmpty ? 'index-$index' : id] =
          Map<String, dynamic>.from(entry);
    }
    return byId;
  }

  VaultMergeSource _defaultSource(VaultMergeEntry entry) {
    return switch (entry.status) {
      VaultMergeEntryStatus.importedOnly => VaultMergeSource.imported,
      _ => VaultMergeSource.current,
    };
  }

  int _statusRank(VaultMergeEntryStatus status) {
    return switch (status) {
      VaultMergeEntryStatus.conflict => 0,
      VaultMergeEntryStatus.importedOnly => 1,
      VaultMergeEntryStatus.currentOnly => 2,
      VaultMergeEntryStatus.identical => 3,
    };
  }

  String _canonical(Map<String, dynamic> entry) {
    return jsonEncode(_sortJson(_withoutAccessMetadata(entry)));
  }

  Map<String, dynamic> _withoutAccessMetadata(Map<String, dynamic> entry) {
    final copy = Map<String, dynamic>.from(entry);
    copy.remove('lastAccessedAt');
    return copy;
  }

  dynamic _sortJson(dynamic value) {
    if (value is Map) {
      final sorted = <String, dynamic>{};
      for (final key
          in value.keys.map((key) => key.toString()).toList()..sort()) {
        sorted[key] = _sortJson(value[key]);
      }
      return sorted;
    }
    if (value is List) {
      return value.map(_sortJson).toList();
    }
    return value;
  }
}
