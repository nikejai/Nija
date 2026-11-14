import 'vault_document_preview_widgets.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

class EncryptedSecretViewerScreen extends StatefulWidget {
  const EncryptedSecretViewerScreen({
    super.key,
    required this.title,
    required this.fields,
    required this.onImport,
  });

  final String title;
  final List<SecretField> fields;
  final VoidCallback onImport;

  @override
  State<EncryptedSecretViewerScreen> createState() =>
      _EncryptedSecretViewerScreenState();
}

class _EncryptedSecretViewerScreenState
    extends State<EncryptedSecretViewerScreen> {
  late final List<bool> _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.fields.map((field) => field.sensitive).toList();
  }

  String _displayValue(int index) {
    final field = widget.fields[index];
    if (!field.sensitive || !_obscured[index]) return field.value;
    return '••••••••';
  }

  Future<void> _copyField(SecretField field) async {
    await Clipboard.setData(
      ClipboardData(text: '${field.key}: ${field.value}'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  Future<void> _copyVisibleSecret() async {
    final buffer = StringBuffer();
    for (var i = 0; i < widget.fields.length; i++) {
      final field = widget.fields[i];
      buffer.writeln('${field.key}: ${_displayValue(i)}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Visible secret copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _copyVisibleSecret,
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy full secret (visible)'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('import-secret-to-vault'),
                onPressed: widget.onImport,
                icon: const Icon(Icons.download_done_outlined),
                label: const Text('Import to vault'),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: widget.fields.isEmpty
                  ? const Center(child: Text('No content'))
                  : ListView.separated(
                      itemCount: widget.fields.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final field = widget.fields[index];
                        return Card(
                          child: ListTile(
                            title: Text(field.key),
                            subtitle: SelectableText(_displayValue(index)),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                if (field.sensitive)
                                  IconButton(
                                    onPressed: () => setState(
                                      () =>
                                          _obscured[index] = !_obscured[index],
                                    ),
                                    icon: Icon(
                                      _obscured[index]
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                IconButton(
                                  onPressed: () => _copyField(field),
                                  icon: const Icon(Icons.copy_outlined),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class EncryptedImportEntry {
  const EncryptedImportEntry({
    required this.index,
    required this.kind,
    required this.bundleEntry,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final String kind;
  final Map<String, dynamic> bundleEntry;
  final String title;
  final String subtitle;
}

class PreparedVaultImport {
  PreparedVaultImport({
    List<Map<String, dynamic>>? items,
    List<Map<String, dynamic>>? notes,
  }) : items = items ?? <Map<String, dynamic>>[],
       notes = notes ?? <Map<String, dynamic>>[];

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> notes;

  bool get isEmpty => items.isEmpty && notes.isEmpty;
}

class EncryptedImportBundleScreen extends StatefulWidget {
  const EncryptedImportBundleScreen({
    super.key,
    required this.entries,
    required this.onImportEntry,
    required this.onImportAll,
  });

  final List<EncryptedImportEntry> entries;
  final Future<bool> Function(EncryptedImportEntry entry) onImportEntry;
  final Future<bool> Function(List<EncryptedImportEntry> entries) onImportAll;

  @override
  State<EncryptedImportBundleScreen> createState() =>
      _EncryptedImportBundleScreenState();
}

class _EncryptedImportBundleScreenState
    extends State<EncryptedImportBundleScreen> {
  final Set<int> _importedIndexes = <int>{};
  final _scrollController = ScrollController();
  bool _importingAll = false;

  List<EncryptedImportEntry> get _remainingEntries => widget.entries
      .where((entry) => !_importedIndexes.contains(entry.index))
      .toList();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encrypted file'),
        actions: [
          TextButton(
            onPressed: _remainingEntries.isEmpty || _importingAll
                ? null
                : _importAll,
            child: _importingAll
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Import all'),
          ),
        ],
      ),
      body: SafeArea(
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          interactive: true,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            itemCount: widget.entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = widget.entries[index];
              final imported = _importedIndexes.contains(entry.index);
              return Material(
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _colorForImportEntry(
                      entry,
                    ).withValues(alpha: 0.16),
                    child: Icon(
                      _iconForImportEntry(entry),
                      color: _colorForImportEntry(entry),
                    ),
                  ),
                  title: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    imported ? 'Imported' : entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: imported
                      ? const Icon(Icons.check_circle, color: Color(0xFF22C55E))
                      : const Icon(Icons.chevron_right),
                  onTap: () => _openEntry(entry, imported: imported),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openEntry(
    EncryptedImportEntry entry, {
    required bool imported,
  }) async {
    final didImport = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EncryptedImportEntryPreviewScreen(
          entry: entry,
          alreadyImported: imported,
          onImport: () => widget.onImportEntry(entry),
        ),
      ),
    );
    if (didImport == true && mounted) {
      setState(() => _importedIndexes.add(entry.index));
    }
  }

  Future<void> _importAll() async {
    setState(() => _importingAll = true);
    final remaining = _remainingEntries;
    final ok = await widget.onImportAll(remaining);
    if (!mounted) return;
    setState(() {
      _importingAll = false;
      if (ok) {
        _importedIndexes.addAll(remaining.map((entry) => entry.index));
      }
    });
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }
}

class EncryptedImportEntryPreviewScreen extends StatefulWidget {
  const EncryptedImportEntryPreviewScreen({
    super.key,
    required this.entry,
    required this.alreadyImported,
    required this.onImport,
  });

  final EncryptedImportEntry entry;
  final bool alreadyImported;
  final Future<bool> Function() onImport;

  @override
  State<EncryptedImportEntryPreviewScreen> createState() =>
      _EncryptedImportEntryPreviewScreenState();
}

class _EncryptedImportEntryPreviewScreenState
    extends State<EncryptedImportEntryPreviewScreen> {
  late bool _imported;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _imported = widget.alreadyImported;
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Scaffold(
      appBar: AppBar(title: Text(_previewTitle(entry))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildPreview(context, entry)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _imported || _importing ? null : _importEntry,
                  icon: _importing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _imported
                              ? Icons.check_circle_outline
                              : Icons.file_download_outlined,
                        ),
                  label: Text(_imported ? 'Imported' : 'Import item'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, EncryptedImportEntry entry) {
    if (entry.kind == 'note') return _buildNotePreview(entry);
    if (entry.kind == 'document') return _buildDocumentPreview(entry);
    return _buildVaultItemPreview(context, entry);
  }

  Widget _buildVaultItemPreview(
    BuildContext context,
    EncryptedImportEntry entry,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final rawEntry = entry.bundleEntry['entry'];
    final item = rawEntry is Map
        ? Map<String, dynamic>.from(rawEntry)
        : const <String, dynamic>{};
    final fields = (item['fields'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((field) => Map<String, dynamic>.from(field))
        .toList();
    if (fields.isEmpty) {
      fields.addAll(_plainTextPreviewFields(entry.bundleEntry['plainText']));
    }
    final type = item['type']?.toString().trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        _ImportPreviewHeader(
          icon: _iconForImportEntry(entry),
          color: _colorForImportEntry(entry),
          title: entry.title,
          subtitle: entry.subtitle,
        ),
        const SizedBox(height: 16),
        if (type != null && type.isNotEmpty)
          _ImportPreviewRow(label: 'Type', value: type),
        if (fields.isEmpty)
          Text(
            'No fields to preview.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          )
        else
          ...fields.map((field) {
            final label = field['label']?.toString() ?? 'Field';
            final value = field['value']?.toString() ?? '';
            return _ImportPreviewRow(label: label, value: value);
          }),
      ],
    );
  }

  Widget _buildNotePreview(EncryptedImportEntry entry) {
    final body = _notePreviewBody(entry);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        _ImportPreviewHeader(
          icon: Icons.sticky_note_2_outlined,
          color: const Color(0xFF6366F1),
          title: entry.title,
          subtitle: 'Secure Note',
        ),
        const SizedBox(height: 16),
        _ImportPreviewRow(label: 'Content', value: body.isEmpty ? '-' : body),
      ],
    );
  }

  Widget _buildDocumentPreview(EncryptedImportEntry entry) {
    return _DocumentImportPreview(entry: entry);
  }

  String _previewTitle(EncryptedImportEntry entry) {
    if (entry.kind == 'note') return 'Note';
    if (entry.kind == 'document') return 'Document';
    return entry.subtitle.isEmpty ? 'Vault Item' : entry.subtitle;
  }

  String _notePreviewBody(EncryptedImportEntry entry) {
    final rawEntry = entry.bundleEntry['entry'];
    if (rawEntry is Map) {
      final delta = rawEntry['delta'];
      if (delta is List) {
        return delta
            .whereType<Map<dynamic, dynamic>>()
            .map((op) => op['insert']?.toString() ?? '')
            .join()
            .trim();
      }
      final preview = rawEntry['preview']?.toString().trim() ?? '';
      if (preview.isNotEmpty) return preview;
    }
    final plainText = entry.bundleEntry['plainText']?.toString() ?? '';
    if (_looksLikeEncodedPreviewData(plainText)) return '';
    return plainText.split('\n').skip(1).join('\n').trim();
  }

  Future<void> _importEntry() async {
    setState(() => _importing = true);
    final ok = await widget.onImport();
    if (!mounted) return;
    setState(() {
      _importing = false;
      _imported = ok;
    });
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }
}

class _DocumentImportPreview extends StatefulWidget {
  const _DocumentImportPreview({required this.entry});

  final EncryptedImportEntry entry;

  @override
  State<_DocumentImportPreview> createState() => _DocumentImportPreviewState();
}

class _DocumentImportPreviewState extends State<_DocumentImportPreview> {
  static const MethodChannel _documentOpenChannel = MethodChannel(
    'nija/document_open',
  );

  final _textPreviewScrollController = ScrollController();
  bool _autoOpenedExternalPreview = false;

  @override
  void dispose() {
    _textPreviewScrollController.dispose();
    super.dispose();
  }

  String get _fileName =>
      widget.entry.bundleEntry['fileName']?.toString().trim().isNotEmpty == true
      ? widget.entry.bundleEntry['fileName'].toString().trim()
      : widget.entry.title;

  String get _extension {
    final extension = widget.entry.bundleEntry['extension']?.toString().trim();
    if (extension != null && extension.isNotEmpty) {
      return extension.toUpperCase();
    }
    final dot = _fileName.lastIndexOf('.');
    if (dot == -1 || dot == _fileName.length - 1) return 'FILE';
    return _fileName.substring(dot + 1).toUpperCase();
  }

  Uint8List? get _bytes {
    final rawBytes = widget.entry.bundleEntry['bytesBase64']?.toString();
    if (rawBytes == null || rawBytes.isEmpty) return null;
    try {
      return Uint8List.fromList(base64Decode(rawBytes));
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final size = int.tryParse(
      widget.entry.bundleEntry['sizeBytes']?.toString() ?? '',
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            children: [
              _DocumentImportHeader(
                title: widget.entry.title,
                fileName: _fileName,
                extension: _extension,
                size: size != null
                    ? _formatDocumentByteCount(size)
                    : bytes == null
                    ? '-'
                    : _formatDocumentByteCount(bytes.length),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildPreview(context, bytes),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context, Uint8List? bytes) {
    if (bytes == null) {
      return const DocumentPreviewMessage(
        icon: Icons.error_outline,
        title: 'Unable to preview document',
        subtitle: 'The encrypted file does not contain readable document data.',
      );
    }
    if (bytes.isEmpty) {
      return const DocumentPreviewMessage(
        icon: Icons.insert_drive_file_outlined,
        title: 'Empty document',
        subtitle: 'There is no content to preview.',
      );
    }
    if (_isImageExtension(_extension)) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              _openExternalPreviewOnce(bytes);
              return DocumentPreviewMessage(
                icon: Icons.broken_image_outlined,
                title: 'Image preview failed',
                subtitle: 'Tap to choose an app that can open this file.',
                onTap: () => _openDocument(bytes),
              );
            },
          ),
        ),
      );
    }
    if (_isTextExtension(_extension)) {
      final text = utf8.decode(bytes, allowMalformed: true);
      return Scrollbar(
        controller: _textPreviewScrollController,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _textPreviewScrollController,
          padding: const EdgeInsets.all(14),
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      );
    }
    if (_isPdfExtension(_extension)) {
      return PdfViewer.data(
        bytes,
        sourceName: 'import-${widget.entry.index}-$_fileName-${bytes.length}',
        params: defaultPdfViewerParams,
      );
    }
    _openExternalPreviewOnce(bytes);
    return DocumentPreviewMessage(
      icon: _extension == 'PDF'
          ? Icons.picture_as_pdf_outlined
          : Icons.insert_drive_file_outlined,
      title: 'Opening $_extension document',
      subtitle: 'Tap to choose an app that can preview this file.',
      onTap: () => _openDocument(bytes),
    );
  }

  void _openExternalPreviewOnce(Uint8List bytes) {
    if (_autoOpenedExternalPreview) return;
    _autoOpenedExternalPreview = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openDocument(bytes);
    });
  }

  Future<void> _openDocument(Uint8List bytes) async {
    final mimeType = _mimeTypeForExtension(_extension);
    try {
      await _documentOpenChannel.invokeMethod<bool>('openDocument', {
        'fileName': _fileName,
        'mimeType': mimeType,
        'bytes': bytes,
      });
    } on MissingPluginException {
      await _shareDocumentFallback(bytes, mimeType);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'No app can open this file.')),
      );
      await _shareDocumentFallback(bytes, mimeType);
    }
  }

  Future<void> _shareDocumentFallback(Uint8List bytes, String mimeType) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: _fileName, mimeType: mimeType)],
      ),
    );
  }
}

class _DocumentImportHeader extends StatelessWidget {
  const _DocumentImportHeader({
    required this.title,
    required this.fileName,
    required this.extension,
    required this.size,
  });

  final String title;
  final String fileName;
  final String extension;
  final String size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFB7185).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.insert_drive_file_outlined,
            color: Color(0xFFFB7185),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$extension · $size · $fileName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImportPreviewHeader extends StatelessWidget {
  const _ImportPreviewHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ImportPreviewRow extends StatelessWidget {
  const _ImportPreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: colorScheme.onSurface)),
        ],
      ),
    );
  }
}

