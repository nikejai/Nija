// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'secret_share_portability_base.dart';
import 'secret_share_model.dart';

class SecretSharePortabilityAdapterImpl
    implements SecretSharePortabilityAdapter {
  @override
  Future<bool> shareEncryptedFile({
    required String suggestedName,
    required String content,
  }) async {
    try {
      final bytes = utf8.encode(content);
      final blob = html.Blob(<dynamic>[bytes], 'application/x-nija-secret');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = suggestedName
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

  @override
  Future<bool> exportEncryptedFile({
    required String suggestedName,
    required String content,
  }) async {
    return shareEncryptedFile(suggestedName: suggestedName, content: content);
  }

  @override
  Future<ImportedSecretFile?> importEncryptedFile() async {
    final input = html.FileUploadInputElement()..accept = '.nijas';
    final completer = Completer<ImportedSecretFile?>();

    input.onChange.first.then((_) {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) {
        completer.complete(null);
        return;
      }
      final reader = html.FileReader();
      reader.readAsText(file);
      reader.onLoad.first.then((_) {
        final content = reader.result?.toString();
        if (content == null || content.isEmpty) {
          completer.complete(null);
          return;
        }
        completer.complete(
          ImportedSecretFile(label: file.name, content: content),
        );
      });
      reader.onError.first.then((_) => completer.complete(null));
    });

    input.click();
    return completer.future;
  }
}
