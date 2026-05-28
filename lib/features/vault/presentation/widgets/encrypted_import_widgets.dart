part of '../vault_app_shell.dart';

class _EncryptedShareChoice {
  const _EncryptedShareChoice({required this.fileName, required this.password});

  final String fileName;
  final String password;
}

class _EncryptedImportEntry {
  const _EncryptedImportEntry({
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

class _PreparedVaultImport {
  _PreparedVaultImport({
    List<Map<String, dynamic>>? items,
    List<Map<String, dynamic>>? notes,
  }) : items = items ?? <Map<String, dynamic>>[],
       notes = notes ?? <Map<String, dynamic>>[];

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> notes;

  bool get isEmpty => items.isEmpty && notes.isEmpty;
}

class _EncryptedShareInputDialog extends StatefulWidget {
  const _EncryptedShareInputDialog({
    required this.initialFileName,
    required this.title,
    required this.actionLabel,
    required this.ensureExtension,
  });

  final String initialFileName;
  final String title;
  final String actionLabel;
  final String Function(String fileName) ensureExtension;

  @override
  State<_EncryptedShareInputDialog> createState() =>
      _EncryptedShareInputDialogState();
}

class _EncryptedShareInputDialogState
    extends State<_EncryptedShareInputDialog> {
  late final TextEditingController _fileNameController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _fileNameController = TextEditingController(text: widget.initialFileName);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawName = _fileNameController.text.trim();
    final hasName = rawName.isNotEmpty;
    final hasPassword = _passwordController.text.trim().isNotEmpty;
    final canShare = hasName && hasPassword;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _fileNameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'File name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Password for this file',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canShare
              ? () {
                  final normalizedName = widget.ensureExtension(rawName);
                  Navigator.of(context).pop(
                    _EncryptedShareChoice(
                      fileName: normalizedName,
                      password: _passwordController.text,
                    ),
                  );
                }
              : null,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

class _EncryptedImportBundleScreen extends StatefulWidget {
  const _EncryptedImportBundleScreen({
    required this.entries,
    required this.customTypeDefinitions,
    required this.onImportEntry,
    required this.onImportAll,
  });

  final List<_EncryptedImportEntry> entries;
  final List<Map<String, dynamic>> customTypeDefinitions;
  final Future<bool> Function(_EncryptedImportEntry entry) onImportEntry;
  final Future<bool> Function(List<_EncryptedImportEntry> entries) onImportAll;

  @override
  State<_EncryptedImportBundleScreen> createState() =>
      _EncryptedImportBundleScreenState();
}

class _EncryptedImportBundleScreenState
    extends State<_EncryptedImportBundleScreen> {
  final Set<int> _importedIndexes = <int>{};
  bool _importingAll = false;

  List<_EncryptedImportEntry> get _remainingEntries => widget.entries
      .where((entry) => !_importedIndexes.contains(entry.index))
      .toList();

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
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          itemCount: widget.entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
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
    );
  }

  Future<void> _openEntry(
    _EncryptedImportEntry entry, {
    required bool imported,
  }) async {
    final didImport = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EncryptedImportEntryPreviewScreen(
          entry: entry,
          customTypeDefinitions: widget.customTypeDefinitions,
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImportFailed)),
      );
    }
  }
}

class _EncryptedImportEntryPreviewScreen extends StatefulWidget {
  const _EncryptedImportEntryPreviewScreen({
    required this.entry,
    required this.customTypeDefinitions,
    required this.alreadyImported,
    required this.onImport,
  });

  final _EncryptedImportEntry entry;
  final List<Map<String, dynamic>> customTypeDefinitions;
  final bool alreadyImported;
  final Future<bool> Function() onImport;

  @override
  State<_EncryptedImportEntryPreviewScreen> createState() =>
      _EncryptedImportEntryPreviewScreenState();
}

class _EncryptedImportEntryPreviewScreenState
    extends State<_EncryptedImportEntryPreviewScreen> {
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

  Widget _buildPreview(BuildContext context, _EncryptedImportEntry entry) {
    if (entry.kind == 'note') return _buildNotePreview(context, entry);
    if (entry.kind == 'document') return _buildDocumentPreview(context, entry);
    return _buildVaultItemPreview(context, entry);
  }

  Widget _buildVaultItemPreview(
    BuildContext context,
    _EncryptedImportEntry entry,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final rawEntry = entry.bundleEntry['entry'];
    final item = rawEntry is Map
        ? Map<String, dynamic>.from(rawEntry)
        : const <String, dynamic>{};
    final fields = (item['fields'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
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

  Widget _buildNotePreview(BuildContext context, _EncryptedImportEntry entry) {
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

  Widget _buildDocumentPreview(
    BuildContext context,
    _EncryptedImportEntry entry,
  ) {
    final fileName = entry.bundleEntry['fileName']?.toString() ?? entry.title;
    final extension =
        entry.bundleEntry['extension']?.toString().toUpperCase() ?? '';
    final size = int.tryParse(entry.bundleEntry['sizeBytes']?.toString() ?? '');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        _ImportPreviewHeader(
          icon: Icons.folder_outlined,
          color: const Color(0xFFFB923C),
          title: entry.title,
          subtitle: 'Document',
        ),
        const SizedBox(height: 16),
        _ImportPreviewRow(label: 'File name', value: fileName),
        _ImportPreviewRow(label: 'Extension', value: extension),
        _ImportPreviewRow(
          label: 'Size',
          value: size == null ? '-' : _formatDocumentByteCount(size),
        ),
      ],
    );
  }

  String _previewTitle(_EncryptedImportEntry entry) {
    if (entry.kind == 'note') return 'Note';
    if (entry.kind == 'document') return 'Document';
    return entry.subtitle.isEmpty ? 'Vault Item' : entry.subtitle;
  }

  String _notePreviewBody(_EncryptedImportEntry entry) {
    final rawEntry = entry.bundleEntry['entry'];
    if (rawEntry is Map) {
      final delta = rawEntry['delta'];
      if (delta is List) {
        return delta
            .whereType<Map>()
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImportFailed)),
      );
    }
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
          style: vaultPageHeadingStyle(context),
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

IconData _iconForImportEntry(_EncryptedImportEntry entry) {
  if (entry.kind == 'note') return Icons.sticky_note_2_outlined;
  if (entry.kind == 'document') return Icons.folder_outlined;
  final rawEntry = entry.bundleEntry['entry'];
  if (rawEntry is Map) {
    return _iconForHomeType(rawEntry['type']?.toString() ?? 'Item');
  }
  return Icons.lock_outline;
}

Color _colorForImportEntry(_EncryptedImportEntry entry) {
  if (entry.kind == 'note') return const Color(0xFF6366F1);
  if (entry.kind == 'document') return const Color(0xFFFB923C);
  final rawEntry = entry.bundleEntry['entry'];
  if (rawEntry is Map) {
    return _colorForHomeType(rawEntry['type']?.toString() ?? 'Item');
  }
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

String _formatDocumentByteCount(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}