IconData _iconForImportEntry(EncryptedImportEntry entry) {
  if (entry.kind == 'note') return Icons.sticky_note_2_outlined;
  if (entry.kind == 'document') return Icons.folder_outlined;
  return Icons.lock_outline;
}

Color _colorForImportEntry(EncryptedImportEntry entry) {
  if (entry.kind == 'note') return const Color(0xFF6366F1);
  if (entry.kind == 'document') return const Color(0xFFFB923C);
  return const Color(0xFF22C55E);
}

List<Map<String, dynamic>> _plainTextPreviewFields(Object? rawPlainText) {
  final plainText = rawPlainText?.toString() ?? '';
  if (_looksLikeEncodedPreviewData(plainText)) {
    return const <Map<String, dynamic>>[];
  }
  final fields = <Map<String, dynamic>>[];
  final lines = plainText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  for (final line in lines.skip(1)) {
    if (line.startsWith('Type: ')) continue;
    final separator = line.indexOf(':');
    if (separator <= 0 || separator >= line.length - 1) continue;
    final label = line.substring(0, separator).trim();
    final value = line.substring(separator + 1).trim();
    if (label.isEmpty || value.isEmpty) continue;
    fields.add(<String, dynamic>{'label': label, 'value': value});
  }
  return fields;
}

