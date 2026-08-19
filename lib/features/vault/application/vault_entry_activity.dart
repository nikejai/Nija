DateTime? parseVaultEntryTimestamp(Object? raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}

DateTime? legacyRelativeUpdatedAt(String? raw) {
  final normalized = raw?.trim().toLowerCase() ?? '';
  if (normalized.isEmpty || normalized == 'now') return null;
  final digits = RegExp(r'\d+').firstMatch(normalized)?.group(0);
  final value = digits == null ? 0 : (int.tryParse(digits) ?? 0);
  if (normalized.contains('h')) {
    return DateTime.now().subtract(Duration(hours: value));
  }
  if (normalized.contains('d')) {
    return DateTime.now().subtract(Duration(days: value));
  }
  if (normalized.contains('w')) {
    return DateTime.now().subtract(Duration(days: value * 7));
  }
  if (normalized.contains('m')) {
    return DateTime.now().subtract(Duration(days: value * 30));
  }
  return null;
}

DateTime? vaultEntryActivityAt(Map<String, dynamic> entry) {
  return parseVaultEntryTimestamp(entry['lastAccessedAt']) ??
      parseVaultEntryTimestamp(entry['updatedAt']) ??
      parseVaultEntryTimestamp(entry['documentUploadedAt']) ??
      parseVaultEntryTimestamp(entry['createdAt']) ??
      parseVaultEntryTimestamp(entry['created_at']) ??
      legacyRelativeUpdatedAt(entry['updated']?.toString());
}

String formatRelativeTimeSince(DateTime timestamp) {
  final elapsed = DateTime.now().toUtc().difference(timestamp.toUtc());
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays == 1) return '1d ago';
  return '${elapsed.inDays}d ago';
}

String vaultEntryRelativeTimeLabel(
  Map<String, dynamic> entry, {
  String fallback = 'Unknown',
}) {
  final activityAt = vaultEntryActivityAt(entry);
  if (activityAt != null) {
    return formatRelativeTimeSince(activityAt);
  }
  final legacy = entry['updated']?.toString().trim() ?? '';
  if (legacy.isNotEmpty && legacy.toLowerCase() != 'now') {
    return legacy;
  }
  return fallback;
}

int? vaultEntryAgeDays(Map<String, dynamic> entry) {
  final activityAt = vaultEntryActivityAt(entry);
  if (activityAt != null) {
    final today = DateTime.now();
    final activityDay = DateTime(
      activityAt.year,
      activityAt.month,
      activityAt.day,
    );
    final currentDay = DateTime(today.year, today.month, today.day);
    return currentDay.difference(activityDay).inDays;
  }
  return null;
}
