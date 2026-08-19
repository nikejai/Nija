part of 'vault_app_shell.dart';

class _ItemDetailScreen extends StatefulWidget {
  const _ItemDetailScreen({
    required this.item,
    required this.onCopy,
    required this.onShareSecurely,
    required this.onAddAttachment,
    required this.onReadAttachment,
    required this.onOpenAttachment,
    required this.onShareAttachment,
    required this.onShareEncryptedAttachment,
    required this.onExportEncryptedAttachment,
    required this.onSaveAttachmentCopy,
    required this.onDeleteAttachment,
    required this.customTypeDefinitions,
    required this.currentVaultSizeBytes,
    required this.maxVaultBytes,
    required this.maxDocumentBytes,
    this.onLifecycleLockSuppressed,
    this.showDeleteAction = false,
    this.readOnly = false,
    this.onShareMenu,
  });

  final Map<String, dynamic> item;
  final ValueChanged<String> onCopy;
  final Future<void> Function() onShareSecurely;
  final Future<Map<String, dynamic>?> Function(
    BuildContext context,
    Map<String, dynamic> item,
  )
  onAddAttachment;
  final Future<List<int>> Function(Map<String, dynamic> attachment)
  onReadAttachment;
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
  final List<Map<String, dynamic>> customTypeDefinitions;
  final int currentVaultSizeBytes;
  final int maxVaultBytes;
  final int maxDocumentBytes;
  final ValueChanged<bool>? onLifecycleLockSuppressed;
  final bool showDeleteAction;
  final bool readOnly;
  final VoidCallback? onShareMenu;

  @override
  State<_ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<_ItemDetailScreen> {
  final Set<int> _revealedIndexes = <int>{};
  final _attachmentPreviewKey = GlobalKey();
  final _attachmentPreviewScrollController = ScrollController();
  final _attachmentPreviewHorizontalScrollController = ScrollController();
  late bool _isFavorite;
  String? _selectedAttachmentId;
  Future<List<int>>? _attachmentPreviewFuture;
  int _busyCount = 0;
  String _busyMessage = 'Working...';
  bool _attachmentPreviewInteracting = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.item['pinned'] == true;
    _selectInitialAttachment();
  }

  @override
  void dispose() {
    _attachmentPreviewScrollController.dispose();
    _attachmentPreviewHorizontalScrollController.dispose();
    super.dispose();
  }

  void _setAttachmentPreviewInteracting(bool interacting) {
    if (!mounted || _attachmentPreviewInteracting == interacting) return;
    setState(() => _attachmentPreviewInteracting = interacting);
  }

  bool _isPointerInsideAttachmentPreview(Offset globalPosition) {
    final context = _attachmentPreviewKey.currentContext;
    if (context == null) return false;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return (topLeft & renderObject.size).contains(globalPosition);
  }

  void _selectInitialAttachment() {
    final attachments = _itemAttachments(widget.item);
    if (attachments.isEmpty) return;
    final attachment = attachments.first;
    _selectedAttachmentId = _documentId(attachment);
    _attachmentPreviewFuture = widget.onReadAttachment(attachment);
  }

