import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nija/application/services/automated_backup_service.dart';

void main() {
  late Directory tempDir;
  late AutomatedBackupService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nija_backup_test_');
    service = AutomatedBackupService(snapshotsBaseDirectory: tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('AutomatedBackupService Unit Tests', () {
    test('durationUntilNextMidnight calculates exact time until 00:00:00', () {
      final from = DateTime(2026, 11, 15, 23, 50, 0); // 10 minutes to midnight
      final diff = AutomatedBackupService.durationUntilNextMidnight(from);
      expect(diff, const Duration(minutes: 10));

      final atMidnight = DateTime(2026, 11, 16, 0, 0, 0);
      final diff2 = AutomatedBackupService.durationUntilNextMidnight(atMidnight);
      expect(diff2, const Duration(hours: 24));
    });

    test('durationUntilNextScheduledTime calculates exact time until custom hour and minute', () {
      final from = DateTime(2026, 11, 15, 14, 0, 0); // 2:00 PM
      // Scheduled for 2:30 PM today (30 min)
      final diff1 = AutomatedBackupService.durationUntilNextScheduledTime(14, 30, from);
      expect(diff1, const Duration(minutes: 30));

      // Scheduled for 1:00 PM (passed today -> tomorrow)
      final diff2 = AutomatedBackupService.durationUntilNextScheduledTime(13, 0, from);
      expect(diff2, const Duration(hours: 23));
    });

    test('isBackupDueAtTime detects when scheduled time has passed', () {
      // Scheduled for 2:00 AM (02:00)
      final todayMorning = DateTime(2026, 11, 15, 8, 0, 0); // 8:00 AM
      final backedUpBefore2Am = DateTime(2026, 11, 15, 1, 30, 0);
      final backedUpAfter2Am = DateTime(2026, 11, 15, 3, 0, 0);

      // Backed up at 1:30 AM, current time 8:00 AM, scheduled 2:00 AM -> Due!
      expect(AutomatedBackupService.isBackupDueAtTime(backedUpBefore2Am, 2, 0, todayMorning), isTrue);

      // Backed up at 3:00 AM, current time 8:00 AM, scheduled 2:00 AM -> Not due
      expect(AutomatedBackupService.isBackupDueAtTime(backedUpAfter2Am, 2, 0, todayMorning), isFalse);
    });

    test('isBackupDue detects when midnight has passed', () {
      // Never backed up
      expect(AutomatedBackupService.isBackupDue(null), isTrue);

      // Backed up yesterday
      final yesterday = DateTime(2026, 11, 14, 22, 0, 0);
      final today = DateTime(2026, 11, 15, 10, 0, 0);
      expect(AutomatedBackupService.isBackupDue(yesterday, today), isTrue);

      // Backed up today after midnight
      final todayEarlier = DateTime(2026, 11, 15, 1, 0, 0);
      expect(AutomatedBackupService.isBackupDue(todayEarlier, today), isFalse);
    });

    test('creates local snapshots and prunes to exactly 2 rolling snapshots', () async {
      const vaultId = 'vault-test-123';
      const content1 = '{"vaultId":"1","revision":1}';
      const content2 = '{"vaultId":"1","revision":2}';
      const content3 = '{"vaultId":"1","revision":3}';

      final t1 = DateTime(2026, 11, 13, 0, 0, 0);
      final t2 = DateTime(2026, 11, 14, 0, 0, 0);
      final t3 = DateTime(2026, 11, 15, 0, 0, 0);

      // Snapshot 1
      final snap1 = await service.createLocalSnapshot(
        vaultId: vaultId,
        rawVaultContent: content1,
        timestamp: t1,
      );
      expect(snap1, isNotNull);

      var list = await service.listLocalSnapshots(vaultId);
      expect(list.length, 1);

      // Snapshot 2
      final snap2 = await service.createLocalSnapshot(
        vaultId: vaultId,
        rawVaultContent: content2,
        timestamp: t2,
      );
      expect(snap2, isNotNull);

      list = await service.listLocalSnapshots(vaultId);
      expect(list.length, 2);

      // Snapshot 3 - must prune oldest (t1) and keep t3, t2
      final snap3 = await service.createLocalSnapshot(
        vaultId: vaultId,
        rawVaultContent: content3,
        timestamp: t3,
      );
      expect(snap3, isNotNull);

      list = await service.listLocalSnapshots(vaultId);
      expect(list.length, 2);
      expect(list[0].timestamp, t3);
      expect(list[1].timestamp, t2);

      // Reading content from snapshot 3
      final readContent = await service.readSnapshotContent(list[0].filePath);
      expect(readContent, content3);
    });

    test('createLocalSnapshotFromFileWriter streams and prunes to 2 snapshots', () async {
      const vaultId = 'vault-stream-123';
      for (var i = 1; i <= 3; i++) {
        final snap = await service.createLocalSnapshotFromFileWriter(
          vaultId: vaultId,
          writeToFile: (destPath) async {
            await File(destPath).writeAsString('streamed-$i', flush: true);
            return true;
          },
          timestamp: DateTime(2026, 11, 12 + i),
        );
        expect(snap, isNotNull);
      }

      final list = await service.listLocalSnapshots(vaultId);
      expect(list.length, 2);
      expect(await service.readSnapshotContent(list[0].filePath), 'streamed-3');
      expect(await service.readSnapshotContent(list[1].filePath), 'streamed-2');
    });

    test('scheduleDailyBackup handle cancels active scheduled timer cleanly', () {
      final handle = service.scheduleDailyBackup(
        hour: 3,
        minute: 15,
        onBackup: () async {},
        now: DateTime(2026, 11, 19, 1, 0, 0),
      );
      expect(handle.isActive, isTrue);
      handle.cancel();
      expect(handle.isActive, isFalse);
    });
  });
}
