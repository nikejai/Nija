import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/web_integrity/web_integrity_startup.dart';
import 'package:nija/generated/web_integrity_groups.g.dart';

void main() {
  test('wrapper code generation is deterministic for fixed seed', () async {
    final first = await _generate('release-123');
    final second = await _generate('release-123');

    expect(first, second);
  });

  test('generated wrapper stays small and avoids failure keywords', () async {
    final source = await _generate('release-456');

    expect(source.length, lessThan(30000));
    expect(nijaWebIntegrityContainsForbiddenFailureLanguage(source), isFalse);
    expect(source.toLowerCase(), isNot(contains('secret')));
    expect(source.toLowerCase(), isNot(contains('private key')));
  });

  test('generated startup wrapper delegates pass and fail results', () async {
    expect(
      await nijaWebIntegrityStartupGate(
        probe: () async => NijaWebIntegrityStartupResult.passed,
      ),
      NijaWebIntegrityStartupResult.passed,
    );
    expect(
      await nijaWebIntegrityStartupGate(
        probe: () async => NijaWebIntegrityStartupResult.unavailable,
      ),
      NijaWebIntegrityStartupResult.unavailable,
    );
  });

  test('generated feature wrappers delegate to expected groups', () async {
    final requestedGroups = <String>[];
    Future<NijaWebIntegrityStartupResult> probe(String groupName) async {
      requestedGroups.add(groupName);
      return groupName == 'transfer'
          ? NijaWebIntegrityStartupResult.unavailable
          : NijaWebIntegrityStartupResult.passed;
    }

    expect(
      await nijaWebIntegrityUnlockGate(probe: probe),
      NijaWebIntegrityStartupResult.passed,
    );
    expect(
      await nijaWebIntegrityVaultReferenceGate(probe: probe),
      NijaWebIntegrityStartupResult.passed,
    );
    expect(
      await nijaWebIntegrityCapacityGate(probe: probe),
      NijaWebIntegrityStartupResult.passed,
    );
    expect(
      await nijaWebIntegrityTransferGate(probe: probe),
      NijaWebIntegrityStartupResult.unavailable,
    );
    expect(
      await nijaWebIntegritySettingsGate(probe: probe),
      NijaWebIntegrityStartupResult.passed,
    );
    expect(requestedGroups, <String>[
      'unlock',
      'vault_reference',
      'capacity',
      'transfer',
      'settings',
    ]);
  });
}

Future<String> _generate(String seed) async {
  final dir = await Directory.systemTemp.createTemp('nija_codegen_');
  final output = File('${dir.path}/web_integrity_groups.g.dart');
  final result = await Process.run('dart', [
    'tool/web_integrity.dart',
    'generate-wrapper',
    '--seed',
    seed,
    '--output',
    output.path,
  ]);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return output.readAsStringSync();
}
