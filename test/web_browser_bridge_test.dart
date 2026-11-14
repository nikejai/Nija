import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web file picker input stays Safari-compatible', () {
    final bridge = File('web/nija_browser_bridge.js').readAsStringSync();

    expect(bridge, contains("input.type = 'file'"));
    expect(bridge, contains("input.style.position = 'fixed'"));
    expect(bridge, contains("input.style.opacity = '0'"));
    expect(bridge, isNot(contains("input.style.display = 'none'")));
  });
}
