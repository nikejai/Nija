import 'package:flutter_test/flutter_test.dart';
import 'package:nija/features/vault/application/vault_entry_activity.dart';

void main() {
  test('prefers updatedAt over legacy updated Now label', () {
    final label = vaultEntryRelativeTimeLabel({
      'updated': 'Now',
      'updatedAt': '2026-08-01T10:00:00.000Z',
    });

    expect(label.endsWith('ago'), isTrue);
    expect(label, isNot('Now'));
  });

  test('uses lastAccessedAt when present', () {
    final label = vaultEntryRelativeTimeLabel({
      'updated': 'Now',
      'updatedAt': '2026-08-01T10:00:00.000Z',
      'lastAccessedAt': '2026-08-10T10:00:00.000Z',
    });

    expect(label.endsWith('ago'), isTrue);
  });

  test('falls back to Unknown for legacy Now-only entries', () {
    expect(
      vaultEntryRelativeTimeLabel({'updated': 'Now'}),
      'Unknown',
    );
  });

  test('parses legacy relative updated labels for activity ordering', () {
    final activityAt = vaultEntryActivityAt({'updated': '9d ago'});
    expect(activityAt, isNotNull);
    expect(
      vaultEntryRelativeTimeLabel({'updated': '9d ago'}),
      '9d ago',
    );
  });

  test('vaultEntryAgeDays ignores legacy Now placeholder', () {
    expect(vaultEntryAgeDays({'updated': 'Now'}), isNull);
    expect(
      vaultEntryAgeDays({
        'updated': 'Now',
        'updatedAt': '2026-08-01T10:00:00.000Z',
      }),
      isNotNull,
    );
  });
}
