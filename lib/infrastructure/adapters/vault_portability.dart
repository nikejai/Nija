export 'vault_portability_stub.dart'
    if (dart.library.js_interop) 'vault_portability_web.dart'
    if (dart.library.io) 'vault_portability_io.dart';
