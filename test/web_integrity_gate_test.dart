import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release gate passes compat-js signed fixture', () async {
    final buildDir = await _fixtureBuildDir(includeMainJs: true);
    final harden = await _hardenCompat(buildDir);
    expect(harden.exitCode, 0, reason: harden.stderr.toString());

    final result = await _gate('compat-js', buildDir);

    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test('release gate rejects compat-js changed artifact hash', () async {
    final buildDir = await _fixtureBuildDir(includeMainJs: true);
    final harden = await _hardenCompat(buildDir);
    expect(harden.exitCode, 0, reason: harden.stderr.toString());
    File('${buildDir.path}/main.dart.js').writeAsStringSync('changed');

    final result = await _gate('compat-js', buildDir);

    expect(result.exitCode, isNot(0));
  });

  test('release gate rejects compat-js missing manifest', () async {
    final buildDir = await _fixtureBuildDir(includeMainJs: true);
    final harden = await _hardenCompat(buildDir);
    expect(harden.exitCode, 0, reason: harden.stderr.toString());
    File('${buildDir.path}/nija_integrity_manifest.json').deleteSync();

    final result = await _gate('compat-js', buildDir);

    expect(result.exitCode, isNot(0));
  });

  test('release gate rejects compat-js missing public key marker', () async {
    final buildDir = await _fixtureBuildDir(includeMainJs: true);
    final harden = await _hardenCompat(buildDir, includePublicKeyMarker: false);
    expect(harden.exitCode, 0, reason: harden.stderr.toString());

    final result = await _gate('compat-js', buildDir);

    expect(result.exitCode, isNot(0));
  });

  test('release gate rejects compat-js missing build id marker', () async {
    final buildDir = await _fixtureBuildDir(includeMainJs: true);
    final harden = await _hardenCompat(buildDir, includeBuildIdMarker: false);
    expect(harden.exitCode, 0, reason: harden.stderr.toString());

    final result = await _gate('compat-js', buildDir);

    expect(result.exitCode, isNot(0));
  });

  test('compat-js hardening normalizes static host file permissions', () async {
    final buildDir = await _fixtureBuildDir(includeMainJs: true);
    await _chmod('600', '${buildDir.path}/main.dart.js');

    final harden = await _hardenCompat(buildDir);

    expect(harden.exitCode, 0, reason: harden.stderr.toString());
    expect(await _worldReadable('${buildDir.path}/main.dart.js'), isTrue);
    expect(await _worldReadable('${buildDir.path}/main.dart.wasm'), isTrue);
  });

  test('release gate rejects unreadable static host files', () async {
    final buildDir = await _fixtureBuildDir(includeMainJs: true);
    final harden = await _hardenCompat(buildDir);
    expect(harden.exitCode, 0, reason: harden.stderr.toString());
    await _chmod('600', '${buildDir.path}/main.dart.js');

    final result = await _gate('compat-js', buildDir);

    expect(result.exitCode, isNot(0));
  });

  test('release gate passes wasm-only hardened fixture', () async {
    final buildDir = await _fixtureBuildDir(includeMainJs: true);
    final harden = await Process.run('./scripts/harden_web_release.sh', [
      buildDir.path,
    ]);
    expect(harden.exitCode, 0, reason: harden.stderr.toString());

    final result = await _gate('wasm-only', buildDir);

    expect(result.exitCode, 0, reason: result.stderr.toString());
  });
}

Future<ProcessResult> _hardenCompat(
  Directory buildDir, {
  bool includePublicKeyMarker = true,
  bool includeBuildIdMarker = true,
}) async {
  final keyDir = await Directory.systemTemp.createTemp('nija_web_gate_key_');
  final keyResult = await Process.run('dart', [
    'run',
    'tool/web_integrity.dart',
    'create-key',
    '--output-dir',
    keyDir.path,
  ]);
  expect(keyResult.exitCode, 0, reason: keyResult.stderr.toString());
  final privateKey = File(
    '${keyDir.path}/private_seed.b64',
  ).readAsStringSync().trim();
  final publicKey = File(
    '${keyDir.path}/public_key.b64',
  ).readAsStringSync().trim();
  const buildId = 'nija-web-gate-test-build';
  if (includePublicKeyMarker) {
    File(
      '${buildDir.path}/main.dart.js',
    ).writeAsStringSync('\n$publicKey\n', mode: FileMode.append);
  }
  if (includeBuildIdMarker) {
    File(
      '${buildDir.path}/main.dart.mjs',
    ).writeAsStringSync('\n$buildId\n', mode: FileMode.append);
  }
  return Process.run(
    './scripts/harden_web_release.sh',
    ['--compat-js', buildDir.path],
    environment: {
      'NIJA_WEB_INTEGRITY_PRIVATE_KEY_B64': privateKey,
      'NIJA_WEB_INTEGRITY_BUILD_ID': buildId,
    },
  );
}

Future<ProcessResult> _gate(String flavor, Directory buildDir) {
  return Process.run('./scripts/release_hardening_gate.sh', [
    '--skip-flutter-checks',
    '--web-flavor=$flavor',
    '--web-build-dir=${buildDir.path}',
  ]);
}

Future<Directory> _fixtureBuildDir({required bool includeMainJs}) async {
  final dir = await Directory.systemTemp.createTemp('nija_web_gate_fixture_');
  Directory('${dir.path}/canvaskit').createSync(recursive: true);
  Directory('${dir.path}/assets/branding').createSync(recursive: true);
  final files = <String, String>{
    'flutter_bootstrap.js': '''
_flutter.buildConfig = {"builds":[{"compileTarget":"dart2js","mainJsPath":"main.dart.js"},{"compileTarget":"dart2wasm","mainWasmPath":"main.dart.wasm"}]};
_flutter.loader.load({
  serviceWorkerSettings: {serviceWorkerVersion: "1"}
});
''',
    'main.dart.mjs': 'mjs',
    'main.dart.wasm': 'wasm',
    'flutter_service_worker.js': 'service worker',
    'pwa_install.js': 'pwa',
    'webauthn_quick_unlock.js': 'webauthn',
    'nija_browser_bridge.js': 'bridge',
    'canvaskit/skwasm.js': 'skwasm js',
    'canvaskit/skwasm.wasm': 'skwasm wasm',
    'assets/branding/nija_mark.png': 'png',
    if (includeMainJs) 'main.dart.js': 'js',
  };
  for (final entry in files.entries) {
    File('${dir.path}/${entry.key}')
      ..createSync(recursive: true)
      ..writeAsStringSync(entry.value);
  }
  return dir;
}

Future<bool> _worldReadable(String path) async {
  final result = await Process.run('test', ['-r', path]);
  if (result.exitCode != 0) return false;
  final stat = await Process.run('stat', ['-f', '%Lp', path]);
  final mode = int.tryParse(stat.stdout.toString().trim());
  return mode != null && (mode & 4) == 4;
}

Future<void> _chmod(String mode, String path) async {
  final result = await Process.run('chmod', [mode, path]);
  expect(result.exitCode, 0, reason: result.stderr.toString());
}
