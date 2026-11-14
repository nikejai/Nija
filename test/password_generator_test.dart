import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/security/password_generator.dart';

void main() {
  group('PasswordGenerator', () {
    late PasswordGenerator generator;

    setUp(() {
      generator = PasswordGenerator();
    });

    test('generates password with requested default length', () {
      final password = generator.generatePassword();
      expect(password.length, 20);
    });

    test('generates password with custom length', () {
      final password = generator.generatePassword(
        const PasswordGeneratorOptions(length: 32),
      );
      expect(password.length, 32);
    });

    test('clamps length within valid limits', () {
      final shortPassword = generator.generatePassword(
        const PasswordGeneratorOptions(length: 4),
      );
      expect(shortPassword.length, 8);

      final longPassword = generator.generatePassword(
        const PasswordGeneratorOptions(length: 200),
      );
      expect(longPassword.length, 128);
    });

    test('contains required character types when requested', () {
      for (var i = 0; i < 20; i++) {
        final password = generator.generatePassword(
          const PasswordGeneratorOptions(
            length: 16,
            includeUppercase: true,
            includeLowercase: true,
            includeDigits: true,
            includeSymbols: true,
          ),
        );
        expect(RegExp(r'[A-Z]').hasMatch(password), isTrue);
        expect(RegExp(r'[a-z]').hasMatch(password), isTrue);
        expect(RegExp(r'[0-9]').hasMatch(password), isTrue);
        expect(RegExp(r'[^a-zA-Z0-9]').hasMatch(password), isTrue);
      }
    });

    test('generates memorable passphrase with word count and separator', () {
      final passphrase = generator.generatePassphrase(
        const PassphraseOptions(
          wordCount: 4,
          separator: '-',
          includeNumber: false,
        ),
      );
      final parts = passphrase.split('-');
      expect(parts.length, 4);
      for (final part in parts) {
        expect(part.isNotEmpty, isTrue);
      }
    });

    test('generates passphrase with capitalization and suffix number', () {
      final passphrase = generator.generatePassphrase(
        const PassphraseOptions(
          wordCount: 3,
          separator: '.',
          capitalize: true,
          includeNumber: true,
        ),
      );
      final parts = passphrase.split('.');
      expect(parts.length, 3);
      expect(parts[0][0], parts[0][0].toUpperCase());
      expect(RegExp(r'\d{2}$').hasMatch(parts.last), isTrue);
    });

    test(
      'entropy calculation reflects password length and character variety',
      () {
        expect(PasswordGenerator.calculateEntropyBits(''), 0.0);
        final simpleEntropy = PasswordGenerator.calculateEntropyBits('aaaa');
        final complexEntropy = PasswordGenerator.calculateEntropyBits(
          'aA1!bB2@',
        );
        expect(complexEntropy, greaterThan(simpleEntropy));
      },
    );

    test('evaluates strength levels correctly', () {
      expect(
        PasswordGenerator.evaluateStrength('12345'),
        PasswordStrength.weak,
      );
      expect(
        PasswordGenerator.evaluateStrength('CorrectHorseBatteryStaple123!'),
        PasswordStrength.veryStrong,
      );
    });
  });
}
