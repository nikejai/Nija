// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'web_page_lifecycle_stub.dart';

WebPageLifecycle createWebPageLifecycle() => _WebPageLifecycleWeb();

class _WebPageLifecycleWeb extends WebPageLifecycle {
  StreamSubscription<html.Event>? _subscription;
  void Function()? _onHidden;

  @override
  void listen(void Function() onHidden) {
    _onHidden = onHidden;
    _subscription ??= html.document.onVisibilityChange.listen((_) {
      if (html.document.hidden == true) {
        _onHidden?.call();
      }
    });
  }

  @override
  void cancel() {
    _subscription?.cancel();
    _subscription = null;
    _onHidden = null;
  }
}
