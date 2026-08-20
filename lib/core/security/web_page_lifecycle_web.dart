import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'web_page_lifecycle_stub.dart';

WebPageLifecycle createWebPageLifecycle() => _WebPageLifecycleWeb();

class _WebPageLifecycleWeb extends WebPageLifecycle {
  web.EventListener? _listener;
  void Function()? _onHidden;

  @override
  void listen(void Function() onHidden) {
    _onHidden = onHidden;
    if (_listener != null) return;
    _listener = ((web.Event event) {
      if (web.document.hidden) {
        _onHidden?.call();
      }
    }).toJS;
    web.document.addEventListener('visibilitychange', _listener);
  }

  @override
  void cancel() {
    final listener = _listener;
    if (listener != null) {
      web.document.removeEventListener('visibilitychange', listener);
    }
    _listener = null;
    _onHidden = null;
  }
}
