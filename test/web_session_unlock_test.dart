import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/security/web_session_unlock.dart';

void main() {
  test('stub session unlock is inert on non-web platforms', () {
    webSessionUnlock.rememberPassword(vaultId: 'vault-a', password: 'secret');
    expect(webSessionUnlock.hasPassword(vaultId: 'vault-a'), isFalse);
    expect(webSessionUnlock.readPassword(vaultId: 'vault-a'), isNull);
  });
}
