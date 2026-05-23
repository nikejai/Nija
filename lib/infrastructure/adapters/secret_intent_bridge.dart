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
}
