part of 'vault_app_shell.dart';

class _DocumentDetailScreen extends StatefulWidget {
  const _DocumentDetailScreen({
    required this.item,
    required this.onReadDocument,
    required this.onShareEncryptedDocument,
    required this.onExportEncryptedDocument,
    this.showDeleteAction = false,
  });

  final Map<String, dynamic> item;
  final ReadVaultDocument? onReadDocument;
  final Future<void> Function(Map<String, dynamic> item, List<int> bytes)
  onShareEncryptedDocument;
  final Future<void> Function(Map<String, dynamic> item, List<int> bytes)
  onExportEncryptedDocument;
  final bool showDeleteAction;

  @override
  State<_DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<_DocumentDetailScreen> {
  late Future<List<int>> _documentFuture;
  late bool _isFavorite;
  final _textPreviewScrollController = ScrollController();
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.item['pinned'] == true;
    _documentFuture = _loadDocument();
  }

  @override
  void dispose() {
    _textPreviewScrollController.dispose();
    super.dispose();
  }

  Future<List<int>> _loadDocument() async {
    final sectionName = widget.item['documentSection']?.toString().trim() ?? '';
    if (sectionName.isEmpty) {
      throw StateError('Document section is missing.');
    }
    final reader = widget.onReadDocument;
    if (reader == null) {
      throw StateError(
        'Document preview is unavailable in this vault session.',
      );
    }
    return reader(sectionName: sectionName);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = widget.item['title']?.toString() ?? 'Document';
    final extension = _documentExtension(widget.item);
    final fileName = _documentFileName(widget.item);
    final size = _formatDocumentSize(widget.item);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _closeWithUpdates();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            onPressed: _closing ? null : _closeWithUpdates,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              onPressed: _closing
                  ? null
                  : () => setState(() => _isFavorite = !_isFavorite),
              icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
              tooltip: 'Favorite',
            ),
            if (widget.showDeleteAction)
              IconButton(
                onPressed: _closing
                    ? null
                    : () => _closeWithResult(<String, dynamic>{
                        '__delete__': true,
                      }),
                icon: const Icon(Icons.delete_outline),
                tooltip: AppStrings.delete,
              ),
          ],
        ),
        body: SafeArea(
          child: _closing
              ? const SizedBox.expand()
              : FutureBuilder<List<int>>(
                  future: _documentFuture,
                  builder: (context, snapshot) {
                    final bytes = snapshot.data;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: Column(
                            children: [
                              _DocumentHeader(
                                title: title,
                                fileName: fileName,
                                extension: extension,
                                size: size,
                              ),
                              const SizedBox(height: 10),
                              _EntryMetadataPanel(entry: widget.item),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _buildPreview(
                                  context,
                                  snapshot,
                                  extension,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: bytes == null
                                      ? null
                                      : () => _openDocument(bytes),
                                  icon: const Icon(Icons.open_in_new_outlined),
                                  label: const Text('Open with app'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: bytes == null
                                      ? null
                                      : () => _shareDecryptedDocument(bytes),
                                  icon: const Icon(Icons.share_outlined),
                                  label: const Text('Share decrypted file'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: bytes == null
                                          ? null
                                          : () =>
                                                widget.onShareEncryptedDocument(
                                                  widget.item,
                                                  bytes,
                                                ),
                                      icon: const Icon(
                                        Icons.enhanced_encryption_outlined,
                                      ),
                                      label: const Text('Share encrypted'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: bytes == null
                                          ? null
                                          : () => widget
                                                .onExportEncryptedDocument(
                                                  widget.item,
                                                  bytes,
                                                ),
                                      icon: const Icon(
                                        Icons.file_download_outlined,
                                      ),
                                      label: const Text('Export encrypted'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildPreview(
    BuildContext context,
    AsyncSnapshot<List<int>> snapshot,
    String extension,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return _DocumentPreviewMessage(
        icon: Icons.error_outline,
        title: 'Unable to preview document',
        subtitle: snapshot.error.toString(),
      );
    }
    final bytes = snapshot.data ?? const <int>[];
    if (bytes.isEmpty) {
      return const _DocumentPreviewMessage(
        icon: Icons.insert_drive_file_outlined,
        title: 'Empty document',
        subtitle: 'There is no content to preview.',
      );
    }
    if (_isImageExtension(extension)) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const _DocumentPreviewMessage(
                  icon: Icons.broken_image_outlined,
                  title: 'Image preview failed',
                  subtitle: 'Use Open with... to view this document.',
                ),
          ),
        ),
      );
    }
    if (_isTextExtension(extension)) {
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
    if (_isPdfExtension(extension)) {
      return PdfViewer.data(
        Uint8List.fromList(bytes),
        sourceName:
            '${widget.item['id']?.toString() ?? _documentFileName(widget.item)}-${bytes.length}',
        params: _pdfViewerParams,
      );
    }
    return _DocumentPreviewMessage(
      icon: extension == 'PDF'
          ? Icons.picture_as_pdf_outlined
          : Icons.insert_drive_file_outlined,
      title: '$extension preview unavailable',
      subtitle: 'Use Open with... to view this document in another app.',
    );
  }

  Future<void> _openDocument(List<int> bytes) async {
    final fileName = _documentFileName(widget.item);
    final mimeType = _mimeTypeForExtension(_documentExtension(widget.item));
    try {
      await _VaultAppShellState._documentOpenChannel.invokeMethod<bool>(
        'openDocument',
        <String, Object>{
          'fileName': fileName,
          'mimeType': mimeType,
          'bytes': Uint8List.fromList(bytes),
        },
      );
    } on MissingPluginException {
      await _shareDocumentFallback(bytes, fileName, mimeType);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'No app can open this file.')),
      );
      await _shareDocumentFallback(bytes, fileName, mimeType);
    }
  }

  Future<void> _shareDecryptedDocument(List<int> bytes) async {
    final fileName = _documentFileName(widget.item);
    await _shareDocumentFallback(
      bytes,
      fileName,
      _mimeTypeForExtension(_documentExtension(widget.item)),
    );
  }

  Future<void> _shareDocumentFallback(
    List<int> bytes,
    String fileName,
    String mimeType,
  ) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(bytes),
            name: fileName,
            mimeType: mimeType,
          ),
        ],
      ),
    );
  }

  Future<void> _closeWithUpdates() async {
    final pinnedWas = widget.item['pinned'] == true;
    if (pinnedWas == _isFavorite) {
      await _closeWithResult(null);
      return;
    }
    await _closeWithResult(<String, dynamic>{
      ...widget.item,
      'pinned': _isFavorite,
    });
  }

  Future<void> _closeWithResult(Map<String, dynamic>? result) async {
    if (_closing) return;
    setState(() => _closing = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }
}

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({
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

class _DocumentPreviewMessage extends StatelessWidget {
  const _DocumentPreviewMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.onSurfaceVariant, size: 42),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

const PdfViewerParams _pdfViewerParams = PdfViewerParams(
  loadingBannerBuilder: _buildPdfLoadingBanner,
  errorBannerBuilder: _buildPdfErrorBanner,
);

Widget _buildPdfLoadingBanner(
  BuildContext context,
  int bytesDownloaded,
  int? totalBytes,
) {
  final progress = totalBytes == null || totalBytes <= 0
      ? null
      : bytesDownloaded / totalBytes;
  return _PdfStatusBanner(
    icon: Icons.picture_as_pdf_outlined,
    title: 'Loading PDF...',
    subtitle: totalBytes == null
        ? 'Preparing preview'
        : '${_formatDocumentSizeBytes(bytesDownloaded)} of ${_formatDocumentSizeBytes(totalBytes)}',
    progress: progress,
  );
}

Widget _buildPdfErrorBanner(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
  PdfDocumentRef documentRef,
) {
  return const _PdfStatusBanner(
    icon: Icons.error_outline,
    title: 'PDF preview failed',
    subtitle: 'Use Open with app to view this document.',
  );
}

class _PdfStatusBanner extends StatelessWidget {
  const _PdfStatusBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.progress,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: colorScheme.primary, size: 30),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _documentExtension(Map<String, dynamic> item) {
  final extension = item['documentExtension']?.toString().trim();
  if (extension != null && extension.isNotEmpty) {
    return extension.toUpperCase();
  }
  final fileName = _documentFileName(item);
  final dot = fileName.lastIndexOf('.');
  if (dot == -1 || dot == fileName.length - 1) return 'FILE';
  return fileName.substring(dot + 1).toUpperCase();
}

String _documentFileName(Map<String, dynamic> item) {
  final fileName = item['documentFileName']?.toString().trim();
  if (fileName != null && fileName.isNotEmpty) return fileName;
  final title = item['title']?.toString().trim();
  if (title != null && title.isNotEmpty) return title;
  return 'document';
}

String _documentSuggestedBaseName(Map<String, dynamic> item) {
  final fileName = _documentFileName(item);
  final dot = fileName.lastIndexOf('.');
  final base = dot <= 0 ? fileName : fileName.substring(0, dot);
  return base.trim().isEmpty ? 'document' : base.trim();
}

String _documentEncryptedPayload(Map<String, dynamic> item, List<int> bytes) {
  return jsonEncode(<String, dynamic>{
    'kind': 'document',
    'entry': _portableDocumentEntry(item),
    'title': item['title']?.toString() ?? 'Document',
    'fileName': _documentFileName(item),
    'extension': _documentExtension(item),
    'mimeType': _mimeTypeForExtension(_documentExtension(item)),
    'sizeBytes': bytes.length,
    'createdAt': item['createdAt']?.toString(),
    'updatedAt': item['updatedAt']?.toString(),
    'deviceId': item['deviceId']?.toString(),
    'updatedByDevice': item['updatedByDevice']?.toString(),
    'bytesBase64': base64Encode(bytes),
  });
}

Map<String, dynamic> _portableDocumentEntry(Map<String, dynamic> item) {
  final entry = Map<String, dynamic>.from(item)
    ..remove('documentSection')
    ..remove('documentStorage')
    ..remove('__documentBytes__');
  return entry;
}

String _formatDocumentSize(Map<String, dynamic> item) {
  final raw = item['documentSizeBytes'];
  final bytes = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
  return _formatDocumentSizeBytes(bytes);
}

String _formatDocumentSizeBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
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
