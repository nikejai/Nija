import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/models/vault_file.dart';
import 'private_vault_store.dart';

/// High-performance, streaming binary container for Nija vaults (NIJA V2).
///
/// Eliminates Base64 memory expansion and enables packaging/unpacking multi-gigabyte
/// vaults with a strictly bounded memory footprint (< 15 MB RAM).
class StreamingVaultContainer {
  StreamingVaultContainer._();

  /// Magic identifier: 'N', 'I', 'J', 'A', version 2, minor 0.
  static const List<int> magicBytes = <int>[0x4E, 0x49, 0x4A, 0x41, 0x02, 0x00];
  static const int maxSectionNameBytes = 255;
  static const int maxSectionDataBytes = 1024 * 1024 * 1024;
  static const int maxPeekHeaderBytes = 1024 * 1024;
  static final RegExp _safeSectionNamePattern = RegExp(r'^[A-Za-z0-9._-]+$');

  static bool isValidSectionFileName(String fileName) {
    if (fileName.isEmpty ||
        fileName == '.' ||
        fileName == '..' ||
        fileName.contains('..') ||
        fileName.contains('/') ||
        fileName.contains('\\') ||
        fileName.endsWith('.tmp')) {
      return false;
    }
    if (utf8.encode(fileName).length > maxSectionNameBytes) return false;
    return _safeSectionNamePattern.hasMatch(fileName);
  }

