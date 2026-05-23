import 'dart:async';

import 'package:flutter/services.dart';

class SecureClipboard {
  SecureClipboard({this.clearAfter = const Duration(seconds: 20)});

  final Duration clearAfter;
  Timer? _timer;

  Future<void> copySensitive(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    _timer?.cancel();
    _timer = Timer(clearAfter, () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}
