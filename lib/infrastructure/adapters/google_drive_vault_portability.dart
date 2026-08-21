import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../../core/config/google_oauth_config.dart';
import 'vault_portability_model.dart';

const _appDataFolderId = 'appDataFolder';
const _maxBackupCandidatesToScan = 24;
const _driveDownloadTimeout = Duration(seconds: 45);
const _driveListTimeout = Duration(seconds: 60);
const _driveScopes = <String>[
  drive.DriveApi.driveAppdataScope,
  drive.DriveApi.driveFileScope,
];

GoogleSignIn? _googleSignInInstance;
_GoogleAuthClient? _driveAuthClient;

/// Shared [GoogleSignIn] client for Drive backup (web + mobile).
GoogleSignIn googleDriveSignInClient() => _googleSignInClient();

/// OAuth scopes required for cross-platform Drive backups.
List<String> get googleDriveOAuthScopes => _driveScopes;

class GoogleDriveVaultPortability {
  const GoogleDriveVaultPortability();

  Future<bool> ensureCloudBackupAccountSelected({
    bool forceAccountChooser = false,
  }) async {
    if (kIsWeb) {
      return !forceAccountChooser &&
          await _googleSignInClient().canAccessScopes(_driveScopes);
    }
    final account = await requireInteractiveSignIn(
      forceAccountChooser: forceAccountChooser,
    );
    return account != null;
  }

  Future<GoogleSignInAccount?> requireInteractiveSignIn({
    bool forceAccountChooser = false,
  }) async {
    final googleSignIn = _googleSignInClient();
    if (kIsWeb) {
      if (forceAccountChooser) {
        return null;
      }
      if (!await googleSignIn.canAccessScopes(_driveScopes)) {
        return null;
      }
      return googleSignIn.currentUser;
    }

    if (forceAccountChooser) {
      await googleSignIn.signOut();
    }
    if (googleSignIn.currentUser != null) {
      return googleSignIn.currentUser;
    }
    return googleSignIn.signIn();
  }

  Future<bool> backupVaultToCloud({
    required String vaultId,
    required String suggestedName,
    required String content,
    bool forceAccountChooser = false,
  }) async {
    final session = await _openDriveSession(
      forceAccountChooser: forceAccountChooser,
    );
    if (session == null) return false;

    try {
      final driveApi = session.driveApi;
      await _uploadVaultToAppDataFolder(
        driveApi: driveApi,
        vaultId: vaultId,
        suggestedName: suggestedName,
        content: content,
      );
      final legacyId = await _findLegacyDriveFileIdForVault(
        driveApi: driveApi,
        vaultId: vaultId,
      );
      if (legacyId != null) {
        try {
          await driveApi.files.delete(legacyId);
        } catch (error) {
          debugLogCloudError('GoogleDriveDeleteLegacyBackup', error);
        }
      }
      return true;
    } catch (error) {
      debugLogCloudError('GoogleDriveBackup', error);
      throw StateError('Google Drive backup failed.');
    }
  }

  Future<CloudVaultBackupFile?> readCloudBackup({
    required String vaultId,
    bool forceAccountChooser = false,
  }) async {
    final session = await _openDriveSession(
      forceAccountChooser: forceAccountChooser,
    );
    if (session == null) return null;

    try {
      final found = await _findCloudBackupForVault(
        driveApi: session.driveApi,
        vaultId: vaultId,
      );
      if (found == null) return null;
      return hydrateCloudBackupContent(
        found,
        forceAccountChooser: forceAccountChooser,
      );
    } catch (error) {
      debugLogCloudError('GoogleDriveReadBackup', error);
      return null;
    }
  }