  /// Checks if [bytes] start with the NIJA V2 magic header.
  static bool isContainerBytes(List<int> bytes) {
    if (bytes.length < magicBytes.length) return false;
    for (var i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) return false;
    }
    return true;
  }

  /// Checks if the file at [filePath] starts with the NIJA V2 container magic bytes.
  static Future<bool> isContainerFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;
      final raf = file.openSync(mode: FileMode.read);
      try {
        final prefix = raf.readSync(magicBytes.length);
        return isContainerBytes(prefix);
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return false;
    }
  }

  /// Packs a vault from [store] identified by [vaultStoreId] directly into [targetFile].
  static Future<void> packPrivateStoreToFile({
    required PrivateVaultStore store,
    required String vaultStoreId,
    required File targetFile,
  }) async {
    await targetFile.parent.create(recursive: true);
    final tempFile = File('${targetFile.path}.tmp_${DateTime.now().millisecondsSinceEpoch}');
    final sink = tempFile.openWrite();
    try {
      await packPrivateStoreToSink(
        store: store,
        vaultStoreId: vaultStoreId,
        sink: sink,
      );
      await sink.flush();
      await sink.close();
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  /// Packs all sections of [vaultStoreId] into [sink].
  ///
  /// Places `header.json` as the very first section entry so the container's
  /// metadata can be inspected from the stream prefix without reading the entire payload.
  static Future<void> packPrivateStoreToSink({
    required PrivateVaultStore store,
    required String vaultStoreId,
    required EventSink<List<int>> sink,
  }) async {
    sink.add(magicBytes);

    final structure = await store.describeVault(vaultStoreId);
    final files = Map<String, dynamic>.from(
      structure['files'] as Map? ?? const <String, dynamic>{},
    );

    // Place header.json first, followed by remaining files in stable alphabetical order.
    final fileNames = files.keys.toList()
      ..sort((a, b) {
        if (a == 'header.json') return -1;
        if (b == 'header.json') return 1;
        return a.compareTo(b);
      });

    for (final fileName in fileNames) {
      final nameBytes = utf8.encode(fileName);
      final size = files[fileName] is int ? files[fileName] as int : 0;

      // Meta header: 4 bytes name length, name UTF-8, 8 bytes data length (big-endian).
      final meta = ByteData(4 + nameBytes.length + 8);
      meta.setUint32(0, nameBytes.length, Endian.big);
      for (var i = 0; i < nameBytes.length; i++) {
        meta.setUint8(4 + i, nameBytes[i]);
      }
      meta.setUint64(4 + nameBytes.length, size, Endian.big);
      sink.add(meta.buffer.asUint8List());

      // Stream section payload directly without in-memory buffering.
      final sectionStream = store.openSectionRead(vaultStoreId, fileName);
      await for (final chunk in sectionStream) {
        sink.add(chunk);
      }
    }

    // End of container sentinel: 4 zero bytes.
    final sentinel = ByteData(4)..setUint32(0, 0, Endian.big);
    sink.add(sentinel.buffer.asUint8List());
  }

  /// Unpacks a container [sourceFile] directly into [store] under [targetStoreId].
  ///
  /// Returns the parsed [VaultFile] header.
  static Future<VaultFile> unpackFileToPrivateStore({
    required File sourceFile,
    required PrivateVaultStore store,
    required String targetStoreId,
  }) async {
    final stream = sourceFile.openRead();
    return unpackStreamToPrivateStore(
      stream: stream,
      store: store,
      targetStoreId: targetStoreId,
    );
  }

  /// Unpacks a binary container from [stream] directly into [store] under [targetStoreId].
  static Future<VaultFile> unpackStreamToPrivateStore({
    required Stream<List<int>> stream,
    required PrivateVaultStore store,
    required String targetStoreId,
  }) async {
    final reader = _StreamChunkReader(stream);
    try {
      // 1. Verify magic bytes
      final magic = await reader.readExact(magicBytes.length);
      if (!isContainerBytes(magic)) {
        throw const FormatException('Not a valid NIJA V2 streaming container.');
      }

      // 2. Read entries sequentially
      while (true) {
        final nameLenBytes = await reader.readExact(4);
        final nameLen = ByteData.sublistView(nameLenBytes).getUint32(0, Endian.big);
        if (nameLen == 0) {
          // End of container sentinel reached
          break;
        }
        if (nameLen > maxSectionNameBytes) {
          throw const FormatException('Section name exceeds maximum length.');
        }

        final nameBytes = await reader.readExact(nameLen);
        final fileName = utf8.decode(nameBytes);
        if (!isValidSectionFileName(fileName)) {
          throw FormatException('Invalid section name: $fileName');
        }

        final dataLenBytes = await reader.readExact(8);
        final dataLen = ByteData.sublistView(dataLenBytes).getUint64(0, Endian.big);
        if (dataLen > maxSectionDataBytes) {
          throw const FormatException('Section payload exceeds maximum size.');
        }

        // Stream exactly dataLen bytes into the target section
        final dataStream = reader.sliceStream(dataLen);
        await store.writeSectionStream(targetStoreId, fileName, dataStream);
      }

      return store.readHeader(targetStoreId);
    } finally {
      await reader.cancel();
    }
  }

  /// Peeks and parses the [VaultFile] header from the prefix of [bytes].
  static VaultFile? peekHeaderFromBytes(Uint8List bytes) {
    try {
      if (!isContainerBytes(bytes)) return null;
      var offset = magicBytes.length;
      if (offset + 4 > bytes.length) return null;
      final nameLen = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0, Endian.big);
      offset += 4;
      if (nameLen == 0 || nameLen > maxSectionNameBytes || offset + nameLen > bytes.length) {
        return null;
      }
      final fileName = utf8.decode(bytes.sublist(offset, offset + nameLen));
      offset += nameLen;
      if (fileName != 'header.json' || offset + 8 > bytes.length) return null;
      final dataLen = ByteData.sublistView(bytes, offset, offset + 8).getUint64(0, Endian.big);
      offset += 8;
      if (dataLen > maxPeekHeaderBytes || offset + dataLen > bytes.length) {
        return null;
      }
      final jsonString = utf8.decode(bytes.sublist(offset, offset + dataLen));
      final decoded = Map<String, dynamic>.from(jsonDecode(jsonString) as Map);
      return VaultFile.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Unpacks a NIJA V2 binary container from [bytes] into a JSON snapshot string
  /// suitable for JSON-based importers (e.g. Web).
  static String containerBytesToJsonSnapshot(Uint8List bytes) {
    if (!isContainerBytes(bytes)) {
      throw const FormatException('Not a valid NIJA V2 streaming container.');
    }
    var offset = magicBytes.length;
    VaultFile? header;
    String? encryptedManifest;
    final encryptedSections = <String, String>{};

    while (true) {
      if (offset + 4 > bytes.length) {
        throw const FormatException('Unexpected end of NIJA V2 container.');
      }
      final nameLen = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0, Endian.big);
      offset += 4;
      if (nameLen == 0) break;
      if (nameLen > maxSectionNameBytes || offset + nameLen > bytes.length) {
        throw const FormatException('Invalid section name length.');
      }
      final fileName = utf8.decode(bytes.sublist(offset, offset + nameLen));
      offset += nameLen;
      if (!isValidSectionFileName(fileName) || offset + 8 > bytes.length) {
        throw FormatException('Invalid section name: $fileName');
      }
      final dataLen = ByteData.sublistView(bytes, offset, offset + 8).getUint64(0, Endian.big);
      offset += 8;
      if (dataLen > maxSectionDataBytes || offset + dataLen > bytes.length) {
        throw const FormatException('Invalid section payload length.');
      }
      final sectionBytes = bytes.sublist(offset, offset + dataLen);
      offset += dataLen;

      if (fileName == 'header.json') {
        final decoded = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(sectionBytes)) as Map,
        );
        header = VaultFile.fromJson(decoded);
      } else if (fileName == 'manifest.enc') {
        encryptedManifest = base64Encode(sectionBytes);
      } else {
        encryptedSections[fileName] = base64Encode(sectionBytes);
      }
    }

    if (header == null) {
      throw const FormatException('NIJA V2 container missing header.json.');
    }
    final snapshot = header.copyWith(
      formatVersion: 2,
      encryptedPayload: null,
      encryptedManifest: encryptedManifest,
      encryptedSections: encryptedSections,
    );
    return jsonEncode(snapshot.toJson());
  }

  /// Peeks and parses the [VaultFile] header from the first bytes of a container [sourceFile]
  /// without reading or unpacking the entire vault.
  static Future<VaultFile?> peekHeaderFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final raf = file.openSync(mode: FileMode.read);
      try {
        final magic = raf.readSync(magicBytes.length);
        if (!isContainerBytes(magic)) return null;

        final nameLenBytes = raf.readSync(4);
        if (nameLenBytes.length < 4) return null;
        final nameLen = ByteData.sublistView(nameLenBytes).getUint32(0, Endian.big);
        if (nameLen == 0 || nameLen > maxSectionNameBytes) return null;

        final nameBytes = raf.readSync(nameLen);
        final fileName = utf8.decode(nameBytes);
        if (fileName != 'header.json') return null;

        final dataLenBytes = raf.readSync(8);
        if (dataLenBytes.length < 8) return null;
        final dataLen = ByteData.sublistView(dataLenBytes).getUint64(0, Endian.big);
        if (dataLen > maxPeekHeaderBytes) return null;

        final headerBytes = raf.readSync(dataLen);
        final jsonString = utf8.decode(headerBytes);
        final decoded = Map<String, dynamic>.from(jsonDecode(jsonString) as Map);
        return VaultFile.fromJson(decoded);
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return null;
    }
  }
}

