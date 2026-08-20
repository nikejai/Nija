export 'web_quick_unlock_vault_base.dart';
export 'web_quick_unlock_vault_stub.dart'
    if (dart.library.js_interop) 'web_quick_unlock_vault_web.dart';

import 'web_quick_unlock_vault_stub.dart'
    if (dart.library.js_interop) 'web_quick_unlock_vault_web.dart';

import 'web_quick_unlock_vault_base.dart';

WebQuickUnlockVault webQuickUnlockVault = createWebQuickUnlockVault();
