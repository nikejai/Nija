part of 'vault_app_shell.dart';

class _DocumentDetailScreen extends StatefulWidget {
  const _DocumentDetailScreen({
    required this.item,
    required this.onReadDocument,
    required this.onShareEncryptedDocument,
    required this.onExportEncryptedDocument,
    required this.onSaveDocumentCopy,
    required this.customTypeDefinitions,
    required this.currentVaultSizeBytes,
    required this.maxVaultBytes,
    required this.maxDocumentBytes,
    required this.onAddAttachment,
    required this.onOpenAttachment,
    required this.onShareAttachment,
    required this.onShareEncryptedAttachment,
    required this.onExportEncryptedAttachment,
    required this.onSaveAttachmentCopy,
    required this.onDeleteAttachment,
    this.onLifecycleLockSuppressed,
    this.showDeleteAction = false,
    this.readOnly = false,
    this.onShareMenu,
  });

  final Map<String, dynamic> item;
  final ReadVaultDocument? onReadDocument;
  final Future<void> Function(Map<String, dynamic> item, List<int> bytes)
  onShareEncryptedDocument;
  final Future<void> Function(Map<String, dynamic> item, List<int> bytes)
  onExportEncryptedDocument;
  final Future<bool> Function(Map<String, dynamic> item, List<int> bytes)
  onSaveDocumentCopy;
  final List<Map<String, dynamic>> customTypeDefinitions;
  final int currentVaultSizeBytes;
  final int maxVaultBytes;
  final int maxDocumentBytes;
  final ValueChanged<bool>? onLifecycleLockSuppressed;
  final Future<Map<String, dynamic>?> Function(
    BuildContext context,
    Map<String, dynamic> item,
  )
  onAddAttachment;
  final Future<void> Function(Map<String, dynamic> attachment) onOpenAttachment;
  final Future<void> Function(Map<String, dynamic> attachment)
  onShareAttachment;
  final Future<void> Function(Map<String, dynamic> attachment)
  onShareEncryptedAttachment;
  final Future<void> Function(Map<String, dynamic> attachment)
  onExportEncryptedAttachment;
  final Future<bool> Function(Map<String, dynamic> attachment)
  onSaveAttachmentCopy;
  final Future<void> Function(
    Map<String, dynamic> item,
    Map<String, dynamic> attachment,
  )
  onDeleteAttachment;
  final bool showDeleteAction;
  final bool readOnly;
  final VoidCallback? onShareMenu;

  @override
  State<_DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<_DocumentDetailScreen> {
  List<int>? _documentBytes;
  Object? _documentLoadError;
  bool _isLoadingDocument = true;
  String _loadMessage = 'Decrypting document...';
  double _loadProgress = 0;
  bool _isPdfRendering = false;
  int _documentLoadToken = 0;
  late bool _isFavorite;
  final _textPreviewScrollController = ScrollController();
  final _textPreviewHorizontalScrollController = ScrollController();
  String _selectedDocumentId = _primaryDocumentId;
  int _busyCount = 0;
  String _busyMessage = 'Working...';
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.item['pinned'] == true;
    if (widget.readOnly) {
      _isLoadingDocument = false;
      return;
    }
    unawaited(_loadSelectedDocument());
  }