bool looksLikeEncodedPreviewData(String value) {
  return _looksLikeEncodedPreviewData(value);
}

bool _looksLikeEncodedPreviewData(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) return true;
  final lower = trimmed.toLowerCase();
  return lower.contains('ciphertext') ||
      lower.contains('schemaversion') ||
      lower.contains('vault_bundle') ||
      lower.contains('bytesbase64');
}

bool _isImageExtension(String extension) {
  return const <String>{
    'PNG',
    'JPG',
    'JPEG',
    'GIF',
    'WEBP',
    'BMP',
  }.contains(extension.toUpperCase());
}

bool _isTextExtension(String extension) {
  return const <String>{
    'TXT',
    'MD',
    'JSON',
    'CSV',
    'LOG',
    'XML',
    'YAML',
    'YML',
  }.contains(extension.toUpperCase());
}

bool _isPdfExtension(String extension) {
  return extension.toUpperCase() == 'PDF';
}

String _mimeTypeForExtension(String extension) {
  switch (extension.toUpperCase()) {
    case 'PNG':
      return 'image/png';
    case 'JPG':
    case 'JPEG':
      return 'image/jpeg';
    case 'GIF':
      return 'image/gif';
    case 'WEBP':
      return 'image/webp';
    case 'PDF':
      return 'application/pdf';
    case 'JSON':
      return 'application/json';
    case 'CSV':
      return 'text/csv';
    case 'TXT':
    case 'MD':
    case 'LOG':
    case 'YAML':
    case 'YML':
      return 'text/plain';
    case 'XML':
      return 'application/xml';
    default:
      return 'application/octet-stream';
  }
}

String formatDocumentByteCount(int bytes) {
  return _formatDocumentByteCount(bytes);
}

String _formatDocumentByteCount(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}

class SecretField {
  const SecretField({
    required this.key,
    required this.value,
    required this.sensitive,
  });

  final String key;
  final String value;
  final bool sensitive;
}