  Map<String, dynamic>? _customTypeDefinitionForType(String type) {
    final normalized = type.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final definition in widget.customTypeDefinitions) {
      final name = definition['name']?.toString().trim().toLowerCase();
      if (name == normalized) return definition;
    }
    return null;
  }

  IconData _iconForItemType(String type) {
    final iconKey = _customTypeDefinitionForType(type)?['iconKey']?.toString();
    if (iconKey != null) return _iconForCustomTemplateKey(iconKey);
    return _iconForHomeType(type);
  }

  Color _colorForItemType(String type) {
    final colorKey = _customTypeDefinitionForType(
      type,
    )?['colorKey']?.toString();
    if (colorKey != null) return _colorForCustomTemplateColorKey(colorKey);
    return _colorForHomeType(type);
  }

  @override
  Widget build(BuildContext context) {
    final fields = _visibleItemFields(
      (widget.item['fields'] as List<dynamic>? ?? const [])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList(),
      widget.item['title']?.toString() ?? '',
    );
    final itemType = widget.item['type']?.toString() ?? 'Item';
    final title = widget.item['title']?.toString() ?? 'Untitled';
    final created = _entryCreatedLabel(widget.item);
    final modified = _entryModifiedLabel(widget.item);
    final device = _entryDeviceLabel(widget.item);
    final lastAccessed = _formatLastAccessedAt(
      widget.item['lastAccessedAt']?.toString(),
    );
    final typeIcon = _iconForItemType(itemType);
    final typeColor = _colorForItemType(itemType);
    final idPhotos = _identityPhotos(widget.item);
    final attachments = _itemAttachments(widget.item);
    final primaryAction = _primaryActionForItemType(
      itemType: itemType,
      fields: fields,
      selectedAttachment: _selectedAttachment(),
    );
    final metadataRows = [
      _DetailMetadataRow('Category', itemType),
      _DetailMetadataRow('Created', created),
      _DetailMetadataRow('Modified', modified),
      _DetailMetadataRow('Device', device),
      _DetailMetadataRow('Last accessed', lastAccessed),
    ].where((row) => _hasMeaningfulValue(row.value)).toList();

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
            onPressed: _closeWithUpdates,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(itemType, maxLines: 1, overflow: TextOverflow.ellipsis),
          titleSpacing: 0,
          actions: [
            if (widget.onShareMenu != null)
              IconButton(
                key: const ValueKey('item-detail-share-menu'),
                onPressed: widget.onShareMenu,
                icon: const Icon(Icons.share_outlined),
                tooltip: AppStrings.shareEncryptedFile,
              ),
            if (!widget.readOnly) ...[
              IconButton(
                onPressed: () => setState(() => _isFavorite = !_isFavorite),
                icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
                tooltip: 'Favorite',
              ),
              IconButton(
                onPressed: _editItem,
                icon: const Icon(Icons.edit_outlined),
                tooltip: AppStrings.edit,
              ),
            ],
            if (widget.showDeleteAction)
              IconButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(<String, dynamic>{'__delete__': true}),
                icon: const Icon(Icons.delete_outline),
                tooltip: AppStrings.delete,
              ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  if (_isPointerInsideAttachmentPreview(event.position)) {
                    _setAttachmentPreviewInteracting(true);
                  }
                },
                onPointerUp: (_) => _setAttachmentPreviewInteracting(false),
                onPointerCancel: (_) => _setAttachmentPreviewInteracting(false),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 860;
                    final mainPanel = _ItemMainContentPanel(
                      fields: fields,
                      revealedIndexes: _revealedIndexes,
                      onToggleReveal: _toggleFieldReveal,
                      onCopy: widget.onCopy,
                      emptyLabel: 'No saved fields for this item.',
                      children: [
                        if (idPhotos.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _IdentityPhotosSection(photos: idPhotos),
                        ],
                        const SizedBox(height: 14),
                        _ItemAttachmentsSection(
                          attachments: attachments,
                          selectedAttachmentId: _selectedAttachmentId,
                          onAdd: () => _addAttachment(context),
                          onSelect: _selectAttachment,
                          onAction: (attachment) =>
                              _showAttachmentActions(context, attachment),
                        ),
                        if (_attachmentPreviewFuture != null) ...[
                          const SizedBox(height: 14),
                          _buildAttachmentPreviewPanel(),
                        ],
                      ],
                    );
                    final sidePanel = _ItemDetailSidePanel(
                      metadataRows: metadataRows,
                      primaryAction: primaryAction,
                      onPrimaryCopy: widget.onCopy,
                      onPrimaryOpenAttachment: widget.onOpenAttachment,
                      onShareSecurely: widget.onShareSecurely,
                    );
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: ListView(
                          key: const ValueKey('item-detail-scroll-view'),
                          physics: _attachmentPreviewInteracting
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          padding: EdgeInsets.fromLTRB(
                            isWide ? 28 : 16,
                            18,
                            isWide ? 28 : 16,
                            24,
                          ),
                          children: [
                            _ItemDetailHero(
                              itemType: itemType,
                              title: title,
                              icon: typeIcon,
                              color: typeColor,
                            ),
                            const SizedBox(height: 22),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 7, child: mainPanel),
                                  const SizedBox(width: 20),
                                  Expanded(flex: 3, child: sidePanel),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  mainPanel,
                                  const SizedBox(height: 14),
                                  sidePanel,
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_busyCount > 0) _VaultDetailBusyOverlay(message: _busyMessage),
          ],
        ),
      ),
    );
  }

  Future<void> _editItem() async {
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
    Navigator.of(context).pop(updated);
  }

  void _toggleFieldReveal(int index) {
    setState(() {
      if (_revealedIndexes.contains(index)) {
        _revealedIndexes.remove(index);
      } else {
        _revealedIndexes.add(index);
      }
    });
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

  List<Map<String, dynamic>> _identityPhotos(Map<String, dynamic> item) {
    final type = item['type']?.toString().trim().toLowerCase() ?? '';
    if (type != 'identity') return const <Map<String, dynamic>>[];
    return (item['idPhotos'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where(
          (entry) => (entry['bytesBase64']?.toString() ?? '').trim().isNotEmpty,
        )
        .toList();
  }

  String _formatLastAccessedAt(String? value) {
    if (value == null || value.trim().isEmpty) return 'Never';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  void _closeWithUpdates() {
    final pinnedWas = widget.item['pinned'] == true;
    if (pinnedWas == _isFavorite) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(
      context,
    ).pop(<String, dynamic>{...widget.item, 'pinned': _isFavorite});
  }

  Future<void> _addAttachment(BuildContext context) async {
    try {
      final attachment = await _runWithBusy(
        'Saving attached document...',
        () => widget.onAddAttachment(context, widget.item),
      );
      if (attachment == null || !mounted) return;
      setState(() {
        _attachmentPreviewInteracting = false;
        _selectedAttachmentId = _documentId(attachment);
        _attachmentPreviewFuture = widget.onReadAttachment(attachment);
      });
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

  void _selectAttachment(Map<String, dynamic> attachment) {
    final attachmentId = _documentId(attachment);
    if (attachmentId == _selectedAttachmentId) return;
    setState(() {
      _attachmentPreviewInteracting = false;
      _selectedAttachmentId = attachmentId;
      _attachmentPreviewFuture = widget.onReadAttachment(attachment);
    });
  }

  Widget _buildAttachmentPreviewPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedAttachment = _selectedAttachment();
    final extension = selectedAttachment == null
        ? 'FILE'
        : _documentExtension(selectedAttachment);
    return _DocumentPreviewInteractionBoundary(
      key: const ValueKey('attachment-preview-interaction-boundary'),
      onInteractionChanged: _setAttachmentPreviewInteracting,
      child: KeyedSubtree(
        key: const ValueKey('attachment-preview-panel'),
        child: Container(
          key: _attachmentPreviewKey,
          height: 260,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<List<int>>(
            future: _attachmentPreviewFuture,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              return Stack(
                children: [
                  Positioned.fill(
                    child: _buildAttachmentPreview(
                      snapshot,
                      extension,
                      selectedAttachment,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _DocumentPreviewFullscreenButton(
                      key: const ValueKey('attachment-preview-fullscreen'),
                      onPressed: bytes == null || selectedAttachment == null
                          ? null
                          : () => _openAttachmentFullscreenPreview(
                              bytes,
                              selectedAttachment,
                            ),
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

  Map<String, dynamic>? _selectedAttachment() {
    final selectedId = _selectedAttachmentId;
    if (selectedId == null) return null;
    for (final attachment in _itemAttachments(widget.item)) {
      if (_documentId(attachment) == selectedId) return attachment;
    }
    return null;
  }

  Widget _buildAttachmentPreview(
    AsyncSnapshot<List<int>> snapshot,
    String extension,
    Map<String, dynamic>? attachment,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError || attachment == null) {
      return _DocumentPreviewMessage(
        icon: Icons.error_outline,
        title: 'Unable to preview document',
        subtitle: snapshot.error?.toString() ?? 'Document unavailable.',
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
                  subtitle: 'Use Open document to view this file.',
                ),
          ),
        ),
      );
    }
    if (_isTextExtension(extension)) {
      final text = utf8.decode(bytes, allowMalformed: true);
      return _ScrollableTextDocumentPreview(
        text: text,
        verticalController: _attachmentPreviewScrollController,
        horizontalController: _attachmentPreviewHorizontalScrollController,
      );
    }
    if (_isPdfExtension(extension)) {
      return _FocusableDocumentPreview(
        child: PdfViewer.data(
          Uint8List.fromList(bytes),
          sourceName: '${_documentId(attachment)}-${bytes.length}',
          params: _buildPdfViewerParams(
            onInteractionChanged: _setAttachmentPreviewInteracting,
          ),
        ),
      );
    }
    return _DocumentPreviewMessage(
      icon: extension == 'PDF'
          ? Icons.picture_as_pdf_outlined
          : Icons.insert_drive_file_outlined,
      title: '$extension preview unavailable',
      subtitle: 'Use Open document to view this file in another app.',
    );
  }

  Future<void> _openAttachmentFullscreenPreview(
    List<int> bytes,
    Map<String, dynamic> attachment,
  ) {
    return _showFullscreenDocumentPreview(
      context: context,
      document: attachment,
      bytes: bytes,
      emptyOpenLabel: 'Open document',
      onSaveCopy: () => widget.onSaveAttachmentCopy(attachment),
      onExportEncrypted: () => widget.onExportEncryptedAttachment(attachment),
    );
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
        _attachmentPreviewInteracting = false;
        widget.item['attachments'] = attachments;
        if (_selectedAttachmentId == _documentId(attachment)) {
          if (attachments.isEmpty) {
            _selectedAttachmentId = null;
            _attachmentPreviewFuture = null;
          } else {
            final nextAttachment = attachments.first;
            _selectedAttachmentId = _documentId(nextAttachment);
            _attachmentPreviewFuture = widget.onReadAttachment(nextAttachment);
          }
        }
      });
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
}

class _DisplayItemField {
  const _DisplayItemField({
    required this.originalIndex,
    required this.label,
    required this.value,
    required this.sensitive,
  });

  final int originalIndex;
  final String label;
  final String value;
  final bool sensitive;
}

class _DetailMetadataRow {
  const _DetailMetadataRow(this.label, this.value);

  final String label;
  final String value;
}

class _ItemPrimaryActionSpec {
  const _ItemPrimaryActionSpec({
    required this.label,
    required this.icon,
    required this.labelMatchers,
    this.opensAttachment = false,
    this.preferSensitiveFallback = false,
  });

  final String label;
  final IconData icon;
  final List<String> labelMatchers;
  final bool opensAttachment;
  final bool preferSensitiveFallback;
}

class _ItemDetailPrimaryAction {
  const _ItemDetailPrimaryAction({
    required this.label,
    required this.icon,
    this.value,
    this.attachment,
  });

  final String label;
  final IconData icon;
  final String? value;
  final Map<String, dynamic>? attachment;

  bool get enabled => _hasMeaningfulValue(value) || attachment != null;
}

List<_DisplayItemField> _visibleItemFields(
  List<Map<String, dynamic>> fields,
  String title,
) {
  final normalizedTitle = title.trim().toLowerCase();
  final visible = <_DisplayItemField>[];
  for (var i = 0; i < fields.length; i++) {
    final field = fields[i];
    final label = field['label']?.toString().trim() ?? 'Field';
    final value = field['value']?.toString().trim() ?? '';
    if (!_hasMeaningfulValue(value)) continue;
    if (label.toLowerCase() == 'title' &&
        value.toLowerCase() == normalizedTitle) {
      continue;
    }
    visible.add(
      _DisplayItemField(
        originalIndex: i,
        label: label,
        value: value,
        sensitive: field['sensitive'] == true,
      ),
    );
  }
  return visible;
}

bool _hasMeaningfulValue(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isNotEmpty && normalized != '-' && normalized != '—';
}

_ItemPrimaryActionSpec _getPrimaryActionForItemType(String type) {
  final normalized = type.trim().toLowerCase();
  if (normalized.contains('document')) {
    return const _ItemPrimaryActionSpec(
      label: 'Open document',
      icon: Icons.open_in_new_outlined,
      labelMatchers: [],
      opensAttachment: true,
    );
  }
  if (normalized.contains('ssh')) {
    return const _ItemPrimaryActionSpec(
      label: 'Copy public key',
      icon: Icons.copy,
      labelMatchers: ['public key', 'ssh key'],
    );
  }
  if (normalized.contains('bank')) {
    return const _ItemPrimaryActionSpec(
      label: 'Copy account number',
      icon: Icons.copy,
      labelMatchers: ['account number', 'account no', 'iban'],
    );
  }
  if (normalized.contains('card')) {
    return const _ItemPrimaryActionSpec(
      label: 'Copy card number',
      icon: Icons.copy,
      labelMatchers: ['card number'],
    );
  }
  if (normalized.contains('driver') || normalized.contains('license')) {
    return const _ItemPrimaryActionSpec(
      label: 'Copy license number',
      icon: Icons.copy,
      labelMatchers: ['license number', 'licence number', 'document number'],
      preferSensitiveFallback: true,
    );
  }
  if (normalized.contains('passport')) {
    return const _ItemPrimaryActionSpec(
      label: 'Copy passport number',
      icon: Icons.copy,
      labelMatchers: ['passport number', 'document number'],
      preferSensitiveFallback: true,
    );
  }
  if (normalized.contains('identity')) {
    return const _ItemPrimaryActionSpec(
      label: 'Copy document number',
      icon: Icons.copy,
      labelMatchers: [
        'document number',
        'id number',
        'identity number',
        'passport number',
        'license number',
      ],
      preferSensitiveFallback: true,
    );
  }
  if (normalized.contains('note')) {
    return const _ItemPrimaryActionSpec(
      label: 'Copy note',
      icon: Icons.copy,
      labelMatchers: ['note', 'notes'],
    );
  }
  if (normalized.contains('password') || normalized.contains('login')) {
    return const _ItemPrimaryActionSpec(
      label: 'Copy password',
      icon: Icons.copy,
      labelMatchers: ['password', 'passcode'],
      preferSensitiveFallback: true,
    );
  }
  return const _ItemPrimaryActionSpec(
    label: 'Copy value',
    icon: Icons.copy,
    labelMatchers: [],
    preferSensitiveFallback: true,
  );
}

_ItemDetailPrimaryAction _primaryActionForItemType({
  required String itemType,
  required List<_DisplayItemField> fields,
  required Map<String, dynamic>? selectedAttachment,
}) {
  final spec = _getPrimaryActionForItemType(itemType);
  if (spec.opensAttachment) {
    return _ItemDetailPrimaryAction(
      label: spec.label,
      icon: spec.icon,
      attachment: selectedAttachment,
    );
  }
  final matched = _findPrimaryActionField(spec, fields);
  return _ItemDetailPrimaryAction(
    label: spec.label,
    icon: spec.icon,
    value: matched?.value,
  );
}

_DisplayItemField? _findPrimaryActionField(
  _ItemPrimaryActionSpec spec,
  List<_DisplayItemField> fields,
) {
  for (final matcher in spec.labelMatchers) {
    final normalizedMatcher = matcher.toLowerCase();
    for (final field in fields) {
      if (field.label.toLowerCase().contains(normalizedMatcher)) {
        return field;
      }
    }
  }
  if (spec.preferSensitiveFallback) {
    for (final field in fields) {
      if (field.sensitive) return field;
    }
  }
  return fields.isEmpty ? null : fields.first;
}

class _ItemDetailHero extends StatelessWidget {
  const _ItemDetailHero({
    required this.itemType,
    required this.title,
    required this.icon,
    required this.color,
  });

  final String itemType;
  final String title;
  final IconData icon;
  final Color color;

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
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 12),
        Text(
          itemType,
          textAlign: TextAlign.center,
          style: vaultPageHeadingStyle(context),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ItemMainContentPanel extends StatelessWidget {
  const _ItemMainContentPanel({
    required this.fields,
    required this.revealedIndexes,
    required this.onToggleReveal,
    required this.onCopy,
    required this.emptyLabel,
    required this.children,
  });

  final List<_DisplayItemField> fields;
  final Set<int> revealedIndexes;
  final ValueChanged<int> onToggleReveal;
  final ValueChanged<String> onCopy;
  final String emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fields.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                emptyLabel,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          else
            ...fields.asMap().entries.map((entry) {
              final index = entry.key;
              final field = entry.value;
              return _ItemDetailFieldRow(
                field: field,
                showTopDivider: index > 0,
                revealed: revealedIndexes.contains(field.originalIndex),
                onToggleReveal: () => onToggleReveal(field.originalIndex),
                onCopy: () => onCopy(field.value),
              );
            }),
          if (children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemDetailFieldRow extends StatelessWidget {
  const _ItemDetailFieldRow({
    required this.field,
    required this.showTopDivider,
    required this.revealed,
    required this.onToggleReveal,
    required this.onCopy,
  });

  final _DisplayItemField field;
  final bool showTopDivider;
  final bool revealed;
  final VoidCallback onToggleReveal;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayValue = field.sensitive && !revealed
        ? _maskedValue(field.value)
        : field.value;
    return Column(
      children: [
        if (showTopDivider)
          Divider(height: 1, thickness: 0.6, color: colorScheme.outlineVariant),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.label.toUpperCase(),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      displayValue,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (field.sensitive)
                IconButton(
                  icon: Icon(
                    revealed ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  tooltip: revealed ? 'Hide' : 'Reveal',
                  onPressed: onToggleReveal,
                ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy',
                onPressed: onCopy,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _maskedValue(String value) {
  if (value.isEmpty) return '';
  return '••••••••';
}

class _ItemDetailSidePanel extends StatelessWidget {
  const _ItemDetailSidePanel({
    required this.metadataRows,
    required this.primaryAction,
    required this.onPrimaryCopy,
    required this.onPrimaryOpenAttachment,
    required this.onShareSecurely,
  });

  final List<_DetailMetadataRow> metadataRows;
  final _ItemDetailPrimaryAction primaryAction;
  final ValueChanged<String> onPrimaryCopy;
  final Future<void> Function(Map<String, dynamic> attachment)
  onPrimaryOpenAttachment;
  final Future<void> Function() onShareSecurely;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ITEM DETAILS',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...metadataRows.map((row) => _SideMetadataLine(row: row)),
          const SizedBox(height: 18),
          Divider(color: colorScheme.outlineVariant),
          const SizedBox(height: 14),
          Text(
            'QUICK ACTIONS',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: primaryAction.enabled
                  ? () {
                      final attachment = primaryAction.attachment;
                      if (attachment != null) {
                        unawaited(onPrimaryOpenAttachment(attachment));
                        return;
                      }
                      final value = primaryAction.value;
                      if (value != null) onPrimaryCopy(value);
                    }
                  : null,
              icon: Icon(primaryAction.icon, size: 18),
              label: Text(primaryAction.label),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => unawaited(onShareSecurely()),
              icon: const Icon(Icons.enhanced_encryption_outlined, size: 18),
              label: const Text('Share securely'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideMetadataLine extends StatelessWidget {
  const _SideMetadataLine({required this.row});

  final _DetailMetadataRow row;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            row.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemAttachmentsSection extends StatelessWidget {
  const _ItemAttachmentsSection({
    required this.attachments,
    required this.selectedAttachmentId,
    required this.onAdd,
    required this.onSelect,
    required this.onAction,
  });

  final List<Map<String, dynamic>> attachments;
  final String? selectedAttachmentId;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final ValueChanged<Map<String, dynamic>> onAction;

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
                  'Attachments',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('item-add-attachment'),
                onPressed: onAdd,
                icon: const Icon(Icons.attach_file),
                label: const Text('Add document'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (attachments.isEmpty)
            Text(
              'No documents attached',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            )
          else
            ...attachments.map((attachment) {
              final attachmentId = _documentId(attachment);
              final selected = attachmentId == selectedAttachmentId;
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  key: ValueKey(
                    'item-attachment-${attachment['id']?.toString() ?? _documentFileName(attachment)}',
                  ),
                  selected: selected,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.insert_drive_file_outlined,
                  ),
                  title: Text(
                    _documentFileName(attachment),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_formatDocumentSize(attachment)),
                  trailing: IconButton(
                    key: ValueKey('item-attachment-actions-$attachmentId'),
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () => onAction(attachment),
                  ),
                  onTap: () => onSelect(attachment),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _VaultDetailBusyOverlay extends StatelessWidget {
  const _VaultDetailBusyOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withValues(alpha: 0.25),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.6),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Large encrypted files may take a moment.',
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

List<Map<String, dynamic>> _itemAttachments(Map<String, dynamic> item) {
  return (item['attachments'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .where((entry) {
        final section = entry['documentSection']?.toString().trim() ?? '';
        final fileName = entry['documentFileName']?.toString().trim() ?? '';
        return section.isNotEmpty || fileName.isNotEmpty;
      })
      .toList();
}

class _IdentityPhotosSection extends StatelessWidget {
  const _IdentityPhotosSection({required this.photos});

  final List<Map<String, dynamic>> photos;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ID photos',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...photos.asMap().entries.map((entry) {
            final index = entry.key;
            final photo = entry.value;
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
              child: InkWell(
                key: ValueKey('identity-photo-row-$index'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showPhotoPicker(context, initialIndex: index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _IdentityPhotoPreview(photo: photo),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              photo['name']?.toString() ??
                                  'ID photo ${index + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatIdentityPhotoSize(photo['sizeBytes']),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.open_in_full,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showPhotoPicker(
    BuildContext context, {
    required int initialIndex,
  }) async {
    final selectedIndex = await showVaultSurfaceSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Choose photo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ...photos.asMap().entries.map((entry) {
              final index = entry.key;
              final photo = entry.value;
              return ListTile(
                key: ValueKey('identity-photo-picker-$index'),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _IdentityPhotoPreview(photo: photo, size: 44),
                ),
                title: Text(
                  photo['name']?.toString() ?? 'ID photo ${index + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_formatIdentityPhotoSize(photo['sizeBytes'])),
                selected: index == initialIndex,
                onTap: () => Navigator.of(context).pop(index),
              );
            }),
          ],
        ),
      ),
    );
    if (selectedIndex == null || !context.mounted) return;
    await _showFullPhotoViewer(context, photos[selectedIndex], selectedIndex);
  }

  Future<void> _showFullPhotoViewer(
    BuildContext context,
    Map<String, dynamic> photo,
    int index,
  ) async {
    final name = photo['name']?.toString() ?? 'ID photo ${index + 1}';
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return Scaffold(
            appBar: AppBar(title: Text(name)),
            backgroundColor: colorScheme.surface,
            body: SafeArea(
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.75,
                  maxScale: 5,
                  child: _IdentityFullPhoto(photo: photo),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IdentityFullPhoto extends StatelessWidget {
  const _IdentityFullPhoto({required this.photo});

  final Map<String, dynamic> photo;

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(photo['bytesBase64']?.toString() ?? '');
      return Image.memory(bytes, fit: BoxFit.contain);
    } catch (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to display photo.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
  }
}

class _IdentityPhotoPreview extends StatelessWidget {
  const _IdentityPhotoPreview({required this.photo, this.size = 64});

  final Map<String, dynamic> photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(photo['bytesBase64']?.toString() ?? '');
      return Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
    } catch (_) {
      return Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.surface,
        child: const Icon(Icons.broken_image_outlined),
      );
    }
  }
}

String _formatIdentityPhotoSize(Object? raw) {
  final bytes = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
  if (bytes <= 0) return 'Image';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}