  @override
  void dispose() {
    _textPreviewScrollController.dispose();
    _textPreviewHorizontalScrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _primaryDocument {
    return {
      ...Map<String, dynamic>.from(widget.item),
      'id': _primaryDocumentId,
      '__primaryDocument__': true,
    };
  }

  List<Map<String, dynamic>> get _documents {
    return [_primaryDocument, ..._itemAttachments(widget.item)];
  }

  Map<String, dynamic> get _selectedDocument {
    for (final document in _documents) {
      if (_documentId(document) == _selectedDocumentId) return document;
    }
    return _primaryDocument;
  }

  Future<List<int>> _loadDocument(
    Map<String, dynamic> document, {
    VaultDocumentLoadProgress? onProgress,
  }) async {
    final sectionName = document['documentSection']?.toString().trim() ?? '';
    if (sectionName.isEmpty) {
      throw StateError('Document section is missing.');
    }
    final reader = widget.onReadDocument;
    if (reader == null) {
      throw StateError(
        'Document preview is unavailable in this vault session.',
      );
    }
    return reader(sectionName: sectionName, onProgress: onProgress);
  }

  Future<void> _loadSelectedDocument() async {
    final loadToken = ++_documentLoadToken;
    final document = _selectedDocument;
    final extension = _documentExtension(document);
    widget.onLifecycleLockSuppressed?.call(true);
    if (mounted) {
      setState(() {
        _isLoadingDocument = true;
        _documentLoadError = null;
        _documentBytes = null;
        _loadMessage = 'Decrypting document...';
        _loadProgress = 0;
        _isPdfRendering = false;
      });
    }
    try {
      final bytes = await _loadDocument(
        document,
        onProgress: (message, progress) {
          if (!mounted || loadToken != _documentLoadToken) return;
          setState(() {
            _loadMessage = message;
            _loadProgress = progress.clamp(0.0, 1.0);
          });
        },
      );
      if (!mounted || loadToken != _documentLoadToken) return;
      setState(() {
        _documentBytes = bytes;
        _isLoadingDocument = false;
        _isPdfRendering = _isPdfExtension(extension);
        _loadProgress = 1;
      });
    } catch (error) {
      if (!mounted || loadToken != _documentLoadToken) return;
      setState(() {
        _documentLoadError = error;
        _isLoadingDocument = false;
        _isPdfRendering = false;
      });
    } finally {
      widget.onLifecycleLockSuppressed?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = widget.item['title']?.toString() ?? 'Document';
    final selectedDocument = _selectedDocument;
    final extension = _documentExtension(selectedDocument);
    final fileName = _documentFileName(selectedDocument);
    final size = _formatDocumentSize(selectedDocument);

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
            if (widget.onShareMenu != null)
              IconButton(
                key: const ValueKey('document-detail-share-menu'),
                onPressed: _closing ? null : widget.onShareMenu,
                icon: const Icon(Icons.share_outlined),
                tooltip: AppStrings.shareEncryptedFile,
              ),
            if (!widget.readOnly) ...[
              IconButton(
                onPressed: _closing
                    ? null
                    : () => setState(() => _isFavorite = !_isFavorite),
                icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
                tooltip: 'Favorite',
              ),
              IconButton(
                onPressed: _closing ? null : _editDocumentItem,
                icon: const Icon(Icons.edit_outlined),
                tooltip: AppStrings.edit,
              ),
            ],
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
        body: Stack(
          children: [
            SafeArea(
              child: _closing
                  ? const SizedBox.expand()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final bytes = _documentBytes;
                        final isWide = constraints.maxWidth >= 860;
                        final edgePadding = isWide ? 28.0 : 16.0;
                        final previewPanel = _buildDocumentPreviewPanel(
                          context: context,
                          colorScheme: colorScheme,
                          extension: extension,
                          selectedDocument: selectedDocument,
                          bytes: bytes,
                        );
                        final infoSection = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DocumentHeader(
                              title: title,
                              fileName: fileName,
                              extension: extension,
                              size: size,
                            ),
                            const SizedBox(height: 10),
                            _EntryMetadataPanel(entry: widget.item),
                            const SizedBox(height: 10),
                            _DocumentFilesSection(
                              documents: _documents,
                              selectedDocumentId: _documentId(selectedDocument),
                              onAdd: () => _addAttachment(context),
                              onSelect: _selectDocument,
                              onAction: _showDocumentFileActions,
                            ),
                          ],
                        );
                        final actionSection = _buildDocumentActionButtons(
                          bytes: bytes,
                          selectedDocument: selectedDocument,
                          compact: isWide,
                        );

                        if (isWide) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 1120,
                                maxHeight: constraints.maxHeight,
                              ),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  edgePadding,
                                  10,
                                  edgePadding,
                                  16,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(flex: 7, child: previewPanel),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 3,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            infoSection,
                                            const SizedBox(height: 16),
                                            actionSection,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                edgePadding,
                                10,
                                edgePadding,
                                10,
                              ),
                              child: infoSection,
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  edgePadding,
                                  0,
                                  edgePadding,
                                  8,
                                ),
                                child: previewPanel,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                edgePadding,
                                8,
                                edgePadding,
                                16,
                              ),
                              child: actionSection,
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (_isLoadingDocument || _isPdfRendering)
              _DocumentPreviewLoadOverlay(
                message: _isLoadingDocument
                    ? _loadMessage
                    : 'Rendering PDF preview...',
                progress: _isLoadingDocument ? _loadProgress : null,
              ),
            if (_busyCount > 0) _VaultDetailBusyOverlay(message: _busyMessage),
          ],
        ),
      ),
    );
  }

  Future<T> _runWithBusy<T>(String message, Future<T> Function() action) async {
    if (mounted) {
      setState(() {
        _busyCount++;
        _busyMessage = message;
      });
    }
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() {
          _busyCount = (_busyCount - 1).clamp(0, 1 << 20);
          if (_busyCount == 0) _busyMessage = 'Working...';
        });
      }
    }
  }

  Widget _buildDocumentPreviewPanel({
    required BuildContext context,
    required ColorScheme colorScheme,
    required String extension,
    required Map<String, dynamic> selectedDocument,
    required List<int>? bytes,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildPreview(context, extension, selectedDocument),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _DocumentPreviewFullscreenButton(
                key: const ValueKey('document-detail-fullscreen'),
                onPressed: bytes == null || _isLoadingDocument
                    ? null
                    : () => _openFullscreenPreview(bytes, selectedDocument),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentActionButtons({
    required List<int>? bytes,
    required Map<String, dynamic> selectedDocument,
    required bool compact,
  }) {
    final openButton = FilledButton.icon(
      onPressed: bytes == null
          ? null
          : () => _openDocument(bytes, selectedDocument),
      icon: const Icon(Icons.open_in_new_outlined),
      label: const Text('Open with app'),
    );
    final saveButton = OutlinedButton.icon(
      key: const ValueKey('document-detail-save-copy'),
      onPressed: bytes == null
          ? null
          : () => _saveDocumentCopy(bytes, selectedDocument),
      icon: const Icon(Icons.download_for_offline_outlined),
      label: const Text('Save copy'),
    );
    final shareDecryptedButton = OutlinedButton.icon(
      onPressed: bytes == null
          ? null
          : () => _shareDecryptedDocument(bytes, selectedDocument),
      icon: const Icon(Icons.share_outlined),
      label: const Text('Share decrypted file'),
    );
    final shareEncryptedButton = OutlinedButton.icon(
      onPressed: bytes == null
          ? null
          : () => widget.onShareEncryptedDocument(selectedDocument, bytes),
      icon: const Icon(Icons.enhanced_encryption_outlined),
      label: const Text('Share encrypted'),
    );
    final exportEncryptedButton = OutlinedButton.icon(
      onPressed: bytes == null
          ? null
          : () => widget.onExportEncryptedDocument(selectedDocument, bytes),
      icon: const Icon(Icons.file_download_outlined),
      label: const Text('Export encrypted'),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          openButton,
          const SizedBox(height: 8),
          saveButton,
          const SizedBox(height: 8),
          shareDecryptedButton,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: shareEncryptedButton),
              const SizedBox(width: 8),
              Expanded(child: exportEncryptedButton),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: double.infinity, child: openButton),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: saveButton),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: shareDecryptedButton),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: shareEncryptedButton),
            const SizedBox(width: 8),
            Expanded(child: exportEncryptedButton),
          ],
        ),
      ],
    );
  }

  Widget _buildPreview(
    BuildContext context,
    String extension,
    Map<String, dynamic> document,
  ) {
    if (_isLoadingDocument) {
      return const SizedBox.shrink();
    }
    if (_documentLoadError != null) {
      return _DocumentPreviewMessage(
        icon: Icons.error_outline,
        title: 'Unable to preview document',
        subtitle: _documentLoadError.toString(),
      );
    }
    final bytes = _documentBytes ?? const <int>[];
    if (bytes.isEmpty) {
      if (widget.readOnly) {
        return const _DocumentPreviewMessage(
          icon: Icons.description_outlined,
          title: 'Sample document metadata',
          subtitle: 'Create a vault to store and preview real files.',
        );
      }
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
      return _ScrollableTextDocumentPreview(
        text: text,
        verticalController: _textPreviewScrollController,
        horizontalController: _textPreviewHorizontalScrollController,
      );
    }
    if (_isPdfExtension(extension)) {
      return _FocusableDocumentPreview(
        child: PdfViewer.data(
          Uint8List.fromList(bytes),
          sourceName: '${_documentId(document)}-${bytes.length}',
          params: _buildPdfViewerParams(
            onDocumentLoadFinished: (_, succeeded) {
              if (!mounted || !succeeded) return;
              setState(() => _isPdfRendering = false);
            },
          ),
        ),
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

  void _selectDocument(Map<String, dynamic> document) {
    final documentId = _documentId(document);
    if (documentId == _selectedDocumentId) return;
    setState(() => _selectedDocumentId = documentId);
    unawaited(_loadSelectedDocument());
  }

  Future<void> _openDocument(
    List<int> bytes,
    Map<String, dynamic> document,
  ) async {
    final fileName = _documentFileName(document);
    final mimeType = _mimeTypeForExtension(_documentExtension(document));
    await _runWithBusy('Opening document...', () async {
      try {
        await _VaultAppShellState._documentOpenChannel
            .invokeMethod<bool>('openDocument', <String, Object>{
              'fileName': fileName,
              'mimeType': mimeType,
              'bytes': Uint8List.fromList(bytes),
            });
      } on MissingPluginException {
        await _shareDocumentFallback(bytes, fileName, mimeType);
      } on PlatformException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'No app can open this file.'),
          ),
        );
        await _shareDocumentFallback(bytes, fileName, mimeType);
      }
    });
  }

  Future<void> _shareDecryptedDocument(
    List<int> bytes,
    Map<String, dynamic> document,
  ) async {
    final fileName = _documentFileName(document);
    await _runWithBusy('Preparing document share...', () {
      return _shareDocumentFallback(
        bytes,
        fileName,
        _mimeTypeForExtension(_documentExtension(document)),
      );
    });
  }

  Future<void> _saveDocumentCopy(
    List<int> bytes,
    Map<String, dynamic> document,
  ) async {
    try {
      final saved = await _runWithBusy(
        'Saving document copy...',
        () => widget.onSaveDocumentCopy(document, bytes),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Document copy saved.' : 'Document save cancelled.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save document copy.')),
      );
    }
  }

  Future<void> _openFullscreenPreview(
    List<int> bytes,
    Map<String, dynamic> document,
  ) {
    return _showFullscreenDocumentPreview(
      context: context,
      document: document,
      bytes: bytes,
      emptyOpenLabel: 'Open with app',
      onSaveCopy: () => widget.onSaveDocumentCopy(document, bytes),
      onExportEncrypted: () =>
          widget.onExportEncryptedDocument(document, bytes),
    );
  }

  Future<void> _editDocumentItem() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => AddVaultItemScreen(
          customTypeDefinitions: widget.customTypeDefinitions,
          initialItem: widget.item,
          currentVaultSizeBytes: widget.currentVaultSizeBytes,
          maxVaultBytes: widget.maxVaultBytes,
          maxDocumentBytes: widget.maxDocumentBytes,
          onLifecycleLockSuppressed: widget.onLifecycleLockSuppressed,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    if (_isFavorite != (widget.item['pinned'] == true)) {
      updated['pinned'] = _isFavorite;
    }
    await _closeWithResult(updated);
  }

  Future<void> _addAttachment(BuildContext context) async {
    try {
      final attachment = await _runWithBusy(
        'Saving attached document...',
        () => widget.onAddAttachment(context, widget.item),
      );
      if (attachment == null || !mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        this.context,
      ).showSnackBar(const SnackBar(content: Text('Document attached.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Unable to attach document.')),
      );
    }
  }

  Future<void> _showDocumentFileActions(
    BuildContext context,
    Map<String, dynamic> document,
  ) async {
    _selectDocument(document);
    if (document['__primaryDocument__'] == true) return;
    await _showAttachmentActions(context, document);
  }

  Future<void> _showAttachmentActions(
    BuildContext context,
    Map<String, dynamic> attachment,
  ) async {
    final selected = await showVaultChoiceMenu<String>(
      context: context,
      options: [
        VaultMenuOption(
          value: 'open',
          leading: const Icon(Icons.open_in_new_outlined),
          title: 'Open document',
        ),
        VaultMenuOption(
          value: 'share',
          leading: const Icon(Icons.share_outlined),
          title: 'Share file',
        ),
        VaultMenuOption(
          value: 'share_encrypted',
          leading: const Icon(Icons.enhanced_encryption_outlined),
          title: 'Share encrypted file',
        ),
        VaultMenuOption(
          value: 'export_encrypted',
          leading: const Icon(Icons.file_download_outlined),
          title: 'Export encrypted file',
        ),
        VaultMenuOption(
          value: 'save_copy',
          leading: const Icon(Icons.download_for_offline_outlined),
          title: 'Save copy',
        ),
        VaultMenuOption(
          value: 'delete',
          leading: const Icon(Icons.delete_outline),
          title: AppStrings.delete,
        ),
      ],
    );
    if (selected == null || !mounted) return;
    try {
      if (selected == 'open') {
        await _runWithBusy(
          'Opening document...',
          () => widget.onOpenAttachment(attachment),
        );
        return;
      }
      if (selected == 'share') {
        await _runWithBusy(
          'Preparing document share...',
          () => widget.onShareAttachment(attachment),
        );
        return;
      }
      if (selected == 'share_encrypted') {
        await _runWithBusy(
          'Preparing encrypted document...',
          () => widget.onShareEncryptedAttachment(attachment),
        );
        return;
      }
      if (selected == 'export_encrypted') {
        await _runWithBusy(
          'Exporting encrypted document...',
          () => widget.onExportEncryptedAttachment(attachment),
        );
        return;
      }
      if (selected == 'save_copy') {
        final saved = await _runWithBusy(
          'Saving document copy...',
          () => widget.onSaveAttachmentCopy(attachment),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              saved ? 'Document copy saved.' : 'Document save cancelled.',
            ),
          ),
        );
        return;
      }
      await _runWithBusy(
        'Removing attached document...',
        () => widget.onDeleteAttachment(widget.item, attachment),
      );
      if (!mounted) return;
      final attachmentId = attachment['id']?.toString();
      final attachments = _itemAttachments(widget.item)
        ..removeWhere((entry) => entry['id']?.toString() == attachmentId);
      setState(() {
        widget.item['attachments'] = attachments;
        if (_selectedDocumentId == _documentId(attachment)) {
          _selectedDocumentId = _primaryDocumentId;
        }
      });
      if (_selectedDocumentId == _primaryDocumentId) {
        unawaited(_loadSelectedDocument());
      }
      ScaffoldMessenger.of(
        this.context,
      ).showSnackBar(const SnackBar(content: Text('Attachment removed.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Unable to process attachment.')),
      );
    }
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

