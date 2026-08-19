// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

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
    final input = html.FileUploadInputElement()..accept = '.nijas';
    final completer = Completer<ImportedSecretFile?>();

    void complete(ImportedSecretFile? file) {
      if (!completer.isCompleted) {
        completer.complete(file);
      }
    }

    input.onChange.first.then((_) {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) {
        complete(null);
        return;
      }
      final reader = html.FileReader();
      reader.readAsText(file);
      reader.onLoad.first.then((_) {
        final content = reader.result?.toString();
        if (content == null || content.isEmpty) {
          complete(null);
          return;
        }
        complete(ImportedSecretFile(label: file.name, content: content));
      });
      reader.onError.first.then((_) => complete(null));
    });

    input.addEventListener('cancel', (_) => complete(null));
    input.click();
    return completer.future;
  }

  Future<bool> _tryWebShareFile({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final navigator = html.window.navigator;
    if (!js_util.hasProperty(navigator, 'share')) return false;
    if (js_util.hasProperty(navigator, 'canShare')) {
      final canShare = js_util.callMethod<bool?>(navigator, 'canShare', [
        js_util.jsify(<String, Object>{
          'files': <Object>[_webFile(bytes, fileName, mimeType)],
        }),
      ]);
      if (canShare != true) return false;
    }
    try {
      final sharePromise = js_util.callMethod(navigator, 'share', [
        js_util.jsify(<String, Object>{
          'files': <Object>[_webFile(bytes, fileName, mimeType)],
          'title': fileName,
        }),
      ]);
      await js_util.promiseToFuture<void>(sharePromise);
      return true;
    } catch (_) {
      return false;
    }
  }

  html.File _webFile(List<int> bytes, String fileName, String mimeType) {
    final blob = html.Blob(<dynamic>[bytes], mimeType);
    return html.File(
      <Object>[blob],
      fileName,
      <String, String>{'type': mimeType},
    );
  }

  bool _downloadBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) {
    try {
      final blob = html.Blob(<dynamic>[bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = fileName
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      return true;
    } catch (_) {
      return false;
    }
  }
}
