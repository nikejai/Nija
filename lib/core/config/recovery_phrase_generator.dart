import 'dart:math';

import 'recovery_phrase_dictionary.dart';

class RecoveryPhraseGenerator {
  RecoveryPhraseGenerator._();

  static const defaultWordCount = 12;

  static List<String> generate({int wordCount = defaultWordCount, Random? random}) {
    final source = List<String>.from(RecoveryPhraseDictionary.words);
    if (source.length < wordCount) {
      throw StateError('Recovery phrase dictionary must have at least $wordCount words.');
    }
    source.shuffle(random ?? Random.secure());
    return source.take(wordCount).toList();
  }

  static String numberedMultiline(List<String> words) {
    return List<String>.generate(
      words.length,
      (index) => '${index + 1}. ${words[index]}',
    ).join('\n');
  }
}
