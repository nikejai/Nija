import 'package:flutter_test/flutter_test.dart';
import 'package:nija/domain/validators/vault_validators.dart';

void main() {
  test('master password validator enforces basic strength', () {
    expect(VaultValidators.isStrongEnoughMasterPassword('weak'), isFalse);
    expect(VaultValidators.isStrongEnoughMasterPassword('noDigitsHere'), isFalse);
    expect(VaultValidators.isStrongEnoughMasterPassword('ValidPass123'), isTrue);
  });

  test('sensitive label validator', () {
    expect(VaultValidators.isValidSensitiveFieldLabel(''), isFalse);
    expect(VaultValidators.isValidSensitiveFieldLabel(' Password '), isTrue);
  });
}
