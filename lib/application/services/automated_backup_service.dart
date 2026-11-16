import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/local_vault_snapshot.dart';

class AutomatedBackupService {
  AutomatedBackupService({
    Directory? snapshotsBaseDirectory,
  }) : _customBaseDirectory = snapshotsBaseDirectory;

  final Directory? _customBaseDirectory;

  static const int maxRollingSnapshots = 2;

  Future<Directory> _resolveSnapshotsDirectory(String vaultId) async {
    final sanitizedVaultId = vaultId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    Directory root;
    final customDir = _customBaseDirectory;
    if (customDir != null) {
      root = customDir;
    } else if (kIsWeb) {
      root = Directory('/tmp');
    } else if (Platform.environment.containsKey('FLUTTER_TEST')) {
      root = Directory.systemTemp;
    } else {
      try {
        root = await getApplicationSupportDirectory();
      } catch (_) {
        root = Directory.systemTemp;
      }
    }
    final dir = Directory('${root.path}/nija_snapshots/$sanitizedVaultId');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Calculates duration from [from] until the next local midnight (00:00:00).
  static Duration durationUntilNextMidnight([DateTime? from]) {
    final current = from ?? DateTime.now();
    final nextMidnight = DateTime(current.year, current.month, current.day + 1);
    final diff = nextMidnight.difference(current);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Checks if a backup is due given the [lastBackup] timestamp and [now].
  static bool isBackupDue(DateTime? lastBackup, [DateTime? now]) {
    if (lastBackup == null) return true;
    final current = now ?? DateTime.now();
    final todayMidnight = DateTime(current.year, current.month, current.day);
    return lastBackup.isBefore(todayMidnight);
  }

  /// Creates a local rolling snapshot of [rawVaultContent].
  /// Keeps exactly [maxRollingSnapshots] (2) latest snapshots, pruning older ones.
  Future<LocalVaultSnapshot?> createLocalSnapshot({
    required String vaultId,
    required String rawVaultContent,
    DateTime? timestamp,
  }) async {
    try {
      final now = timestamp ?? DateTime.now();
      final dir = await _resolveSnapshotsDirectory(vaultId);
      final epoch = now.millisecondsSinceEpoch;
      final fileName = 'snapshot_$epoch.nija';
      final file = File('${dir.path}/$fileName');

      await file.writeAsString(rawVaultContent, flush: true);

      // Prune snapshots older than the 2 most recent
      await _pruneOldSnapshots(dir);

      return LocalVaultSnapshot(
        id: fileName,
        vaultId: vaultId,
        filePath: file.path,
        timestamp: now,
        sizeBytes: file.lengthSync(),
      );
    } catch (e) {
      debugPrint('AutomatedBackupService error creating snapshot: $e');
      return null;
    }
  }

  Future<void> _pruneOldSnapshots(Directory dir) async {
    try {
      final entities = dir.listSync();
      final snapshotFiles = <File>[];

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.nija')) {
          snapshotFiles.add(entity);
        }
      }

      // Sort newest first
      snapshotFiles.sort((a, b) {
        final aModified = a.lastModifiedSync();
        final bModified = b.lastModifiedSync();
        return bModified.compareTo(aModified);
      });

      // Keep only up to maxRollingSnapshots (2)
      if (snapshotFiles.length > maxRollingSnapshots) {
        for (var i = maxRollingSnapshots; i < snapshotFiles.length; i++) {
          try {
            snapshotFiles[i].deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Lists all local snapshots for the given [vaultId], newest first.
  Future<List<LocalVaultSnapshot>> listLocalSnapshots(String vaultId) async {
    try {
      final dir = await _resolveSnapshotsDirectory(vaultId);
      final entities = dir.listSync();
      final snapshots = <LocalVaultSnapshot>[];

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.nija')) {
          final fileName = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : entity.path;
          DateTime timestamp;
          final match = RegExp(r'snapshot_(\d+)\.nija$').firstMatch(fileName);
          if (match != null) {
            final epoch = int.tryParse(match.group(1)!);
            timestamp = epoch != null
                ? DateTime.fromMillisecondsSinceEpoch(epoch)
                : entity.lastModifiedSync();
          } else {
            timestamp = entity.lastModifiedSync();
          }

          snapshots.add(
            LocalVaultSnapshot(
              id: fileName,
              vaultId: vaultId,
              filePath: entity.path,
              timestamp: timestamp,
              sizeBytes: entity.lengthSync(),
            ),
          );
        }
      }

      snapshots.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return snapshots;
    } catch (_) {
      return const <LocalVaultSnapshot>[];
    }
  }

  /// Reads raw vault content from a snapshot file.
  Future<String?> readSnapshotContent(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }

  /// Starts a midnight recurring schedule, executing [onMidnightBackup] at each midnight.
  Timer scheduleMidnightBackup({
    required Future<void> Function() onMidnightBackup,
    DateTime? now,
  }) {
    final duration = durationUntilNextMidnight(now);
    return Timer(duration, () async {
      try {
        await onMidnightBackup();
      } catch (e) {
        debugPrint('Midnight automated backup execution error: $e');
      }
      // Re-schedule for next midnight
      scheduleMidnightBackup(onMidnightBackup: onMidnightBackup);
    });
  }
}
