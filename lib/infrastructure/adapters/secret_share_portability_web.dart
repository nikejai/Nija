import 'dart:convert';
import 'dart:typed_data';

import '../../../core/platform/nija_browser_bridge.dart';
import 'secret_share_portability_base.dart';
import 'secret_share_model.dart';

class SecretSharePortabilityAdapterImpl
    implements SecretSharePortabilityAdapter {
  @override
  Future<bool> shareEncryptedFile({
    required String suggestedName,
    required String content,
  }) async {
    final bytes = utf8.encode(content);
    if (await _tryWebShareFile(
      bytes: bytes,
      fileName: suggestedName,
      mimeType: 'application/x-nija-secret',
    )) {
      return true;
    }
    return _downloadBytes(
      bytes: bytes,
      fileName: suggestedName,
      mimeType: 'application/x-nija-secret',
    );
  }

  @override
  Future<bool> exportEncryptedFile({
    required String suggestedName,
    required String content,
  }) async {
    return shareEncryptedFile(suggestedName: suggestedName, content: content);
  }

  @override
  Future<bool> exportPlainFile({
    required String suggestedName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final fileName = suggestedName.trim().isEmpty ? 'document' : suggestedName;
    if (await _tryWebShareFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    )) {
      return true;
    }
    return _downloadBytes(bytes: bytes, fileName: fileName, mimeType: mimeType);
  }

  @override
  Future<ImportedSecretFile?> importEncryptedFile() async {
    final file = await nijaPickTextFile('.nijas');
    if (file == null) return null;
    return ImportedSecretFile(label: file.name, content: file.content);
  }

  Future<bool> _tryWebShareFile({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    return nijaShareBase64File(
      fileName: fileName,
      base64: base64Encode(bytes),
      mimeType: mimeType,
    );
  }

  bool _downloadBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) {
    try {
      return nijaDownloadBase64File(
        fileName: fileName,
        base64: base64Encode(bytes),
        mimeType: mimeType,
      );
    } catch (_) {
      return false;
    }
  }
}
