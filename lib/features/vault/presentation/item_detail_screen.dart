part of 'vault_app_shell.dart';

class _ItemDetailScreen extends StatefulWidget {
  const _ItemDetailScreen({
    required this.item,
    required this.onCopy,
    required this.onShareSecurely,
    required this.customTypeDefinitions,
    this.showDeleteAction = false,
  });

  final Map<String, dynamic> item;
  final ValueChanged<String> onCopy;
  final Future<void> Function() onShareSecurely;
  final List<Map<String, dynamic>> customTypeDefinitions;
  final bool showDeleteAction;

  @override
  State<_ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<_ItemDetailScreen> {
  final Set<int> _revealedIndexes = <int>{};
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.item['pinned'] == true;
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
    final colorScheme = Theme.of(context).colorScheme;
    final fields = (widget.item['fields'] as List<dynamic>? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    final itemType = widget.item['type']?.toString() ?? 'Item';
    final title = widget.item['title']?.toString() ?? 'Untitled';
    final created = _entryCreatedLabel(widget.item);
    final modified = _entryModifiedLabel(widget.item);
    final device = _entryDeviceLabel(widget.item);
    final lastAccessed = _formatLastAccessedAt(
      widget.item['lastAccessedAt']?.toString(),
    );
    final primarySecret = _extractPrimarySecret(fields);
    final typeIcon = _iconForItemType(itemType);
    final typeColor = _colorForItemType(itemType);
    final idPhotos = _identityPhotos(widget.item);

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
            IconButton(
              onPressed: () => setState(() => _isFavorite = !_isFavorite),
              icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
              tooltip: 'Favorite',
            ),
            IconButton(
              onPressed: () async {
                final updated = await Navigator.of(context)
                    .push<Map<String, dynamic>>(
                      MaterialPageRoute(
                        builder: (_) => AddVaultItemScreen(
                          customTypeDefinitions: widget.customTypeDefinitions,
                          initialItem: widget.item,
                        ),
                      ),
                    );
                if (updated == null || !context.mounted) return;
                if (_isFavorite != (widget.item['pinned'] == true)) {
                  updated['pinned'] = _isFavorite;
                }
                Navigator.of(context).pop(updated);
              },
              icon: const Icon(Icons.edit_outlined),
              tooltip: AppStrings.edit,
            ),
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
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 30),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        itemType,
                        textAlign: TextAlign.center,
                        style: vaultPageHeadingStyle(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        children: List.generate(fields.length, (index) {
                          final field = fields[index];
                          final sensitive = field['sensitive'] == true;
                          final revealed = _revealedIndexes.contains(index);
                          final value = field['value']?.toString() ?? '';
                          final displayValue = sensitive && !revealed
                              ? '••••••••••'
                              : value;
                          return Column(
                            children: [
                              if (index > 0)
                                const Divider(height: 16, thickness: 0.5),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          field['label']?.toString() ?? 'Field',
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          displayValue,
                                          style: TextStyle(
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (sensitive)
                                    IconButton(
                                      icon: Icon(
                                        revealed
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (revealed) {
                                            _revealedIndexes.remove(index);
                                          } else {
                                            _revealedIndexes.add(index);
                                          }
                                        });
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 18),
                                    onPressed: value.isEmpty
                                        ? null
                                        : () => widget.onCopy(value),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                    if (idPhotos.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _IdentityPhotosSection(photos: idPhotos),
                    ],
                    const SizedBox(height: 14),
                    _metadataRow('Category', itemType),
                    const SizedBox(height: 8),
                    _metadataRow('Created', created),
                    const SizedBox(height: 8),
                    _metadataRow('Modified', modified),
                    const SizedBox(height: 8),
                    _metadataRow('Device', device),
                    const SizedBox(height: 8),
                    _metadataRow('Last accessed', lastAccessed),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: primarySecret == null
                            ? null
                            : () => widget.onCopy(primarySecret),
                        child: const Text('Copy Password'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => widget.onShareSecurely(),
                        child: const Text('Share Securely'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _extractPrimarySecret(List<Map<String, dynamic>> fields) {
    if (fields.isEmpty) return null;
    for (final field in fields) {
      final label = field['label']?.toString().toLowerCase() ?? '';
      if (label.contains('password') || label.contains('passcode')) {
        final value = field['value']?.toString() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    for (final field in fields) {
      if (field['sensitive'] == true) {
        final value = field['value']?.toString() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    final fallback = fields.first['value']?.toString() ?? '';
    return fallback.isEmpty ? null : fallback;
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

  Widget _metadataRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
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
    final selectedIndex = await showModalBottomSheet<int>(
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