  Future<List<CloudVaultBackupFile>> listCloudBackups({
    bool forceAccountChooser = false,
  }) async {
    final session = await _openDriveSession(
      forceAccountChooser: forceAccountChooser,
    );
    if (session == null) {
      throw StateError(
        'Google Drive is not connected. Sign in again and allow Drive access.',
      );
    }

    try {
      return await _listAllCloudBackups(driveApi: session.driveApi).timeout(
        _driveListTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Timed out while searching Google Drive backups.',
          );
        },
      );
    } catch (error) {
      debugLogCloudError('GoogleDriveListBackups', error);
      rethrow;
    }
  }

  Future<CloudVaultBackupFile> hydrateCloudBackupContent(
    CloudVaultBackupFile listing, {
    bool forceAccountChooser = false,
  }) async {
    if (listing.hasContent) return listing;
    if (listing.driveFileId.trim().isEmpty) {
      throw StateError('Cloud backup listing is missing Drive file id.');
    }

    final session = await _openDriveSession(
      forceAccountChooser: forceAccountChooser,
    );
    if (session == null) {
      throw StateError(
        'Google Drive is not connected. Sign in again and allow Drive access.',
      );
    }

    final driveFile = drive.File(
      id: listing.driveFileId,
      name: listing.fileName.isEmpty ? listing.label : listing.fileName,
    );
    final content = await _downloadDriveFileContent(
      session.driveApi,
      driveFile,
    );
    if (content == null || !looksLikeNijaVaultContent(content)) {
      throw StateError('Selected cloud backup could not be downloaded.');
    }

    return CloudVaultBackupFile(
      storageId: listing.storageId,
      label: cloudBackupLabelFromContent(
        fallbackName: listing.fileName.isEmpty
            ? listing.label
            : listing.fileName,
        content: content,
      ),
      content: content,
      fileName: listing.fileName.isEmpty ? listing.label : listing.fileName,
      modifiedAt: listing.modifiedAt,
      revision: vaultRevisionFromNijaVaultContent(content),
      versionId: vaultVersionIdFromNijaVaultContent(content),
      updatedAt: vaultUpdatedAtFromNijaVaultContent(content),
      driveFileId: listing.driveFileId,
      listedVaultId: vaultIdFromNijaVaultContent(content),
    );
  }

  /// Ensures a fresh Drive HTTP client after web sign-in completes.
  Future<bool> ensureDriveSessionReady() async {
    final googleSignIn = _googleSignInClient();
    if (!await googleSignIn.canAccessScopes(_driveScopes)) {
      return false;
    }
    if (googleSignIn.currentUser == null) {
      return false;
    }
    resetDriveAuthClient();
    return true;
  }

  /// Clears cached Drive HTTP auth (call after Google sign-out on web).
  void resetDriveAuthClient() {
    _driveAuthClient?.close();
    _driveAuthClient = null;
  }

  Future<String?> getCloudBackupAccountLabel() async {
    try {
      final googleSignIn = _googleSignInClient();
      if (kIsWeb) {
        // Do not call signInSilently on web — it triggers FedCM One Tap and
        // fails on localhost when OAuth origins are misconfigured.
        if (!await googleSignIn.canAccessScopes(_driveScopes)) {
          return null;
        }
        return googleSignIn.currentUser?.email;
      }
      final account =
          googleSignIn.currentUser ?? await googleSignIn.signInSilently();
      return account?.email;
    } catch (_) {
      return null;
    }
  }

  Future<bool> changeCloudBackupAccount() async {
    return ensureCloudBackupAccountSelected(forceAccountChooser: true);
  }

  Future<_DriveSession?> _openDriveSession({
    required bool forceAccountChooser,
  }) async {
    if (kIsWeb && forceAccountChooser) return null;

    final account = await requireInteractiveSignIn(
      forceAccountChooser: forceAccountChooser,
    );
    if (account == null) return null;

    final driveApi = await _driveApiForAccount(account);
    return _DriveSession(driveApi: driveApi);
  }

  Future<drive.DriveApi> _driveApiForAccount(
    GoogleSignInAccount account,
  ) async {
    _driveAuthClient ??= _GoogleAuthClient(() async {
      final active = _googleSignInClient().currentUser ?? account;
      return Map<String, String>.from(await active.authHeaders);
    });
    return drive.DriveApi(_driveAuthClient!);
  }

  Future<String?> _findDriveFileIdInAppDataForVault({
    required drive.DriveApi driveApi,
    required String vaultId,
  }) async {
    for (final file in await _listAppDataDriveFiles(driveApi: driveApi)) {
      final properties = file.appProperties;
      if (properties?['nijaVaultId'] == vaultId) {
        return file.id;
      }
      final content = await _downloadDriveFileContent(driveApi, file);
      if (content == null) continue;
      if (vaultIdFromNijaVaultContent(content) == vaultId) {
        return file.id;
      }
    }
    return null;
  }

  Future<String?> _findLegacyDriveFileIdForVault({
    required drive.DriveApi driveApi,
    required String vaultId,
  }) async {
    for (final file in await _listLegacyCandidateBackupDriveFiles(driveApi)) {
      final content = await _downloadDriveFileContent(driveApi, file);
      if (content == null) continue;
      if (vaultIdFromNijaVaultContent(content) == vaultId) {
        return file.id;
      }
    }
    return null;
  }

  Future<void> _uploadVaultToAppDataFolder({
    required drive.DriveApi driveApi,
    required String vaultId,
    required String suggestedName,
    required String content,
  }) async {
    final bytes = utf8.encode(content);
    final media = drive.Media(Stream<List<int>>.value(bytes), bytes.length);
    final existingId = await _findDriveFileIdInAppDataForVault(
      driveApi: driveApi,
      vaultId: vaultId,
    );
    final meta = drive.File()
      ..name = suggestedName
      ..mimeType = 'application/json'
      ..modifiedTime = DateTime.now().toUtc()
      ..appProperties = <String, String>{'nijaVaultId': vaultId};

    if (existingId != null) {
      await driveApi.files.update(meta, existingId, uploadMedia: media);
      return;
    }

    meta.parents = <String>[_appDataFolderId];
    await driveApi.files.create(meta, uploadMedia: media);
  }

  Future<CloudVaultBackupFile?> _findCloudBackupForVault({
    required drive.DriveApi driveApi,
    required String vaultId,
  }) async {
    final backups = await _listAllCloudBackups(
      driveApi: driveApi,
      vaultId: vaultId,
    );
    if (backups.isEmpty) return null;
    return backups.first;
  }

  Future<List<CloudVaultBackupFile>> _listAllCloudBackups({
    required drive.DriveApi driveApi,
    String? vaultId,
  }) async {
    final candidates = await _listCandidateBackupDriveFiles(driveApi);
    final backupsByVaultId = <String, CloudVaultBackupFile>{};
    var scanned = 0;
    for (final file in candidates) {
      if (scanned >= _maxBackupCandidatesToScan) break;
      if (!_looksLikeBackupDriveFile(file)) continue;
      scanned++;

      if (vaultId != null) {
        final propertyVaultId =
            file.appProperties?['nijaVaultId']?.trim() ?? '';
        if (propertyVaultId.isNotEmpty && propertyVaultId != vaultId) {
          continue;
        }
      }

      final propertyVaultId = file.appProperties?['nijaVaultId']?.trim() ?? '';
      final driveFileId = file.id?.trim() ?? '';
      if (propertyVaultId.isNotEmpty && driveFileId.isNotEmpty) {
        if (vaultId != null && propertyVaultId != vaultId) {
          continue;
        }
        final backup = CloudVaultBackupFile(
          storageId: 'gdrive_$driveFileId.nija',
          label: file.name ?? 'Google Drive backup',
          content: '',
          fileName: file.name ?? '',
          modifiedAt: file.modifiedTime?.toLocal(),
          driveFileId: driveFileId,
          listedVaultId: propertyVaultId,
        );
        final existing = backupsByVaultId[propertyVaultId];
        if (existing == null ||
            (cloudBackupEffectiveUpdatedAt(backup) ??
                    DateTime.fromMillisecondsSinceEpoch(0))
                .isAfter(
                  cloudBackupEffectiveUpdatedAt(existing) ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                )) {
          backupsByVaultId[propertyVaultId] = backup;
        }
        continue;
      }

      final content = await _downloadDriveFileContent(driveApi, file);
      if (content == null || !looksLikeNijaVaultContent(content)) continue;
      final contentVaultId = vaultIdFromNijaVaultContent(content);
      if (contentVaultId.isEmpty) continue;
      if (vaultId != null && contentVaultId != vaultId) continue;

      final backup = CloudVaultBackupFile(
        storageId: 'gdrive_${file.id}.nija',
        label: cloudBackupLabelFromContent(
          fallbackName: file.name ?? 'Google Drive backup',
          content: content,
        ),
        content: content,
        fileName: file.name ?? '',
        modifiedAt: file.modifiedTime?.toLocal(),
        revision: vaultRevisionFromNijaVaultContent(content),
        versionId: vaultVersionIdFromNijaVaultContent(content),
        updatedAt: vaultUpdatedAtFromNijaVaultContent(content),
        driveFileId: file.id ?? '',
        listedVaultId: contentVaultId,
      );
      final existing = backupsByVaultId[contentVaultId];
      if (existing == null ||
          vaultRevisionFromNijaVaultContent(backup.content) >
              vaultRevisionFromNijaVaultContent(existing.content)) {
        backupsByVaultId[contentVaultId] = backup;
      }
    }
    final backups = backupsByVaultId.values.toList(growable: false);
    backups.sort((a, b) {
      final revisionCompare = b.revision.compareTo(a.revision);
      if (revisionCompare != 0) return revisionCompare;
      final aTime = cloudBackupEffectiveUpdatedAt(a);
      final bTime = cloudBackupEffectiveUpdatedAt(b);
      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime);
      }
      if (aTime != null) return -1;
      if (bTime != null) return 1;
      return 0;
    });
    return backups;
  }

  Future<List<drive.File>> _listCandidateBackupDriveFiles(
    drive.DriveApi driveApi,
  ) async {
    final seen = <String>{};
    final candidates = <drive.File>[];

    for (final file in await _listAppDataDriveFiles(driveApi: driveApi)) {
      final id = file.id;
      if (id == null || id.isEmpty || !seen.add(id)) continue;
      candidates.add(file);
    }

    if (!kIsWeb) {
      for (final file in await _listLegacyCandidateBackupDriveFiles(driveApi)) {
        final id = file.id;
        if (id == null || id.isEmpty || !seen.add(id)) continue;
        candidates.add(file);
      }
    }

    candidates.sort((a, b) {
      final aTime = a.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return candidates;
  }

  Future<List<drive.File>> _listLegacyCandidateBackupDriveFiles(
    drive.DriveApi driveApi,
  ) async {
    final seen = <String>{};
    final candidates = <drive.File>[];
    // `appProperties has { key='...' }` without a value returns 400 from Drive.
    final queries = <String>[
      "name contains 'backup_'",
      "name contains '.nija'",
    ];
    for (final query in queries) {
      try {
        final files = await _listDriveFiles(driveApi: driveApi, query: query);
        for (final file in files) {
          final id = file.id;
          if (id == null || id.isEmpty || !seen.add(id)) continue;
          candidates.add(file);
        }
      } catch (error) {
        debugLogCloudError('GoogleDriveLegacyList($query)', error);
      }
    }
    return candidates;
  }

  bool _looksLikeBackupDriveFile(drive.File file) {
    final properties = file.appProperties;
    if (properties != null && properties.containsKey('nijaVaultId')) {
      return true;
    }
    final name = file.name?.trim() ?? '';
    if (name.isEmpty) return false;
    return looksLikeVaultBackupName(name);
  }

  Future<List<drive.File>> _listAppDataDriveFiles({
    required drive.DriveApi driveApi,
  }) async {
    try {
      final list = await driveApi.files.list(
        $fields: 'files(id,name,modifiedTime,appProperties,mimeType)',
        spaces: 'appDataFolder',
        pageSize: 100,
      );
      return list.files ?? const <drive.File>[];
    } catch (error) {
      debugLogCloudError('GoogleDriveListAppData', error);
      rethrow;
    }
  }

  Future<List<drive.File>> _listDriveFiles({
    required drive.DriveApi driveApi,
    required String query,
  }) async {
    final list = await driveApi.files.list(
      q: query,
      $fields: 'files(id,name,modifiedTime,appProperties,mimeType)',
      spaces: 'drive',
      pageSize: 100,
    );
    return list.files ?? const <drive.File>[];
  }

  Future<String?> _downloadDriveFileContent(
    drive.DriveApi driveApi,
    drive.File file,
  ) async {
    final id = file.id;
    if (id == null || id.isEmpty) return null;
    try {
      final media = await driveApi.files
          .get(id, downloadOptions: drive.DownloadOptions.fullMedia)
          .timeout(_driveDownloadTimeout);
      if (media is! drive.Media) return null;
      final bytes = <int>[];
      await for (final chunk in media.stream.timeout(_driveDownloadTimeout)) {
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes);
    } catch (error) {
      debugLogCloudError('GoogleDriveDownload(${file.name ?? id})', error);
      return null;
    }
  }
}

class _DriveSession {
  _DriveSession({required this.driveApi});

  final drive.DriveApi driveApi;
}

String vaultIdFromNijaVaultContent(String content) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is! Map) return '';
    return decoded['vaultId']?.toString().trim() ?? '';
  } catch (_) {
    return '';
  }
}