class _DocumentPreviewFullscreenButton extends StatelessWidget {
  const _DocumentPreviewFullscreenButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Enlarge preview',
        onPressed: onPressed,
        icon: const Icon(Icons.fullscreen_outlined),
      ),
    );
  }
}

Future<void> _showFullscreenDocumentPreview({
  required BuildContext context,
  required Map<String, dynamic> document,
  required List<int> bytes,
  required String emptyOpenLabel,
  Future<bool> Function()? onSaveCopy,
  Future<void> Function()? onExportEncrypted,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => _FullscreenDocumentPreviewScreen(
        document: document,
        bytes: bytes,
        emptyOpenLabel: emptyOpenLabel,
        onSaveCopy: onSaveCopy,
        onExportEncrypted: onExportEncrypted,
      ),
    ),
  );
}

class _FullscreenDocumentPreviewScreen extends StatefulWidget {
  const _FullscreenDocumentPreviewScreen({
    required this.document,
    required this.bytes,
    required this.emptyOpenLabel,
    this.onSaveCopy,
    this.onExportEncrypted,
  });

  final Map<String, dynamic> document;
  final List<int> bytes;
  final String emptyOpenLabel;
  final Future<bool> Function()? onSaveCopy;
  final Future<void> Function()? onExportEncrypted;

