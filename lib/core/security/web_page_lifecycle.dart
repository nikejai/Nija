export 'web_page_lifecycle_stub.dart';

import 'web_page_lifecycle_stub.dart';
import 'web_page_lifecycle_web.dart'
    if (dart.library.io) 'web_page_lifecycle_stub.dart' as web_impl;

final WebPageLifecycle webPageLifecycle = web_impl.createWebPageLifecycle();

void registerWebPageHiddenListener(void Function()? onHidden) {
  webPageLifecycle.cancel();
  if (onHidden == null) return;
  webPageLifecycle.listen(onHidden);
}
