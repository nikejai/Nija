import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/vault_reference.dart';

class VaultReferenceCache {
  static const _key = 'nija_vault_references_v1';

  Future<List<VaultReference>> readAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return <VaultReference>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <VaultReference>[];
      return decoded
          .whereType<Map>()
          .map(
            (entry) =>
                VaultReference.fromJson(Map<String, dynamic>.from(entry)),
          )
          .where((entry) => entry.id.isNotEmpty && entry.label.isNotEmpty)
          .toList(growable: true)
        ..sort((a, b) {
          final openCmp = b.lastOpenedAtEpochMs.compareTo(
            a.lastOpenedAtEpochMs,
          );
          if (openCmp != 0) return openCmp;
          return b.addedAtEpochMs.compareTo(a.addedAtEpochMs);
        });
    } on MissingPluginException {
      return <VaultReference>[];
    } catch (_) {
      return <VaultReference>[];
    }
  }

  Future<void> upsert(VaultReference reference) async {
    final all = await readAll();
    final existingIndex = all.indexWhere((entry) => entry.id == reference.id);
    if (existingIndex >= 0) {
      all[existingIndex] = reference;
    } else {
      all.insert(0, reference);
    }
    await _save(all);
  }

  Future<void> removeById(String id) async {
    final all = await readAll();
    all.removeWhere((entry) => entry.id == id);
    await _save(all);
  }

  Future<void> _save(List<VaultReference> references) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(
        references.map((entry) => entry.toJson()).toList(),
      );
      await prefs.setString(_key, raw);
    } on MissingPluginException {
      // Ignore in test environments without plugin channel wiring.
    } catch (_) {
      // Ignore in test environments without plugin channel wiring.
    }
  }
}
