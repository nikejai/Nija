export 'pwa_install_service_base.dart';
export 'pwa_install_service_stub.dart'
    if (dart.library.html) 'pwa_install_service_web.dart';

import 'pwa_install_service_stub.dart'
    if (dart.library.html) 'pwa_install_service_web.dart';

import 'pwa_install_service_base.dart';

PwaInstallService pwaInstallService = createPwaInstallService();