  @override
  State<_FullscreenDocumentPreviewScreen> createState() =>
      _FullscreenDocumentPreviewScreenState();
}

class _FullscreenDocumentPreviewScreenState
    extends State<_FullscreenDocumentPreviewScreen> {
  final _textPreviewScrollController = ScrollController();
  final _textPreviewHorizontalScrollController = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    _textPreviewScrollController.dispose();
    _textPreviewHorizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = _documentFileName(widget.document);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.onSaveCopy != null)
            IconButton(
              key: const ValueKey('document-fullscreen-save-copy'),
              tooltip: 'Save copy',
              onPressed: _busy ? null : _saveCopy,
              icon: const Icon(Icons.download_for_offline_outlined),
            ),
          if (widget.onExportEncrypted != null)
            IconButton(
              key: const ValueKey('document-fullscreen-export-encrypted'),
              tooltip: 'Export encrypted',
              onPressed: _busy ? null : _exportEncrypted,
              icon: const Icon(Icons.file_download_outlined),
            ),
          IconButton(
            key: const ValueKey('document-fullscreen-close'),
            tooltip: 'Close preview',
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.fullscreen_exit_outlined),
          ),
        ],
      ),
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: _buildFullscreenPreview(context),
              ),
            ),
            if (_busy) const _VaultDetailBusyOverlay(message: 'Working...'),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCopy() async {
    final action = widget.onSaveCopy;
    if (action == null) return;
    await _runAction(() async {
      final saved = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Document copy saved.' : 'Document save cancelled.',
          ),
        ),
      );
    });
  }

  Future<void> _exportEncrypted() async {
    final action = widget.onExportEncrypted;
    if (action == null) return;
    await _runAction(action);
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (mounted) setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to complete document action.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildFullscreenPreview(BuildContext context) {
    final bytes = widget.bytes;
    if (bytes.isEmpty) {
      return const _DocumentPreviewMessage(
        icon: Icons.insert_drive_file_outlined,
        title: 'Empty document',
        subtitle: 'There is no content to preview.',
      );
    }
    final extension = _documentExtension(widget.document);
    if (_isImageExtension(extension)) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Center(
          child: Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _DocumentPreviewMessage(
                  icon: Icons.broken_image_outlined,
                  title: 'Image preview failed',
                  subtitle:
                      'Use ${widget.emptyOpenLabel} to view this document.',
                ),
          ),
        ),
      );
    }
    if (_isTextExtension(extension)) {
      final text = utf8.decode(bytes, allowMalformed: true);
      return _ScrollableTextDocumentPreview(
        text: text,
        verticalController: _textPreviewScrollController,
        horizontalController: _textPreviewHorizontalScrollController,
      );
    }
    if (_isPdfExtension(extension)) {
      return _FocusableDocumentPreview(
        child: PdfViewer.data(
          Uint8List.fromList(bytes),
          sourceName:
              'fullscreen-${_documentId(widget.document)}-${bytes.length}',
          params: _buildPdfViewerParams(),
        ),
      );
    }
    return _DocumentPreviewMessage(
      icon: Icons.insert_drive_file_outlined,
      title: '$extension preview unavailable',
      subtitle: 'Use ${widget.emptyOpenLabel} to view this document.',
    );
  }
}