/// Helper to read exact byte counts and sub-streams from a `Stream<List<int>>`.
class _StreamChunkReader {
  _StreamChunkReader(Stream<List<int>> stream) {
    _subscription = stream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: true,
    );
  }

  late final StreamSubscription<List<int>> _subscription;
  final List<List<int>> _buffer = <List<int>>[];
  int _bufferBytes = 0;
  bool _isDone = false;
  Object? _error;

  Completer<void>? _dataCompleter;

  Future<void> cancel() async {
    await _subscription.cancel();
  }

  void _onData(List<int> chunk) {
    if (chunk.isEmpty) return;
    _buffer.add(chunk);
    _bufferBytes += chunk.length;
    _dataCompleter?.complete();
    _dataCompleter = null;
  }

  void _onError(Object error) {
    _error = error;
    _dataCompleter?.completeError(error);
    _dataCompleter = null;
  }

  void _onDone() {
    _isDone = true;
    _dataCompleter?.complete();
    _dataCompleter = null;
  }

  Future<void> _waitForBytes(int count) async {
    while (_bufferBytes < count) {
      if (_error != null) throw _error!;
      if (_isDone) {
        throw StateError('Unexpected end of stream: needed $count bytes, got $_bufferBytes');
      }
      _dataCompleter ??= Completer<void>();
      await _dataCompleter!.future;
    }
  }

  Future<Uint8List> readExact(int count) async {
    await _waitForBytes(count);
    final result = Uint8List(count);
    var targetOffset = 0;

    while (targetOffset < count) {
      final first = _buffer.first;
      final remainingNeeded = count - targetOffset;
      if (first.length <= remainingNeeded) {
        result.setRange(targetOffset, targetOffset + first.length, first);
        targetOffset += first.length;
        _buffer.removeAt(0);
        _bufferBytes -= first.length;
      } else {
        result.setRange(targetOffset, count, first.sublist(0, remainingNeeded));
        _buffer[0] = first.sublist(remainingNeeded);
        _bufferBytes -= remainingNeeded;
        targetOffset = count;
      }
    }

    return result;
  }

  Stream<List<int>> sliceStream(int totalBytes) async* {
    var remaining = totalBytes;
    while (remaining > 0) {
      if (_bufferBytes == 0) {
        if (_error != null) throw _error!;
        if (_isDone) {
          throw StateError('Unexpected end of stream: needed $remaining more bytes');
        }
        _dataCompleter ??= Completer<void>();
        await _dataCompleter!.future;
      }

      final first = _buffer.removeAt(0);
      if (first.length <= remaining) {
        _bufferBytes -= first.length;
        remaining -= first.length;
        yield first;
      } else {
        final toYield = first.sublist(0, remaining);
        _buffer.insert(0, first.sublist(remaining));
        _bufferBytes -= remaining;
        remaining = 0;
        yield toYield;
      }
    }
  }
}
