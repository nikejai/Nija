import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'vault_portability_base.dart';
import 'vault_portability_model.dart';

class VaultPortabilityAdapterImpl implements VaultPortabilityAdapter {
  static const MethodChannel _cloudBackupChannel = MethodChannel(
    'nija/cloud_backup',
  );

  @override
  Future<ImportedVaultFile?> importVaultFromLocal() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['nija', 'json', 'txt'],
      withData: false,
    );
    final file = result?.files.isNotEmpty == true ? result!.files.first : null;
    final path = file?.path;
    if (path == null || path.isEmpty) return null;
    final content = await File(path).readAsString();
    return ImportedVaultFile(
      storageId: path,
      label: file!.name,
      content: content,
    );
  }

  @override
  Future<String?> exportVaultToLocal({
    required String suggestedName,
    required String content,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (Platform.isAndroid || Platform.isIOS) {
      return FilePicker.platform.saveFile(
        dialogTitle: 'Export vault file',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: const <String>['nija'],
        bytes: bytes,
      );
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export vault file',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: const <String>['nija'],
    );
    if (outputPath == null || outputPath.isEmpty) return null;
    await File(outputPath).writeAsString(content, flush: true);
    return outputPath;
  }

  String _joinPath(String directory, String fileName) {
    final separator = Platform.pathSeparator;
    if (directory.endsWith(separator)) {
      return '$directory$fileName';
    }
    return '$directory$separator$fileName';
  }

  @override
  Future<bool> backupVaultToCloud({
    required String vaultId,
    required String suggestedName,
    required String content,
  }) async {
    if (Platform.isAndroid) {
      return _backupToGoogleDrive(
        vaultId: vaultId,
        suggestedName: suggestedName,
        content: content,
      );
    }
    if (Platform.isIOS) {
      return _backupToICloud(
        vaultId: vaultId,
        suggestedName: suggestedName,
        content: content,
      );
    }
    return false;
  }

  @override
  Future<CloudVaultBackupFile?> readCloudBackup({
    required String vaultId,
  }) async {
    if (Platform.isAndroid) {
      return _readGoogleDriveBackup(vaultId: vaultId);
    }
    if (Platform.isIOS) {
      try {
        final raw = await _cloudBackupChannel.invokeMethod<String>(
          'readFromICloud',
          {'vaultId': vaultId},
        );
        if (raw == null || raw.isEmpty) return null;
        return CloudVaultBackupFile(
          storageId: 'icloud_$vaultId.nija',
          label: 'iCloud backup',
          content: raw,
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<bool> _backupToGoogleDrive({
    required String vaultId,
    required String suggestedName,
    required String content,
  }) async {
    _GoogleAuthClient? authedClient;
    try {
      final googleSignIn = _googleSignInClient();
      final account = await googleSignIn.signIn();
      if (account == null) return false;
      final authHeaders = await account.authHeaders;
      authedClient = _GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authedClient);
      final bytes = utf8.encode(content);
      final media = drive.Media(Stream<List<int>>.value(bytes), bytes.length);
      final query =
          "appProperties has { key='nijaVaultId' and value='$vaultId' } and trashed=false";
      final list = await driveApi.files.list(
        q: query,
        $fields: 'files(id,name)',
        spaces: 'drive',
        pageSize: 1,
      );

      if (list.files != null && list.files!.isNotEmpty) {
        final existingId = list.files!.first.id;
        if (existingId == null || existingId.isEmpty) return false;
        final meta = drive.File()
          ..name = suggestedName
          ..modifiedTime = DateTime.now().toUtc();
        await driveApi.files.update(meta, existingId, uploadMedia: media);
        return true;
      }
      final meta = drive.File()
        ..name = suggestedName
        ..mimeType = 'application/json'
        ..appProperties = <String, String>{'nijaVaultId': vaultId};
      await driveApi.files.create(meta, uploadMedia: media);
      return true;
    } catch (error) {
      debugPrint('[VaultPortability][GoogleDriveBackup] $error');
      throw StateError('Google Drive backup failed: $error');
    } finally {
      authedClient?.close();
    }
  }

  Future<CloudVaultBackupFile?> _readGoogleDriveBackup({
    required String vaultId,
  }) async {
    _GoogleAuthClient? authedClient;
    try {
      final googleSignIn = _googleSignInClient();
      final account =
          googleSignIn.currentUser ?? await googleSignIn.signInSilently();
      final signedIn = account ?? await googleSignIn.signIn();
      if (signedIn == null) return null;
      final authHeaders = await signedIn.authHeaders;
      authedClient = _GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authedClient);
      final query =
          "appProperties has { key='nijaVaultId' and value='$vaultId' } and trashed=false";
      final list = await driveApi.files.list(
        q: query,
        $fields: 'files(id,name)',
        spaces: 'drive',
        pageSize: 1,
      );
      final file = list.files?.isNotEmpty == true ? list.files!.first : null;
      final id = file?.id;
      if (id == null || id.isEmpty) return null;
      final media = await driveApi.files.get(
        id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (media is! drive.Media) return null;
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }
      return CloudVaultBackupFile(
        storageId: 'gdrive_$id.nija',
        label: file?.name ?? 'Google Drive backup',
        content: utf8.decode(bytes),
      );
    } catch (error) {
      debugPrint('[VaultPortability][GoogleDriveReadBackup] $error');
      return null;
    } finally {
      authedClient?.close();
    }
  }

  @override
  Future<String?> getCloudBackupAccountLabel() async {
    if (Platform.isAndroid) {
      try {
        final googleSignIn = _googleSignInClient();
        final account =
            googleSignIn.currentUser ?? await googleSignIn.signInSilently();
        return account?.email;
      } catch (_) {
        return null;
      }
    }
    if (Platform.isIOS) {
      return 'iCloud (system account)';
    }
    return null;
  }

  @override
  Future<bool> changeCloudBackupAccount() async {
    if (Platform.isAndroid) {
      try {
        final googleSignIn = _googleSignInClient();
        await googleSignIn.signOut();
        final account = await googleSignIn.signIn();
        return account != null;
      } catch (_) {
        return false;
      }
    }
    if (Platform.isIOS) {
      return false;
    }
    return false;
  }

  Future<bool> _backupToICloud({
    required String vaultId,
    required String suggestedName,
    required String content,
  }) async {
    try {
      final ok = await _cloudBackupChannel.invokeMethod<bool>(
        'backupToICloud',
        {
          'vaultId': vaultId,
          'suggestedName': suggestedName,
          'content': content,
        },
      );
      return ok == true;
    } catch (error) {
      debugPrint('[VaultPortability][ICloudBackup] $error');
      return false;
    }
  }

  Future<bool> shareBackupFallback({
    required String suggestedName,
    required String content,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = _joinPath(tempDir.path, suggestedName);
    final file = File(filePath);
    await file.writeAsString(content, flush: true);
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'application/json')],
        ),
      );
      return result.status == ShareResultStatus.success;
    } finally {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Temp file cleanup is best-effort.
      }
    }
  }
}

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

GoogleSignIn _googleSignInClient() {
  return GoogleSignIn(scopes: const <String>[drive.DriveApi.driveFileScope]);
}
