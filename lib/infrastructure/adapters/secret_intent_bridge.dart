import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'secret_share_model.dart';

class SecretIntentBridge {
  static const _channel = MethodChannel('nija/secret_intent');

  Future<ImportedSecretFile?> consumePendingSecret() async {
    if (kIsWeb) return null;
    try {
      final raw = await _channel.invokeMethod<dynamic>('consumePendingSecret');
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      final label = map['label']?.toString() ?? '';
      final content = map['content']?.toString() ?? '';
      if (label.isEmpty || content.isEmpty) return null;
      return ImportedSecretFile(label: label, content: content);
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<SharedTextIntent?> consumePendingSharedText() async {
    if (kIsWeb) return null;
    try {
      final raw = await _channel.invokeMethod<dynamic>(
        'consumePendingSharedText',
      );
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      final text = map['text']?.toString() ?? '';
      if (text.trim().isEmpty) return null;
      final sourceApplication = map['sourceApplication']?.toString() ?? '';
      final sourcePackage = map['sourcePackage']?.toString() ?? '';
      return SharedTextIntent(
        text: text,
        sourceApplication: sourceApplication.trim().isEmpty
            ? 'Unknown app'
            : sourceApplication.trim(),
        sourcePackage: sourcePackage.trim().isEmpty
            ? null
            : sourcePackage.trim(),
      );
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }
}

class SharedTextIntent {
  const SharedTextIntent({
    required this.text,
    required this.sourceApplication,
    this.sourcePackage,
  });

  final String text;
  final String sourceApplication;
  final String? sourcePackage;
}
