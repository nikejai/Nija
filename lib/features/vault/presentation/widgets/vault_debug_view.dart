part of '../vault_app_shell.dart';

class _VaultDebugView extends StatelessWidget {
  const _VaultDebugView({
    required this.internalsFuture,
    required this.onRefresh,
    required this.hasReader,
    required this.activeVaultName,
    required this.vaultSizeBytes,
    required this.itemCount,
    required this.noteCount,
    required this.customTypeCount,
  });

  final Future<Map<String, dynamic>>? internalsFuture;
  final VoidCallback? onRefresh;
  final bool hasReader;
  final String activeVaultName;
  final int vaultSizeBytes;
  final int itemCount;
  final int noteCount;
  final int customTypeCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: FutureBuilder<Map<String, dynamic>>(
        future: internalsFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return ListView(
            children: [
              _DebugHeader(onRefresh: onRefresh),
              const SizedBox(height: 14),
              if (!hasReader)
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.info_outline,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    title: const Text('Debug internals unavailable'),
                    subtitle: Text(
                      'No debug internals reader is registered.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              else if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError || data == null)
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.error_outline,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    title: const Text('Unable to read internals'),
                    subtitle: Text(
                      snapshot.error?.toString() ?? 'No data',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              else ...[
                _DebugInfoCard(
                  title: 'Snapshot',
                  rows: _debugRows(data, const [
                    'format',
                    'formatVersion',
                    'schemaVersion',
                    'storageLayoutVersion',
                    'manifestVersion',
                    'snapshotBytes',
                    'workingStoreBytes',
                  ]),
                ),
                const SizedBox(height: 10),
                _DebugInfoCard(
                  title: 'Identity',
                  rows: _debugRows(data, const [
                    'vaultId',
                    'vaultVersionId',
                    'revision',
                    'createdAt',
                    'updatedAt',
                    'lastModifiedByDeviceId',
                  ]),
                ),
                const SizedBox(height: 10),
                _DebugInfoCard(
                  title: 'Crypto',
                  rows: _debugMapRows(data['crypto']),
                ),
                const SizedBox(height: 10),
                _DebugInfoCard(
                  title: 'Encrypted sections',
                  rows: _encryptedSectionRows(data['encryptedSections']),
                  maxHeight: 220,
                ),
                const SizedBox(height: 10),
                _DebugInfoCard(
                  title: 'Working folder',
                  rows: _workingFolderRows(data['workingStore']),
                ),
                const SizedBox(height: 10),
                _DebugFileTreeCard(store: data['workingStore']),
                const SizedBox(height: 10),
                _DebugInfoCard(
                  title: 'Working files',
                  rows: _workingFileRows(data['workingStore']),
                  maxHeight: 260,
                ),
                const SizedBox(height: 10),
                _DebugInfoCard(
                  title: 'Session',
                  rows: [
                    MapEntry<String, String>(
                      'activeVaultName',
                      activeVaultName,
                    ),
                    MapEntry<String, String>(
                      'exportVaultSizeBytes',
                      vaultSizeBytes.toString(),
                    ),
                    MapEntry<String, String>('items', itemCount.toString()),
                    MapEntry<String, String>('notes', noteCount.toString()),
                    MapEntry<String, String>(
                      'customTypes',
                      customTypeCount.toString(),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DebugHeader extends StatelessWidget {
  const _DebugHeader({required this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: _SectionHeader(
            title: 'Vault internals',
            subtitle: 'Debug-only storage metadata and encrypted sections.',
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          key: const ValueKey('debug-internals-refresh'),
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh internals',
        ),
      ],
    );
  }
}

class _DebugInfoCard extends StatelessWidget {
  const _DebugInfoCard({
    required this.title,
    required this.rows,
    this.maxHeight,
  });

  final String title;
  final List<MapEntry<String, String>> rows;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text(
                'No data',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              )
            else
              _DebugRowsView(rows: rows, maxHeight: maxHeight),
          ],
        ),
      ),
    );
  }
}

class _DebugRowsView extends StatelessWidget {
  const _DebugRowsView({required this.rows, this.maxHeight});

  final List<MapEntry<String, String>> rows;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) => _DebugInfoRow(row: row)).toList(),
    );
    if (maxHeight == null) return content;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight!),
      child: Scrollbar(
        child: SingleChildScrollView(primary: false, child: content),
      ),
    );
  }
}

class _DebugInfoRow extends StatelessWidget {
  const _DebugInfoRow({required this.row});