int vaultRevisionFromNijaVaultContent(String content) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is! Map) return 0;
    return int.tryParse(decoded['revision']?.toString() ?? '') ?? 0;
  } catch (_) {
    return 0;
  }
}

String vaultUpdatedAtFromNijaVaultContent(String content) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is! Map) return '';
    return decoded['updatedAt']?.toString().trim() ?? '';
  } catch (_) {
    return '';
  }
}

String vaultVersionIdFromNijaVaultContent(String content) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is! Map) return '';
    return decoded['vaultVersionId']?.toString().trim() ?? '';
  } catch (_) {
    return '';
  }
}

DateTime? backupTimestampFromFileName(String name) {
  final match = RegExp(r'backup_(\d{8})_(\d{4})').firstMatch(name);
  if (match == null) return null;
  final datePart = match.group(1)!;
  final timePart = match.group(2)!;
  try {
    return DateTime(
      int.parse(datePart.substring(0, 4)),
      int.parse(datePart.substring(4, 6)),
      int.parse(datePart.substring(6, 8)),
      int.parse(timePart.substring(0, 2)),
      int.parse(timePart.substring(2, 4)),
    );
  } catch (_) {
    return null;
  }
}

DateTime? cloudBackupEffectiveUpdatedAt(CloudVaultBackupFile backup) {
  if (backup.modifiedAt != null) return backup.modifiedAt;
  final vaultUpdated = backup.updatedAt.trim();
  if (vaultUpdated.isNotEmpty) {
    final parsed = DateTime.tryParse(vaultUpdated);
    if (parsed != null) return parsed.toLocal();
  }
  final fromFileName = backupTimestampFromFileName(backup.fileName);
  if (fromFileName != null) return fromFileName;
  return backupTimestampFromFileName(backup.label);
}

