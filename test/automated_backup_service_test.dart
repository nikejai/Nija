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
  });
}
