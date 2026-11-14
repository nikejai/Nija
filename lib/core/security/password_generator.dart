import 'dart:math';

import '../config/recovery_phrase_dictionary.dart';

enum PasswordStrength { weak, fair, strong, veryStrong }

class PasswordGeneratorOptions {
  const PasswordGeneratorOptions({
    this.length = 20,
    this.includeUppercase = true,
    this.includeLowercase = true,
    this.includeDigits = true,
    this.includeSymbols = true,
  });

  final int length;
  final bool includeUppercase;
  final bool includeLowercase;
  final bool includeDigits;
  final bool includeSymbols;
}

class PassphraseOptions {
  const PassphraseOptions({
    this.wordCount = 4,
    this.separator = '-',
    this.capitalize = false,
    this.includeNumber = true,
  });

  final int wordCount;
  final String separator;
  final bool capitalize;
  final bool includeNumber;
}

class PasswordGenerator {
  PasswordGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  static const String uppercaseChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; // Exclude ambiguous I, O
  static const String lowercaseChars = 'abcdefghijkmnopqrstuvwxyz'; // Exclude ambiguous l
  static const String digitChars = '23456789'; // Exclude ambiguous 0, 1
  static const String symbolChars = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

  String generatePassword([
    PasswordGeneratorOptions options = const PasswordGeneratorOptions(),
  ]) {
    final length = options.length.clamp(8, 128);
    final charPool = <String>[];
    final requiredChars = <String>[];

    if (options.includeUppercase) {
      charPool.add(uppercaseChars);
      requiredChars.add(_randomChar(uppercaseChars));
    }
    if (options.includeLowercase) {
      charPool.add(lowercaseChars);
      requiredChars.add(_randomChar(lowercaseChars));
    }
    if (options.includeDigits) {
      charPool.add(digitChars);
      requiredChars.add(_randomChar(digitChars));
    }
    if (options.includeSymbols) {
      charPool.add(symbolChars);
      requiredChars.add(_randomChar(symbolChars));
    }

    if (charPool.isEmpty) {
      // Fallback if user unchecks all
      charPool.add(lowercaseChars);
      requiredChars.add(_randomChar(lowercaseChars));
    }

    final allChars = charPool.join();
    final result = <String>[...requiredChars];

    while (result.length < length) {
      result.add(_randomChar(allChars));
    }

    // Fisher-Yates shuffle
    for (var i = result.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }

    return result.join();
  }

  String generatePassphrase([
    PassphraseOptions options = const PassphraseOptions(),
  ]) {
    final words = RecoveryPhraseDictionary.words;
    final count = options.wordCount.clamp(3, 12);
    final selected = <String>[];

    for (var i = 0; i < count; i++) {
      var word = words[_random.nextInt(words.length)];
      if (options.capitalize && word.isNotEmpty) {
        word = '${word[0].toUpperCase()}${word.substring(1)}';
      }
      selected.add(word);
    }

    var result = selected.join(options.separator);
    if (options.includeNumber) {
      final num = _random.nextInt(90) + 10; // 2-digit number 10-99
      result = '$result$num';
    }
    return result;
  }

  String _randomChar(String chars) {
    return chars[_random.nextInt(chars.length)];
  }

  static double calculateEntropyBits(String password) {
    if (password.isEmpty) return 0.0;
    var poolSize = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) poolSize += 26;
    if (RegExp(r'[A-Z]').hasMatch(password)) poolSize += 26;
    if (RegExp(r'[0-9]').hasMatch(password)) poolSize += 10;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) poolSize += 32;

    if (poolSize == 0) return 0.0;
    final entropyPerChar = log(poolSize) / ln2;
    return password.length * entropyPerChar;
  }

  static PasswordStrength evaluateStrength(String password) {
    final bits = calculateEntropyBits(password);
    if (bits < 40) return PasswordStrength.weak;
    if (bits < 60) return PasswordStrength.fair;
    if (bits < 80) return PasswordStrength.strong;
    return PasswordStrength.veryStrong;
  }

  static String strengthLabel(PasswordStrength strength) {
    return switch (strength) {
      PasswordStrength.weak => 'Weak',
      PasswordStrength.fair => 'Fair',
      PasswordStrength.strong => 'Strong',
      PasswordStrength.veryStrong => 'Very Strong',
    };
  }
}