String formatCloudBackupLocalDateTime(DateTime value) {
  String two(int input) => input.toString().padLeft(2, '0');
  final local = value.toLocal();
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String cloudBackupDisplayTitle(CloudVaultBackupFile backup) {
  try {
    final decoded = jsonDecode(backup.content);
    if (decoded is Map) {
      final vaultName = decoded['vaultName']?.toString().trim() ?? '';
      if (vaultName.isNotEmpty) return vaultName;
    }
  } catch (_) {
    // Fall through to label and vault id.
  }

  final label = backup.label.trim();
  if (label.isNotEmpty && !looksLikeVaultBackupName(label)) {
    return label;
  }

  final vaultId = backup.listedVaultId.trim().isNotEmpty
      ? backup.listedVaultId.trim()
      : vaultIdFromNijaVaultContent(backup.content);
  if (vaultId.isNotEmpty) {
    final short = vaultId.length <= 8 ? vaultId : vaultId.substring(0, 8);
    return 'Vault $short';
  }
  return 'Cloud vault backup';
}

String cloudBackupLastUpdatedSubtitle(CloudVaultBackupFile backup) {
  final effective = cloudBackupEffectiveUpdatedAt(backup);
  if (effective != null) {
    return 'Last updated ${formatCloudBackupLocalDateTime(effective)}';
  }
  if (backup.revision > 0) {
    return 'Revision ${backup.revision}';
  }
  return 'Google Drive backup';
}

bool looksLikeVaultBackupName(String name) {
  final normalized = name.toLowerCase();
  return normalized.endsWith('.nija') || normalized.startsWith('backup_');
}

bool looksLikeNijaVaultContent(String content) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is! Map) return false;
    return decoded['format'] == 'Nija' &&
        vaultIdFromNijaVaultContent(content).isNotEmpty &&
        (decoded['encryptedVaultKey']?.toString().trim().isNotEmpty ?? false);
  } catch (_) {
    return false;
  }
}