class _ScrollableTextDocumentPreview extends StatelessWidget {
  const _ScrollableTextDocumentPreview({
    required this.text,
    required this.verticalController,
    required this.horizontalController,
  });

  final String text;
  final ScrollController verticalController;
  final ScrollController horizontalController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Builder(
      builder: (context) {
        return Focus(
          autofocus: true,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => FocusScope.of(context).requestFocus(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                _dragScroll(verticalController, -details.delta.dy);
                _dragScroll(horizontalController, -details.delta.dx);
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: Scrollbar(
                  controller: verticalController,
                  thumbVisibility: true,
                  interactive: true,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.vertical,
                  child: SingleChildScrollView(
                    controller: verticalController,
                    primary: false,
                    child: Scrollbar(
                      controller: horizontalController,
                      thumbVisibility: true,
                      interactive: true,
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      notificationPredicate: (notification) =>
                          notification.metrics.axis == Axis.horizontal,
                      child: SingleChildScrollView(
                        controller: horizontalController,
                        primary: false,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(14),
                        child: SelectionArea(
                          child: Text(
                            text,
                            softWrap: false,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FocusableDocumentPreview extends StatelessWidget {
  const _FocusableDocumentPreview({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => FocusScope.of(context).requestFocus(),
        child: child,
      ),
    );
  }
}

class _DocumentPreviewInteractionBoundary extends StatelessWidget {
  const _DocumentPreviewInteractionBoundary({
    super.key,
    required this.child,
    required this.onInteractionChanged,
  });

  final Widget child;
  final ValueChanged<bool> onInteractionChanged;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onInteractionChanged(true),
      onPointerUp: (_) => onInteractionChanged(false),
      onPointerCancel: (_) => onInteractionChanged(false),
      child: child,
    );
  }
}

void _dragScroll(ScrollController controller, double delta) {
  if (!controller.hasClients || delta == 0) return;
  final position = controller.position;
  final next = (position.pixels + delta).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  if (next == position.pixels) return;
  controller.jumpTo(next);
}

class _DocumentFilesSection extends StatelessWidget {
  const _DocumentFilesSection({
    required this.documents,
    required this.selectedDocumentId,
    required this.onAdd,
    required this.onSelect,
    required this.onAction,
  });

  final List<Map<String, dynamic>> documents;
  final String selectedDocumentId;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final Future<void> Function(
    BuildContext context,
    Map<String, dynamic> document,
  )
  onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Documents',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('document-detail-add-document'),
                onPressed: onAdd,
                tooltip: 'Add document',
                icon: const Icon(Icons.attach_file),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...documents.map((document) {
            final documentId = _documentId(document);
            final selected = documentId == selectedDocumentId;
            final isPrimary = document['__primaryDocument__'] == true;
            return Material(
              color: Colors.transparent,
              child: ListTile(
                key: ValueKey('document-file-$documentId'),
                selected: selected,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.insert_drive_file_outlined,
                ),
                title: Text(
                  _documentFileName(document),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  isPrimary
                      ? 'Primary document · ${_formatDocumentSize(document)}'
                      : _formatDocumentSize(document),
                ),
                trailing: isPrimary
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.more_horiz),
                        onPressed: () => onAction(context, document),
                      ),
                onTap: () => onSelect(document),
              ),
            );
          }),
        ],
      ),
    );
  }
}

PdfViewerParams _buildPdfViewerParams({
  ValueChanged<bool>? onInteractionChanged,
  PdfDocumentLoadFinished? onDocumentLoadFinished,
}) {
  return PdfViewerParams(
    panAxis: PanAxis.free,
    scrollPhysics: const ClampingScrollPhysics(),
    onInteractionStart: (_) => onInteractionChanged?.call(true),
    onInteractionUpdate: (_) => onInteractionChanged?.call(true),
    onInteractionEnd: (_) => onInteractionChanged?.call(false),
    onDocumentLoadFinished: onDocumentLoadFinished,
    loadingBannerBuilder: _buildPdfLoadingBanner,
    errorBannerBuilder: _buildPdfErrorBanner,
  );
}

class _DocumentPreviewLoadOverlay extends StatelessWidget {
  const _DocumentPreviewLoadOverlay({required this.message, this.progress});

  final String message;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withValues(alpha: 0.32),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.8),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Large encrypted documents may take a moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

const _primaryDocumentId = '__primary_document__';

String _documentId(Map<String, dynamic> item) {
  final id = item['id']?.toString().trim();
  if (id != null && id.isNotEmpty) return id;
  final section = item['documentSection']?.toString().trim();
  if (section != null && section.isNotEmpty) return section;
  return _documentFileName(item);
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