  final MapEntry<String, String> row;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              row.key,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              row.value,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugFileTreeCard extends StatelessWidget {
  const _DebugFileTreeCard({required this.store});

  static const int _maxRenderedFiles = 80;
  static const double _maxHeight = 260;
  final dynamic store;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tree = _buildTree();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vault file tree',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (tree.isEmpty)
              Text(
                'No files',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: _maxHeight),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    primary: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: tree
                          .map((line) => _DebugTreeLine(line: line))
                          .toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_DebugTreeLineData> _buildTree() {
    if (store is! Map) return const <_DebugTreeLineData>[];
    final root = (store as Map)['root']?.toString() ?? 'vault';
    final files = (store as Map)['files'];
    if (files is! Map) return const <_DebugTreeLineData>[];
    final entries =
        files.entries
            .map(
              (entry) => MapEntry<String, int>(
                entry.key.toString(),
                int.tryParse(entry.value.toString()) ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    final core = <MapEntry<String, int>>[];
    final documents = <String, List<MapEntry<String, int>>>{};
    final other = <MapEntry<String, int>>[];
    for (final entry in entries) {
      final docId = documentTreeId(entry.key);
      if (isCoreDebugFile(entry.key)) {
        core.add(entry);
      } else if (docId != null) {
        documents
            .putIfAbsent(docId, () => <MapEntry<String, int>>[])
            .add(entry);
      } else {
        other.add(entry);
      }
    }

    final lines = <_DebugTreeLineData>[
      _DebugTreeLineData(depth: 0, label: _rootLabel(root), folder: true),
    ];
    var renderedFiles = 0;

    bool canRenderMoreFiles() => renderedFiles < _maxRenderedFiles;

    Iterable<_DebugTreeLineData> cappedFileLines(
      Iterable<MapEntry<String, int>> files, {
      required int depth,
    }) sync* {
      for (final entry in files) {
        if (!canRenderMoreFiles()) return;
        renderedFiles++;
        yield _fileLine(entry, depth: depth);
      }
    }

    if (core.isNotEmpty && canRenderMoreFiles()) {
      lines.add(
        const _DebugTreeLineData(depth: 1, label: 'core', folder: true),
      );
      lines.addAll(cappedFileLines(core, depth: 2));
    }
    if (documents.isNotEmpty && canRenderMoreFiles()) {
      lines.add(
        const _DebugTreeLineData(depth: 1, label: 'documents', folder: true),
      );
      for (final docId in documents.keys.toList()..sort()) {
        if (!canRenderMoreFiles()) break;
        final docFiles = documents[docId]!;
        final docBytes = docFiles.fold<int>(
          0,
          (sum, entry) => sum + entry.value,
        );
        renderedFiles += docFiles.length;
        lines.add(
          _DebugTreeLineData(
            depth: 2,
            label: docId,
            detail: '${docFiles.length} files, $docBytes bytes',
            folder: true,
          ),
        );
      }
    }
    if (other.isNotEmpty && canRenderMoreFiles()) {
      lines.add(
        const _DebugTreeLineData(depth: 1, label: 'other', folder: true),
      );
      lines.addAll(cappedFileLines(other, depth: 2));
    }
    if (entries.length > renderedFiles) {
      lines.add(
        _DebugTreeLineData(
          depth: 1,
          label:
              '${entries.length - renderedFiles} more files hidden to keep Debug responsive',
        ),
      );
    }
    return lines;
  }

  static _DebugTreeLineData _fileLine(
    MapEntry<String, int> entry, {
    required int depth,
  }) {
    return _DebugTreeLineData(
      depth: depth,
      label: entry.key,
      detail: '${entry.value} bytes',
    );
  }

  static String _rootLabel(String root) {
    final normalized = root.replaceAll('\\', '/');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? root : parts.last;
  }

  static bool isCoreDebugFile(String name) {
    return const <String>{
      'header.json',
      'manifest.enc',
      'items.enc',
      'notes.enc',
      'settings.enc',
      'tags.enc',
    }.contains(name);
  }

  static String? documentTreeId(String name) {
    final manifest = RegExp(r'^document_(.+)\.manifest\.enc$').firstMatch(name);
    if (manifest != null) return manifest.group(1);
    final chunk = RegExp(r'^document_(.+)_chunk_\d+\.enc$').firstMatch(name);
    return chunk?.group(1);
  }
}

class _DebugTreeLineData {
  const _DebugTreeLineData({
    required this.depth,
    required this.label,
    this.detail,
    this.folder = false,
  });

  final int depth;
  final String label;
  final String? detail;
  final bool folder;
}

class _DebugTreeLine extends StatelessWidget {
  const _DebugTreeLine({required this.line});

  final _DebugTreeLineData line;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: line.depth * 14.0, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(
            line.folder
                ? Icons.folder_outlined
                : Icons.insert_drive_file_outlined,
            size: 15,
            color: line.folder
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SelectableText(
              line.label,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: line.folder ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (line.detail != null) ...[
            const SizedBox(width: 8),
            Text(
              line.detail!,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

List<MapEntry<String, String>> _debugRows(
  Map<String, dynamic> data,
  List<String> keys,
) {
  return keys
      .where((key) => data.containsKey(key))
      .map((key) => MapEntry<String, String>(key, data[key].toString()))
      .toList();
}

List<MapEntry<String, String>> _debugMapRows(dynamic value) {
  if (value is! Map) return const <MapEntry<String, String>>[];
  return _dedupeDebugRows(
    value.entries
        .map(
          (entry) => MapEntry<String, String>(
            entry.key.toString(),
            entry.value.toString(),
          ),
        )
        .toList(),
  );
}

List<MapEntry<String, String>> _encryptedSectionRows(dynamic value) {
  if (value is! Map) return const <MapEntry<String, String>>[];
  final coreRows = <MapEntry<String, String>>[];
  var documentManifests = 0;
  var documentChunks = 0;
  var documentBytes = 0;
  final otherRows = <MapEntry<String, String>>[];

  for (final entry in value.entries) {
    final name = entry.key.toString();
    final bytes = int.tryParse(entry.value.toString()) ?? 0;
    if (_DebugFileTreeCard.isCoreDebugFile(name)) {
      coreRows.add(MapEntry<String, String>(name, '$bytes bytes'));
    } else if (_isDocumentManifestName(name)) {
      documentManifests += 1;
      documentBytes += bytes;
    } else if (_isDocumentChunkName(name)) {
      documentChunks += 1;
      documentBytes += bytes;
    } else {
      otherRows.add(MapEntry<String, String>(name, '$bytes bytes'));
    }
  }

  coreRows.sort((a, b) => a.key.compareTo(b.key));
  otherRows.sort((a, b) => a.key.compareTo(b.key));
  final rows = <MapEntry<String, String>>[
    ...coreRows,
    if (documentManifests > 0)
      MapEntry<String, String>(
        'document manifests',
        '$documentManifests files',
      ),
    if (documentChunks > 0)
      MapEntry<String, String>('document chunks', '$documentChunks files'),
    if (documentBytes > 0)
      MapEntry<String, String>('document bytes', '$documentBytes bytes'),
    ...otherRows,
  ];
  return _dedupeDebugRows(rows);
}

List<MapEntry<String, String>> _workingFolderRows(dynamic value) {
  if (value is! Map) return const <MapEntry<String, String>>[];
  return <MapEntry<String, String>>[
    MapEntry<String, String>('type', value['type']?.toString() ?? ''),
    MapEntry<String, String>('root', value['root']?.toString() ?? ''),
    const MapEntry<String, String>(
      'layout',
      'header.json, manifest.enc, items.enc, notes.enc, settings.enc, tags.enc',
    ),
  ];
}

List<MapEntry<String, String>> _workingFileRows(dynamic value) {
  if (value is! Map) return const <MapEntry<String, String>>[];
  final files = value['files'];
  if (files is! Map) return const <MapEntry<String, String>>[];
  final coreRows = <MapEntry<String, String>>[];
  final documents = <String, ({int count, int bytes})>{};
  final otherRows = <MapEntry<String, String>>[];
  for (final entry in files.entries) {
    final name = entry.key.toString();
    final bytes = int.tryParse(entry.value.toString()) ?? 0;
    final docId = _DebugFileTreeCard.documentTreeId(name);
    if (_DebugFileTreeCard.isCoreDebugFile(name)) {
      coreRows.add(MapEntry<String, String>(name, '$bytes bytes'));
    } else if (docId != null) {
      final existing = documents[docId] ?? (count: 0, bytes: 0);
      documents[docId] = (
        count: existing.count + 1,
        bytes: existing.bytes + bytes,
      );
    } else {
      otherRows.add(MapEntry<String, String>(name, '$bytes bytes'));
    }
  }

  final documentRows =
      documents.entries
          .map(
            (entry) => MapEntry<String, String>(
              'document ${entry.key}',
              '${entry.value.count} files, ${entry.value.bytes} bytes',
            ),
          )
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
  coreRows.sort((a, b) => a.key.compareTo(b.key));
  otherRows.sort((a, b) => a.key.compareTo(b.key));
  final rows = _dedupeDebugRows([...coreRows, ...documentRows, ...otherRows]);
  const maxRows = 80;
  if (rows.length <= maxRows) return rows;
  return [
    ...rows.take(maxRows),
    MapEntry<String, String>(
      'more',
      '${rows.length - maxRows} files hidden; use Refresh after narrowing the issue.',
    ),
  ];
}

List<MapEntry<String, String>> _dedupeDebugRows(
  List<MapEntry<String, String>> rows,
) {
  final seen = <String>{};
  final deduped = <MapEntry<String, String>>[];
  for (final row in rows) {
    final signature = '${row.key}\u0000${row.value}';
    if (!seen.add(signature)) continue;
    deduped.add(row);
  }
  return deduped;
}

bool _isDocumentManifestName(String name) {
  return RegExp(r'^document_.+\.manifest\.enc$').hasMatch(name);
}

bool _isDocumentChunkName(String name) {
  return RegExp(r'^document_.+_chunk_\d+\.enc$').hasMatch(name);
}