String cloudBackupLabelFromContent({
  required String fallbackName,
  required String content,
}) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is Map) {
      final vaultName = decoded['vaultName']?.toString().trim() ?? '';
      if (vaultName.isNotEmpty) return vaultName;
    }
  } catch (_) {
    // Fall back to file name.
  }
  return fallbackName.isEmpty ? 'Google Drive backup' : fallbackName;
}

void debugLogCloudError(String operation, Object error) {
  if (!kDebugMode) return;
  debugPrint('[VaultPortability][$operation] $error');
}

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headerProvider);

  final Future<Map<String, String>> Function() _headerProvider;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(await _headerProvider());
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

GoogleSignIn _googleSignInClient() {
  final cached = _googleSignInInstance;
  if (cached != null) {
    return cached;
  }

  final GoogleSignIn client;
  if (kIsWeb) {
    const webClientId = GoogleOAuthConfig.webClientId;
    if (webClientId.isEmpty) {
      throw StateError(
        'NIJA_GOOGLE_WEB_CLIENT_ID is required for web cloud backup and restore.',
      );
    }
    client = GoogleSignIn(clientId: webClientId, scopes: _driveScopes);
  } else {
    const nativeServerClientId = GoogleOAuthConfig.nativeServerClientId;
    client = GoogleSignIn(
      scopes: _driveScopes,
      serverClientId: nativeServerClientId.isEmpty
          ? null
          : nativeServerClientId,
    );
  }

  _googleSignInInstance = client;
  return client;
}
