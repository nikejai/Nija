import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/local_vault_snapshot.dart';

class AutomatedBackupService {
  AutomatedBackupService({
    Directory? snapshotsBaseDirectory,
  }) : _customBaseDirectory = snapshotsBaseDirectory;

  final Directory? _customBaseDirectory;

  static const int maxRollingSnapshots = 2;

  bool get _isTestEnvironment =>
      (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) ||
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  Future<Directory> _resolveSnapshotsDirectory(String vaultId) async {
    final sanitizedVaultId = vaultId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    Directory root;
    final customDir = _customBaseDirectory;
    if (customDir != null) {
      root = customDir;
    } else if (kIsWeb) {
      throw UnsupportedError('Local file snapshots are not supported on Web.');
    } else if (_isTestEnvironment) {
      root = Directory.systemTemp;
    } else {
      try {
        root = await getApplicationSupportDirectory();
      } catch (_) {
        root = Directory.systemTemp;
      }
    }
    final dir = Directory('${root.path}/nija_snapshots/$sanitizedVaultId');
    if (_isTestEnvironment) {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Calculates duration from [from] until the next scheduled time [hour]:[minute].
  static Duration durationUntilNextScheduledTime(
    int hour,
    int minute, [
    DateTime? from,
  ]) {
    final current = from ?? DateTime.now();
    var scheduled = DateTime(
      current.year,
      current.month,
      current.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(current) || scheduled.isAtSameMomentAs(current)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final diff = scheduled.difference(current);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Calculates duration from [from] until the next local midnight (00:00:00).
  static Duration durationUntilNextMidnight([DateTime? from]) {
    return durationUntilNextScheduledTime(0, 0, from);
  }

  /// Checks if a backup is due given the [lastBackup] timestamp, scheduled [hour]:[minute], and [now].
  static bool isBackupDueAtTime(
    DateTime? lastBackup,
    int hour,
    int minute, [
    DateTime? now,
  ]) {
    if (lastBackup == null) return true;
    final current = now ?? DateTime.now();
    final todayScheduled = DateTime(
      current.year,
      current.month,
      current.day,
      hour,
      minute,
    );

    if (current.isAfter(todayScheduled) || current.isAtSameMomentAs(todayScheduled)) {
      return lastBackup.isBefore(todayScheduled);
    } else {
      final prevScheduled = todayScheduled.subtract(const Duration(days: 1));
      return lastBackup.isBefore(prevScheduled);
    }
  }

  /// Checks if a backup is due given the [lastBackup] timestamp and [now] for midnight schedule.
  static bool isBackupDue(DateTime? lastBackup, [DateTime? now]) {
    return isBackupDueAtTime(lastBackup, 0, 0, now);
  }

  /// Creates a local rolling snapshot by streaming directly to [filePath] via [writeToFile].
  Future<LocalVaultSnapshot?> createLocalSnapshotFromFileWriter({
    required String vaultId,
    required Future<bool> Function(String destinationPath) writeToFile,
    DateTime? timestamp,
  }) async {
    if (kIsWeb && _customBaseDirectory == null) return null;
    try {
      final now = timestamp ?? DateTime.now();
      final dir = await _resolveSnapshotsDirectory(vaultId);
      final epoch = now.millisecondsSinceEpoch;
      final fileName = 'snapshot_$epoch.nija';
      final file = File('${dir.path}/$fileName');

      final ok = await writeToFile(file.path);
      if (!ok || !await file.exists()) {
        return null;
      }

      await _pruneOldSnapshots(dir);

      return LocalVaultSnapshot(
        id: fileName,
        vaultId: vaultId,
        filePath: file.path,
        timestamp: now,
        sizeBytes: await file.length(),
      );
    } catch (e) {
      debugPrint('AutomatedBackupService error creating streamed snapshot: $e');
      return null;
    }
  }

  /// Creates a local rolling snapshot of [rawVaultContent].
  /// Keeps exactly [maxRollingSnapshots] (2) latest snapshots, pruning older ones.
  Future<LocalVaultSnapshot?> createLocalSnapshot({
    required String vaultId,
    required String rawVaultContent,
    DateTime? timestamp,
  }) async {
    if (kIsWeb && _customBaseDirectory == null) return null;
    try {
      final now = timestamp ?? DateTime.now();
      final dir = await _resolveSnapshotsDirectory(vaultId);
      final epoch = now.millisecondsSinceEpoch;
      final fileName = 'snapshot_$epoch.nija';
      final file = File('${dir.path}/$fileName');

      if (_isTestEnvironment) {
        file.writeAsStringSync(rawVaultContent, flush: true);
        await _pruneOldSnapshots(dir);
        return LocalVaultSnapshot(
          id: fileName,
          vaultId: vaultId,
          filePath: file.path,
          timestamp: now,
          sizeBytes: file.lengthSync(),
        );
      }

      await file.writeAsString(rawVaultContent, flush: true);

      // Prune snapshots older than the 2 most recent
      await _pruneOldSnapshots(dir);

      return LocalVaultSnapshot(
        id: fileName,
        vaultId: vaultId,
        filePath: file.path,
        timestamp: now,
        sizeBytes: await file.length(),
      );
    } catch (e) {
      debugPrint('AutomatedBackupService error creating snapshot: $e');
      return null;
    }
  }

  Future<void> _pruneOldSnapshots(Directory dir) async {
    try {
      final isTest = _isTestEnvironment;
      final entities = isTest ? dir.listSync() : await dir.list().toList();
      final snapshotFiles = <File>[];

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.nija')) {
          snapshotFiles.add(entity);
        }
      }

      // Sort newest first
      final modifiedByPath = <String, DateTime>{};
      for (final file in snapshotFiles) {
        modifiedByPath[file.path] = isTest
            ? file.lastModifiedSync()
            : await file.lastModified();
      }
      snapshotFiles.sort((a, b) {
        final aEpoch = int.tryParse(
              RegExp(r'snapshot_(\d+)\.nija$').firstMatch(a.path)?.group(1) ?? '',
            ) ??
            0;
        final bEpoch = int.tryParse(
              RegExp(r'snapshot_(\d+)\.nija$').firstMatch(b.path)?.group(1) ?? '',
            ) ??
            0;
        if (aEpoch != bEpoch) {
          return bEpoch.compareTo(aEpoch);
        }
        return (modifiedByPath[b.path] ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(
              modifiedByPath[a.path] ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
      });

      // Keep only up to maxRollingSnapshots (2)
      if (snapshotFiles.length > maxRollingSnapshots) {
        for (var i = maxRollingSnapshots; i < snapshotFiles.length; i++) {
          try {
            if (isTest) {
              snapshotFiles[i].deleteSync();
            } else {
              await snapshotFiles[i].delete();
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Lists all local snapshots for the given [vaultId], newest first.
  Future<List<LocalVaultSnapshot>> listLocalSnapshots(String vaultId) async {
    if (kIsWeb && _customBaseDirectory == null) {
      return const <LocalVaultSnapshot>[];
    }
    try {
      final isTest = _isTestEnvironment;
      final dir = await _resolveSnapshotsDirectory(vaultId);
      final entities = isTest ? dir.listSync() : await dir.list().toList();
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
                : (isTest
                    ? entity.lastModifiedSync()
                    : await entity.lastModified());
          } else {
            timestamp = isTest
                ? entity.lastModifiedSync()
                : await entity.lastModified();
          }

          snapshots.add(
            LocalVaultSnapshot(
              id: fileName,
              vaultId: vaultId,
              filePath: entity.path,
              timestamp: timestamp,
              sizeBytes: isTest ? entity.lengthSync() : await entity.length(),
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

  /// Starts a daily recurring schedule at [hour]:[minute], executing [onBackup].
  Timer scheduleDailyBackup({
    required int hour,
    required int minute,
    required Future<void> Function() onBackup,
    DateTime? now,
  }) {
    final handle = _ScheduledBackupTimerHandle();
    void scheduleNext([DateTime? from]) {
      if (handle.isCancelled) return;
      final duration = durationUntilNextScheduledTime(hour, minute, from);
      handle.attach(
        Timer(duration, () async {
          if (handle.isCancelled) return;
          try {
            await onBackup();
          } catch (e) {
            debugPrint('Daily automated backup execution error: $e');
          }
          scheduleNext();
        }),
      );
    }

    scheduleNext(now);
    return handle;
  }

  /// Starts a midnight recurring schedule, executing [onMidnightBackup] at each midnight.
  Timer scheduleMidnightBackup({
    required Future<void> Function() onMidnightBackup,
    DateTime? now,
  }) {
    return scheduleDailyBackup(
      hour: 0,
      minute: 0,
      onBackup: onMidnightBackup,
      now: now,
    );
  }
}

class _ScheduledBackupTimerHandle implements Timer {
  Timer? _active;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void attach(Timer timer) {
    if (_cancelled) {
      timer.cancel();
      return;
    }
    _active?.cancel();
    _active = timer;
  }

  @override
  void cancel() {
    _cancelled = true;
    _active?.cancel();
    _active = null;
  }

  @override
  bool get isActive => !_cancelled && (_active?.isActive ?? false);

  @override
  int get tick => _active?.tick ?? 0;
}
