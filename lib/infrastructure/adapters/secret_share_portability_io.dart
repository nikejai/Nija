import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'secret_share_portability_base.dart';
import 'secret_share_model.dart';

class SecretSharePortabilityAdapterImpl
    implements SecretSharePortabilityAdapter {
  @override
  Future<bool> shareEncryptedFile({
    required String suggestedName,
    required String content,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = suggestedName.trim().isEmpty
        ? 'secret.nijas'
        : suggestedName.trim();
    final filePath = _joinPath(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsString(content, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Encrypted Nija secret file.',
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  @override
  Future<bool> exportEncryptedFile({
    required String suggestedName,
    required String content,
  }) async {
    if (Platform.isAndroid) {
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Export encrypted secret',
      );
      if (directoryPath == null || directoryPath.isEmpty) return false;
      final outputPath = _joinPath(directoryPath, suggestedName);
      await File(outputPath).writeAsString(content, flush: true);
      return true;
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export encrypted secret',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: const <String>['nijas'],
    );
    if (outputPath == null || outputPath.isEmpty) return false;
    await File(outputPath).writeAsString(content, flush: true);
    return true;
  }

  @override
  Future<ImportedSecretFile?> importEncryptedFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['nijas'],
      withData: false,
    );
    final file = result?.files.isNotEmpty == true ? result!.files.first : null;
    final path = file?.path;
    if (path == null || path.isEmpty) return null;
    final content = await File(path).readAsString();
    return ImportedSecretFile(label: file!.name, content: content);
  }

  String _joinPath(String directory, String fileName) {
    final separator = Platform.pathSeparator;
    if (directory.endsWith(separator)) {
      return '$directory$fileName';
    }
    return '$directory$separator$fileName';
  }
}
