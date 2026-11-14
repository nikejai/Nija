import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('harden script help exposes compat-js mode', () async {
    final result = await Process.run('./scripts/harden_web_release.sh', [
      '--help',
    ]);

    expect(result.exitCode, 0);
    expect(result.stdout.toString(), contains('--compat-js'));
  });

  test('wasm-only hardening removes dart js fallback', () async {
    final buildDir = await _fixtureBuildDir(includeMainJs: true);

    final result = await Process.run('./scripts/harden_web_release.sh', [
      buildDir.path,
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File('${buildDir.path}/main.dart.js').existsSync(), isFalse);
    expect(
      File('${buildDir.path}/flutter_bootstrap.js').readAsStringSync(),
      isNot(contains('main.dart.js')),
    );
  });

  test('compat-js hardening preserves fallback and signs artifact', () async {
    final buildDir = await _fixtureBuildDir(includeMainJs: true);

    final result = await Process.run(
      './scripts/harden_web_release.sh',
      ['--compat-js', buildDir.path],
      environment: {'NIJA_WEB_INTEGRITY_ALLOW_EPHEMERAL': 'true'},
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File('${buildDir.path}/main.dart.js').existsSync(), isTrue);
    expect(
      File('${buildDir.path}/nija_integrity_manifest.json').existsSync(),
      isTrue,
    );
    expect(
      File('${buildDir.path}/nija_integrity_manifest.sig').existsSync(),
      isTrue,
    );
  });

  test('hardening copies no-cache rules for stable web entry files', () async {
    final buildDir = await _fixtureBuildDir(includeMainJs: true);

    final result = await Process.run(
      './scripts/harden_web_release.sh',
      ['--compat-js', buildDir.path],
      environment: {'NIJA_WEB_INTEGRITY_ALLOW_EPHEMERAL': 'true'},
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final htaccess = File('${buildDir.path}/.htaccess').readAsStringSync();
    expect(htaccess, contains('main\\.dart\\.js'));
    expect(htaccess, contains('main\\.dart\\.mjs'));
    expect(htaccess, contains('main\\.dart\\.wasm'));
    expect(htaccess, contains('nija_integrity_manifest\\.json'));
    expect(htaccess, contains('no-cache, no-store, must-revalidate'));
  });

  test('hardening rejects source maps', () async {
    final buildDir = await _fixtureBuildDir(includeMainJs: true);
    File('${buildDir.path}/main.dart.js.map').writeAsStringSync('map');

    final result = await Process.run('./scripts/harden_web_release.sh', [
      buildDir.path,
    ]);

    expect(result.exitCode, isNot(0));
    expect(result.stdout.toString(), contains('Source maps'));
  });
}

Future<Directory> _fixtureBuildDir({required bool includeMainJs}) async {
  final dir = await Directory.systemTemp.createTemp('nija_web_fixture_');
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
