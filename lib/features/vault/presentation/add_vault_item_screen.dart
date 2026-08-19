import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/vault_limits.dart';
import '../../../core/localization/app_strings.dart';
import 'widgets/vault_page_heading.dart';

class VaultFieldTemplate {
  const VaultFieldTemplate({
    required this.label,
    this.valueType = 'text',
    this.sensitive = false,
    this.keyboardType,
  });

  final String label;
  final String valueType;
  final bool sensitive;
  final TextInputType? keyboardType;
}

class VaultItemTemplate {
  const VaultItemTemplate({required this.type, required this.fields});

  final String type;
  final List<VaultFieldTemplate> fields;
}

class AddVaultItemScreen extends StatefulWidget {
  const AddVaultItemScreen({
    super.key,
    this.customTypeDefinitions = const <Map<String, dynamic>>[],
    this.initialItem,
    this.fixedType,
    this.currentVaultSizeBytes = 0,
    this.maxVaultBytes = VaultLimits.freeVaultBytes,
    this.maxDocumentBytes = VaultLimits.maxDocumentBytes,
    this.onLifecycleLockSuppressed,
  });

  final List<Map<String, dynamic>> customTypeDefinitions;
  final Map<String, dynamic>? initialItem;
  final String? fixedType;
  final int currentVaultSizeBytes;
  final int maxVaultBytes;
  final int maxDocumentBytes;
  final ValueChanged<bool>? onLifecycleLockSuppressed;

  static const _documentEditTemplate = VaultItemTemplate(
    type: 'Documents',
    fields: [
      VaultFieldTemplate(label: 'Title'),
      VaultFieldTemplate(label: 'Description'),
    ],
  );

  static const templates = <VaultItemTemplate>[
    VaultItemTemplate(
      type: 'Login',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Username or email'),
        VaultFieldTemplate(label: 'Password', sensitive: true),
        VaultFieldTemplate(label: 'Website'),
        VaultFieldTemplate(label: 'Notes'),
      ],
    ),
    VaultItemTemplate(
      type: 'Card',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(
          label: 'Card number',
          sensitive: true,
          keyboardType: TextInputType.number,
        ),
        VaultFieldTemplate(label: 'Name on card'),
        VaultFieldTemplate(label: 'Expiry', sensitive: true),
        VaultFieldTemplate(
          label: 'CVV',
          sensitive: true,
          keyboardType: TextInputType.number,
        ),
        VaultFieldTemplate(label: 'Notes'),
      ],
    ),
    VaultItemTemplate(
      type: 'Identity',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Full name'),
        VaultFieldTemplate(label: 'Document number', sensitive: true),
        VaultFieldTemplate(label: 'Country'),
        VaultFieldTemplate(label: 'Expiry'),
      ],
    ),
    VaultItemTemplate(
      type: 'Password',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Password', sensitive: true),
        VaultFieldTemplate(label: 'Usage / App'),
        VaultFieldTemplate(label: 'Notes'),
      ],
    ),
    VaultItemTemplate(
      type: 'Bank Account',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Bank name'),
        VaultFieldTemplate(label: 'Account number', sensitive: true),
        VaultFieldTemplate(label: 'IFSC / Routing code', sensitive: true),
        VaultFieldTemplate(label: 'Account holder'),
      ],
    ),
    VaultItemTemplate(
      type: 'Passport',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Passport number', sensitive: true),
        VaultFieldTemplate(label: 'Country'),
        VaultFieldTemplate(label: 'Issue date'),
        VaultFieldTemplate(label: 'Expiry date'),
      ],
    ),
    VaultItemTemplate(
      type: 'Driver License',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'License number', sensitive: true),
        VaultFieldTemplate(label: 'State / Region'),
        VaultFieldTemplate(label: 'Expiry date'),
      ],
    ),
    VaultItemTemplate(
      type: 'SSH Key',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Public key'),
        VaultFieldTemplate(label: 'Private key', sensitive: true),
        VaultFieldTemplate(label: 'Passphrase', sensitive: true),
      ],
    ),
    VaultItemTemplate(
      type: 'API Key',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Service'),
        VaultFieldTemplate(label: 'API key', sensitive: true),
        VaultFieldTemplate(label: 'Secret', sensitive: true),
      ],
    ),
    VaultItemTemplate(
      type: 'Wi-Fi Credential',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'SSID'),
        VaultFieldTemplate(label: 'Password', sensitive: true),
        VaultFieldTemplate(label: 'Security type'),
      ],
    ),
    VaultItemTemplate(
      type: 'Server/Database Credential',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Host'),
        VaultFieldTemplate(label: 'Username'),
        VaultFieldTemplate(label: 'Password', sensitive: true),
        VaultFieldTemplate(label: 'Port', keyboardType: TextInputType.number),
      ],
    ),
    VaultItemTemplate(
      type: 'License Key',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Product'),
        VaultFieldTemplate(label: 'License key', sensitive: true),
      ],
    ),
    VaultItemTemplate(
      type: 'Address Profile',
      fields: [
        VaultFieldTemplate(label: 'Title'),
        VaultFieldTemplate(label: 'Full name'),
        VaultFieldTemplate(label: 'Phone'),
        VaultFieldTemplate(label: 'Address line'),
        VaultFieldTemplate(label: 'City / State / ZIP'),
      ],
    ),
  ];

  @override
  State<AddVaultItemScreen> createState() => _AddVaultItemScreenState();
}

class _AddVaultItemScreenState extends State<AddVaultItemScreen> {
  late String _type;
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Set<String> _revealedSensitiveFields = <String>{};
  final List<Map<String, dynamic>> _idPhotos = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _attachments = <Map<String, dynamic>>[];
  late final TextEditingController _tagDraftController;
  final List<String> _tags = <String>[];
  String? _attachmentErrorText;

  @override
  void initState() {
    super.initState();
    _tagDraftController = TextEditingController();
    _type =
        widget.initialItem?['type']?.toString() ??
        widget.fixedType ??
        _allTemplates.first.type;
    _syncControllers();
    _hydrateInitialItem();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _tagDraftController.dispose();
    super.dispose();
  }

  List<VaultItemTemplate> get _allTemplates {
    final custom = widget.customTypeDefinitions.map((definition) {
      final fields =
          (definition['fields'] as List<dynamic>? ?? const <dynamic>[])
              .map((raw) => Map<String, dynamic>.from(raw as Map))
              .map(
                (field) => VaultFieldTemplate(
                  label: field['key']?.toString() ?? 'Field',
                  valueType: field['valueType']?.toString() ?? 'text',
                  sensitive:
                      (field['valueType']?.toString() ?? 'text') == 'password',
                  keyboardType:
                      (field['valueType']?.toString() ?? 'text') == 'number'
                      ? TextInputType.number
                      : TextInputType.text,
                ),
              )
              .toList();

      return VaultItemTemplate(
        type: definition['name']?.toString() ?? 'Custom',
        fields: [
          const VaultFieldTemplate(label: 'Title'),
          ...fields,
        ],
      );
    }).toList();

    final templates = [...AddVaultItemScreen.templates, ...custom];
    final initialType = widget.initialItem?['type']?.toString();
    if (initialType == 'Documents') {
      return [...templates, AddVaultItemScreen._documentEditTemplate];
    }
    if (initialType == null ||
        initialType.isEmpty ||
        templates.any((template) => template.type == initialType)) {
      return templates;
    }

    final fields = (widget.initialItem?['fields'] as List<dynamic>? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .map(
          (field) => VaultFieldTemplate(
            label: field['label']?.toString() ?? 'Field',
            sensitive: field['sensitive'] == true,
          ),
        )
        .where((field) => field.label.trim().isNotEmpty)
        .toList();

    return [
      ...templates,
      VaultItemTemplate(
        type: initialType,
        fields: [
          const VaultFieldTemplate(label: 'Title'),
          ...fields.where((field) => field.label != 'Title'),
        ],
      ),
    ];
  }

  VaultItemTemplate get _template =>
      _allTemplates.firstWhere((item) => item.type == _type);

  void _syncControllers() {
    final labels = _template.fields.map((field) => field.label).toSet();

    _controllers.removeWhere((label, controller) {
      final shouldRemove = !labels.contains(label);
      if (shouldRemove) controller.dispose();
      return shouldRemove;
    });

    for (final field in _template.fields) {
      _controllers.putIfAbsent(field.label, () => TextEditingController());
    }
  }

  void _hydrateInitialItem() {
    final item = widget.initialItem;
    if (item == null) return;

    _controllers['Title']?.text = item['title']?.toString() ?? '';
    final fields = (item['fields'] as List<dynamic>? ?? const <dynamic>[])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    for (final field in fields) {
      final label = field['label']?.toString() ?? '';
      if (label.isEmpty) continue;
      _controllers[label]?.text = field['value']?.toString() ?? '';
    }
    if (item['type']?.toString() == 'Documents' &&
        (_controllers['Description']?.text.trim().isEmpty ?? false)) {
      _controllers['Description']?.text = _documentDescription(item, fields);
    }
    final tags = (item['tags'] as List<dynamic>? ?? const <dynamic>[])
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    _tags
      ..clear()
      ..addAll(tags);
    _idPhotos
      ..clear()
      ..addAll(
        (item['idPhotos'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .where((entry) {
              final bytes = entry['bytesBase64']?.toString() ?? '';
              return bytes.isNotEmpty;
            }),
      );
    _attachments
      ..clear()
      ..addAll(_initialAttachments(item));
  }

  String _documentDescription(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> fields,
  ) {
    for (final field in fields) {
      final label = field['label']?.toString().trim().toLowerCase() ?? '';
      if (label == 'description') {
        return field['value']?.toString() ?? '';
      }
    }
    final subtitle = item['subtitle']?.toString() ?? '';
    final fileName = item['documentFileName']?.toString() ?? '';
    return subtitle == fileName ? '' : subtitle;
  }

  List<Map<String, dynamic>> _initialAttachments(Map<String, dynamic> item) {
    return (item['attachments'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where((entry) {
          final fileName = entry['documentFileName']?.toString().trim() ?? '';
          final section = entry['documentSection']?.toString().trim() ?? '';
          return fileName.isNotEmpty || section.isNotEmpty;
        })
        .toList();
  }

  Map<String, dynamic>? get _primaryDocumentSelection {
    final item = widget.initialItem;
    if (item == null) return null;
    if ((item['type']?.toString() ?? '') != 'Documents') return null;
    final fileName = item['documentFileName']?.toString().trim() ?? '';
    final section = item['documentSection']?.toString().trim() ?? '';
    if (fileName.isEmpty && section.isEmpty) return null;
    return {
      'id': item['id']?.toString() ?? 'primary-document',
      'documentFileName': fileName.isEmpty
          ? item['title']?.toString() ?? 'document'
          : fileName,
      'documentExtension': item['documentExtension']?.toString() ?? 'FILE',
      'documentSizeBytes': item['documentSizeBytes'] ?? 0,
      'documentSection': section,
      'documentStorage': item['documentStorage'] ?? 'private-section',
      '__primaryDocument__': true,
    };
  }

  bool get _canSave {
    final titleController = _controllers['Title'];
    return titleController != null && titleController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final showTypeSelector =
        widget.fixedType == null && widget.initialItem == null;
    final categoryColor = _colorForItemType(
      _type,
      widget.customTypeDefinitions,
    );
    final categoryIcon = _iconForItemType(_type, widget.customTypeDefinitions);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialItem == null ? 'New $_type' : 'Edit item'),
        leading: TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Cancel'),
        ),
        leadingWidth: 86,
        actions: [const SizedBox.shrink()],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = MediaQuery.sizeOf(context);
            final isWide = viewport.width >= 760 && viewport.height >= 700;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 24 : 16,
                18,
                isWide ? 24 : 16,
                28,
              ),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 860 : double.infinity,
                    ),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: categoryColor.withValues(
                                      alpha: 0.18,
                                    ),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    categoryIcon,
                                    color: categoryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _type,
                                    style: vaultPageHeadingStyle(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (showTypeSelector) ...[
                              DropdownButtonFormField<String>(
                                initialValue: _type,
                                items: _allTemplates
                                    .map(
                                      (template) => DropdownMenuItem(
                                        value: template.type,
                                        child: Text(template.type),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null || value == _type) return;
                                  setState(() {
                                    _type = value;
                                    _syncControllers();
                                  });
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            ..._template.fields.map((field) {
                              final controller = _controllers[field.label]!;
                              final isLong =
                                  field.label == 'Private key' ||
                                  field.label == 'Notes' ||
                                  field.label == 'Address line';
                              final isDate = field.valueType == 'date';
                              final isNumber = field.valueType == 'number';
                              final key = field.label;
                              final isRevealed = _revealedSensitiveFields
                                  .contains(key);
                              final obscure =
                                  field.sensitive && !isLong && !isRevealed;
                              final hint = _fieldHint(field.label);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: TextField(
                                  controller: controller,
                                  keyboardType: isNumber
                                      ? TextInputType.number
                                      : field.keyboardType,
                                  readOnly: isDate,
                                  obscureText: obscure,
                                  minLines: isLong ? 3 : 1,
                                  maxLines: isLong ? 6 : 1,
                                  onChanged: (_) => setState(() {}),
                                  onTap: isDate
                                      ? () async {
                                          final now = DateTime.now();
                                          final picked = await showDatePicker(
                                            context: context,
                                            firstDate: DateTime(now.year - 100),
                                            lastDate: DateTime(now.year + 100),
                                            initialDate: now,
                                          );
                                          if (picked == null) return;
                                          controller.text =
                                              '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                          setState(() {});
                                        }
                                      : null,
                                  decoration: InputDecoration(
                                    labelText: field.label,
                                    hintText: hint == field.label ? null : hint,
                                    suffixIcon: field.sensitive && !isLong
                                        ? SizedBox(
                                            width: 56,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  onTap: () {
                                                    setState(() {
                                                      if (isRevealed) {
                                                        _revealedSensitiveFields
                                                            .remove(key);
                                                      } else {
                                                        _revealedSensitiveFields
                                                            .add(key);
                                                      }
                                                    });
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    child: Icon(
                                                      isRevealed
                                                          ? Icons.visibility_off
                                                          : Icons.visibility,
                                                      size: 17,
                                                    ),
                                                  ),
                                                ),
                                                InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  onTap: () async {
                                                    await Clipboard.setData(
                                                      ClipboardData(
                                                        text: controller.text,
                                                      ),
                                                    );
                                                  },
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Icon(
                                                      Icons.copy,
                                                      size: 17,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            }),
                            _buildTagsEditor(context),
                            if (_supportsIdPhotos) ...[
                              const SizedBox(height: 12),
                              _buildIdPhotosSection(context),
                            ],
                            const SizedBox(height: 12),
                            _buildAttachmentsEditor(context),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _canSave ? _save : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _fieldHint(String label) {
    final normalized = label.toLowerCase();
    if (normalized == 'title') return 'Title';
    if (normalized.contains('username')) return 'Username';
    if (normalized.contains('password')) return 'Password';
    if (normalized.contains('website')) return 'Website (optional)';
    if (normalized.contains('notes')) return 'Notes (optional)';
    return label;
  }

  Widget _buildTagsEditor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _tagDraftController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _commitTagDraft(),
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'Add tag',
                  helperText: 'Press add after each tag',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IconButton.filledTonal(
                onPressed: _commitTagDraft,
                icon: const Icon(Icons.add),
                tooltip: 'Add tag',
              ),
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _tags.map((tag) {
              return InputChip(
                label: Text(tag),
                backgroundColor: colorScheme.surfaceContainerHighest,
                onDeleted: () => setState(() => _tags.remove(tag)),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _commitTagDraft() {
    final parts = _tagDraftController.text
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty);
    var changed = false;
    for (final part in parts) {
      if (_tags.contains(part)) continue;
      _tags.add(part);
      changed = true;
    }
    if (!changed && _tagDraftController.text.trim().isEmpty) return;
    _tagDraftController.clear();
    setState(() {});
  }

  Widget _buildAttachmentsEditor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryDocument = _primaryDocumentSelection;
    final selectedDocuments = [?primaryDocument, ..._attachments];
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
              TextButton.icon(
                key: const ValueKey('item-form-add-document'),
                onPressed: _pickAttachment,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  selectedDocuments.isEmpty ? 'Choose document' : 'Add another',
                ),
              ),
            ],
          ),
          Text(
            'Maximum file size: ${VaultLimits.formatBytes(widget.maxDocumentBytes)}',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          if (_attachmentErrorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _attachmentErrorText!,
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          if (selectedDocuments.isEmpty)
            Text(
              'No documents selected',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            )
          else
            ...List.generate(selectedDocuments.length, (index) {
              final attachment = selectedDocuments[index];
              final isPrimary = attachment['__primaryDocument__'] == true;
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  key: ValueKey(
                    'item-form-attachment-${attachment['id']?.toString() ?? index}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(
                    attachment['documentFileName']?.toString() ?? 'document',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    isPrimary
                        ? 'Current document · ${VaultLimits.formatBytes(_attachmentSizeBytes(attachment))}'
                        : VaultLimits.formatBytes(
                            _attachmentSizeBytes(attachment),
                          ),
                  ),
                  trailing: IconButton(
                    key: ValueKey('item-form-remove-attachment-$index'),
                    onPressed: isPrimary
                        ? null
                        : () => setState(() {
                            final attachmentIndex = primaryDocument == null
                                ? index
                                : index - 1;
                            _attachments.removeAt(attachmentIndex);
                            _attachmentErrorText = null;
                          }),
                    icon: const Icon(Icons.close),
                    tooltip: isPrimary
                        ? 'Current document cannot be removed here'
                        : 'Remove document',
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _pickAttachment() async {
    widget.onLifecycleLockSuppressed?.call(true);
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
        withReadStream: true,
      );
    } finally {
      widget.onLifecycleLockSuppressed?.call(false);
    }
    final file = result?.files.single;
    if (file == null) return;
    final error = _attachmentValidationError(file);
    if (error != null) {
      setState(() => _attachmentErrorText = error);
      return;
    }
    final uploadedAt = DateTime.now().toUtc().toIso8601String();
    final attachment = <String, dynamic>{
      'id': 'attachment-${DateTime.now().microsecondsSinceEpoch}',
      'title': _fileNameWithoutExtension(file.name),
      'documentFileName': file.name,
      'documentExtension': _extensionForFileName(file.name),
      'documentSizeBytes': file.size,
      'documentUploadedAt': uploadedAt,
      'documentStorage': 'pending',
      if (file.readStream != null) '__documentReadStream__': file.readStream,
      if (file.bytes != null) '__documentBytes__': file.bytes,
    };
    setState(() {
      _attachments.add(attachment);
      _attachmentErrorText = null;
    });
  }

  String? _attachmentValidationError(PlatformFile file) {
    if (file.size > widget.maxDocumentBytes) {
      return 'Document must be ${VaultLimits.formatBytes(widget.maxDocumentBytes)} or smaller.';
    }
    if (file.readStream == null && file.bytes == null) {
      return 'Could not read the selected document.';
    }
    final selectedBytes = _attachments.fold<int>(
      0,
      (sum, attachment) => sum + _pendingAttachmentSizeBytes(attachment),
    );
    final projected = widget.currentVaultSizeBytes + selectedBytes + file.size;
    if (projected > widget.maxVaultBytes) {
      return 'Not enough vault space. Limit is ${VaultLimits.formatBytes(widget.maxVaultBytes)}.';
    }
    return null;
  }

  int _pendingAttachmentSizeBytes(Map<String, dynamic> attachment) {
    if (attachment['documentSection'] != null) return 0;
    return _attachmentSizeBytes(attachment);
  }

  int _attachmentSizeBytes(Map<String, dynamic> attachment) {
    final raw = attachment['documentSizeBytes'];
    if (raw is int && raw >= 0) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _extensionForFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'FILE';
    return fileName.substring(dot + 1).toUpperCase();
  }

  String _fileNameWithoutExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }

  void _save() {
    final title = _controllers['Title']!.text.trim();

    String subtitle = '';
    for (final field in _template.fields) {
      if (field.label == 'Title' || field.sensitive) continue;
      final value = _controllers[field.label]!.text.trim();
      if (value.isNotEmpty) {
        subtitle = value;
        break;
      }
    }

    final fields = _template.fields
        .where((field) => field.label != 'Title')
        .map(
          (field) => {
            'label': field.label,
            'value': _controllers[field.label]!.text.trim(),
            'sensitive': field.sensitive,
          },
        )
        .toList();
    _commitTagDraft();

    final item = {
      ...Map<String, dynamic>.from(widget.initialItem ?? const {}),
      'id':
          widget.initialItem?['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'type': _type,
      'title': title,
      'subtitle': subtitle,
      'updated': 'Now',
      'pinned': widget.initialItem?['pinned'] == true,
      'tags': List<String>.from(_tags),
      'fields': fields,
    };
    if (_idPhotos.isNotEmpty) {
      item['idPhotos'] = _idPhotos
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } else {
      item.remove('idPhotos');
    }
    if (_attachments.isNotEmpty) {
      item['attachments'] = _attachments
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } else {
      item.remove('attachments');
    }
    Navigator.of(context).pop(item);
  }

  bool get _supportsIdPhotos => _type.trim().toLowerCase() == 'identity';

  Widget _buildIdPhotosSection(BuildContext context) {
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
                  'ID photos',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('identity-add-photo'),
                onPressed: _pickIdPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add photo'),
              ),
            ],
          ),
          if (_idPhotos.isEmpty)
            Text(
              'No photos attached.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            )
          else
            ..._idPhotos.asMap().entries.map((entry) {
              final index = entry.key;
              final photo = entry.value;
              return Padding(
                padding: EdgeInsets.only(top: index == 0 ? 4 : 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _idPhotoPreview(photo, width: 44, height: 44),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        photo['name']?.toString() ?? 'ID photo ${index + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('identity-remove-photo-$index'),
                      onPressed: () =>
                          setState(() => _idPhotos.removeAt(index)),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove photo',
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _idPhotoPreview(
    Map<String, dynamic> photo, {
    required double width,
    required double height,
  }) {
    try {
      final bytes = base64Decode(photo['bytesBase64']?.toString() ?? '');
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    } catch (_) {
      return Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surface,
        child: const Icon(Icons.broken_image_outlined, size: 18),
      );
    }
  }

  Future<void> _pickIdPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final photos = result.files
        .where((file) => file.bytes != null && file.bytes!.isNotEmpty)
        .map(
          (file) => <String, dynamic>{
            'id': '${now}_${file.name}_${_idPhotos.length}',
            'name': file.name,
            'sizeBytes': file.size,
            'extension': file.extension,
            'addedAt': now,
            'bytesBase64': base64Encode(file.bytes!),
          },
        )
        .toList();
    if (photos.isEmpty) return;
    setState(() => _idPhotos.addAll(photos));
  }
}

class NewItemCategoryScreen extends StatefulWidget {
  const NewItemCategoryScreen({
    super.key,
    required this.customTypeDefinitions,
    this.currentVaultSizeBytes = 0,
    this.maxVaultBytes = VaultLimits.freeVaultBytes,
    this.maxDocumentBytes = VaultLimits.maxDocumentBytes,
    this.onLifecycleLockSuppressed,
    this.onCreateNote,
    this.onCreateDocument,
  });

  final List<Map<String, dynamic>> customTypeDefinitions;
  final int currentVaultSizeBytes;
  final int maxVaultBytes;
  final int maxDocumentBytes;
  final ValueChanged<bool>? onLifecycleLockSuppressed;
  final Future<Map<String, dynamic>?> Function()? onCreateNote;
  final Future<Map<String, dynamic>?> Function()? onCreateDocument;

  @override
  State<NewItemCategoryScreen> createState() => _NewItemCategoryScreenState();
}

class _NewItemCategoryScreenState extends State<NewItemCategoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final options = _buildCategoryOptions(widget.customTypeDefinitions);
    final filtered = options.where((option) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return option.type.toLowerCase().contains(q) ||
          option.subtitle.toLowerCase().contains(q);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Item'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              key: const ValueKey('new-item-category-shell'),
              constraints: BoxConstraints(
                maxWidth: isWide ? 680 : constraints.maxWidth,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search category...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        final colorScheme = Theme.of(context).colorScheme;
                        return Material(
                          key: ValueKey(
                            'new-item-category-${option.kind}-${option.type}',
                          ),
                          color: colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: ListTile(
                            minVerticalPadding: 12,
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: option.color.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                option.icon,
                                color: option.color,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              option.type,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              option.subtitle,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            onTap: () async {
                              if (option.kind == 'note' &&
                                  widget.onCreateNote != null) {
                                final createdNote = await widget.onCreateNote!
                                    .call();
                                if (createdNote == null || !context.mounted) {
                                  return;
                                }
                                await _showSavedSuccessSheet(context);
                                if (!context.mounted) return;
                                Navigator.of(context).pop({
                                  'kind': 'note',
                                  'entry': createdNote,
                                });
                                return;
                              }
                              if (option.kind == 'document' &&
                                  widget.onCreateDocument != null) {
                                final createdDocument = await widget
                                    .onCreateDocument!
                                    .call();
                                if (createdDocument == null ||
                                    !context.mounted) {
                                  return;
                                }
                                await _showSavedSuccessSheet(context);
                                if (!context.mounted) return;
                                Navigator.of(context).pop({
                                  'kind': 'item',
                                  'entry': createdDocument,
                                });
                                return;
                              }
                              final createdItem = await Navigator.of(context)
                                  .push<Map<String, dynamic>>(
                                    MaterialPageRoute(
                                      builder: (_) => AddVaultItemScreen(
                                        customTypeDefinitions:
                                            widget.customTypeDefinitions,
                                        fixedType: option.type,
                                        currentVaultSizeBytes:
                                            widget.currentVaultSizeBytes,
                                        maxVaultBytes: widget.maxVaultBytes,
                                        maxDocumentBytes:
                                            widget.maxDocumentBytes,
                                        onLifecycleLockSuppressed:
                                            widget.onLifecycleLockSuppressed,
                                      ),
                                    ),
                                  );
                              if (createdItem == null || !context.mounted) {
                                return;
                              }
                              await _showSavedSuccessSheet(context);
                              if (!context.mounted) return;
                              Navigator.of(context).pop({
                                'kind': 'item',
                                'entry': createdItem,
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSavedSuccessSheet(BuildContext context) async {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    if (isWide) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const _SavedSuccessContent(),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => const SafeArea(child: _SavedSuccessContent()),
    );
  }
}

class _SavedSuccessContent extends StatelessWidget {
  const _SavedSuccessContent();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('saved-success-content'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF16A34A),
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppStrings.entrySaved,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.entrySavedMessage,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppStrings.done),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryOption {
  const _CategoryOption({
    required this.kind,
    required this.type,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String kind;
  final String type;
  final String subtitle;
  final IconData icon;
  final Color color;
}

List<_CategoryOption> _buildCategoryOptions(
  List<Map<String, dynamic>> customTypeDefinitions,
) {
  final note = _CategoryOption(
    kind: 'note',
    type: 'Notes',
    subtitle: 'Secure notes and memos',
    icon: Icons.note_add_outlined,
    color: const Color(0xFFFBBF24),
  );
  final documents = _CategoryOption(
    kind: 'document',
    type: 'Documents',
    subtitle: 'Encrypted files up to 5 MB',
    icon: Icons.folder_outlined,
    color: const Color(0xFFFB7185),
  );
  final builtIn = AddVaultItemScreen.templates
      .map(
        (template) => _CategoryOption(
          kind: 'item',
          type: template.type,
          subtitle: _subtitleForType(template.type),
          icon: _iconForCategoryType(template.type),
          color: _colorForCategoryType(template.type),
        ),
      )
      .toList();
  final custom = customTypeDefinitions
      .map(
        (definition) => _CategoryOption(
          kind: 'item',
          type: definition['name']?.toString() ?? 'Custom',
          subtitle: 'Create your own template',
          icon: _iconForCustomTemplateKey(definition['iconKey']?.toString()),
          color: _colorForCustomTemplateColorKey(
            definition['colorKey']?.toString(),
          ),
        ),
      )
      .toList();
  return [note, documents, ...custom, ...builtIn];
}

String _subtitleForType(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('password') || normalized.contains('login')) {
    return 'Website, app, Wi-Fi and more';
  }
  if (normalized.contains('note')) return 'Secure notes and memos';
  if (normalized.contains('document')) return 'Encrypted files and records';
  if (normalized.contains('ident') || normalized.contains('passport')) {
    return 'Personal info and IDs';
  }
  if (normalized.contains('finan') || normalized.contains('bank')) {
    return 'Accounts, cards, budgets';
  }
  if (normalized.contains('document') || normalized.contains('license')) {
    return 'Files and important docs';
  }
  if (normalized.contains('health')) return 'Medical info and records';
  return 'Secure item details';
}

IconData _iconForCategoryType(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('password') || normalized.contains('login')) {
    return Icons.lock_outline;
  }
  if (normalized.contains('note')) return Icons.sticky_note_2_outlined;
  if (normalized.contains('document')) return Icons.folder_outlined;
  if (normalized.contains('ident') || normalized.contains('passport')) {
    return Icons.badge_outlined;
  }
  if (normalized.contains('finan') || normalized.contains('bank')) {
    return Icons.account_balance_wallet_outlined;
  }
  if (normalized.contains('document') || normalized.contains('license')) {
    return Icons.folder_outlined;
  }
  if (normalized.contains('health')) return Icons.favorite_outline;
  return Icons.shield_outlined;
}

Map<String, dynamic>? _customTypeDefinitionForType(
  String type,
  List<Map<String, dynamic>> definitions,
) {
  final normalized = type.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (final definition in definitions) {
    final name = definition['name']?.toString().trim().toLowerCase();
    if (name == normalized) return definition;
  }
  return null;
}

IconData _iconForItemType(
  String type,
  List<Map<String, dynamic>> customTypeDefinitions,
) {
  final iconKey = _customTypeDefinitionForType(
    type,
    customTypeDefinitions,
  )?['iconKey']?.toString();
  if (iconKey != null) return _iconForCustomTemplateKey(iconKey);
  return _iconForCategoryType(type);
}

Color _colorForCategoryType(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('password') || normalized.contains('login')) {
    return const Color(0xFF60A5FA);
  }
  if (normalized.contains('note')) return const Color(0xFFFBBF24);
  if (normalized.contains('document')) return const Color(0xFFFB7185);
  if (normalized.contains('ident') || normalized.contains('passport')) {
    return const Color(0xFF34D399);
  }
  if (normalized.contains('finan') || normalized.contains('bank')) {
    return const Color(0xFF22C55E);
  }
  if (normalized.contains('document') || normalized.contains('license')) {
    return const Color(0xFFFB923C);
  }
  if (normalized.contains('health')) return const Color(0xFFF472B6);
  return const Color(0xFF93C5FD);
}

Color _colorForItemType(
  String type,
  List<Map<String, dynamic>> customTypeDefinitions,
) {
  final colorKey = _customTypeDefinitionForType(
    type,
    customTypeDefinitions,
  )?['colorKey']?.toString();
  if (colorKey != null) return _colorForCustomTemplateColorKey(colorKey);
  return _colorForCategoryType(type);
}

IconData _iconForCustomTemplateKey(String? key) {
  switch (key) {
    case 'lock':
      return Icons.lock_outline;
    case 'note':
      return Icons.sticky_note_2_outlined;
    case 'id':
      return Icons.badge_outlined;
    case 'wallet':
      return Icons.account_balance_wallet_outlined;
    case 'folder':
      return Icons.folder_outlined;
    case 'heart':
      return Icons.favorite_outline;
    case 'star':
      return Icons.star_outline;
    case 'spark':
      return Icons.auto_awesome_outlined;
    case 'key':
      return Icons.key_outlined;
    case 'password':
      return Icons.password_outlined;
    case 'credit_card':
      return Icons.credit_card;
    case 'bank':
      return Icons.account_balance_outlined;
    case 'receipt':
      return Icons.receipt_long_outlined;
    case 'car':
      return Icons.directions_car_outlined;
    case 'home':
      return Icons.home_outlined;
    case 'work':
      return Icons.work_outline;
    case 'travel':
      return Icons.flight_takeoff_outlined;
    case 'passport':
      return Icons.airplane_ticket_outlined;
    case 'calendar':
      return Icons.event_outlined;
    case 'phone':
      return Icons.phone_iphone_outlined;
    case 'email':
      return Icons.alternate_email;
    case 'wifi':
      return Icons.wifi_outlined;
    case 'server':
      return Icons.dns_outlined;
    case 'code':
      return Icons.code_outlined;
    case 'database':
      return Icons.storage_outlined;
    case 'cloud':
      return Icons.cloud_outlined;
    case 'medical':
      return Icons.medical_services_outlined;
    case 'pet':
      return Icons.pets_outlined;
    case 'school':
      return Icons.school_outlined;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'gift':
      return Icons.card_giftcard_outlined;
    case 'photo':
      return Icons.photo_outlined;
    case 'link':
      return Icons.link_outlined;
    default:
      return Icons.auto_awesome_outlined;
  }
}

Color _colorForCustomTemplateColorKey(String? key) {
  switch (key) {
    case 'purple':
      return const Color(0xFF8B5CF6);
    case 'indigo':
      return const Color(0xFF6366F1);
    case 'blue':
      return const Color(0xFF60A5FA);
    case 'sky':
      return const Color(0xFF38BDF8);
    case 'cyan':
      return const Color(0xFF22D3EE);
    case 'teal':
      return const Color(0xFF2DD4BF);
    case 'green':
      return const Color(0xFF4ADE80);
    case 'emerald':
      return const Color(0xFF10B981);
    case 'lime':
      return const Color(0xFFA3E635);
    case 'amber':
      return const Color(0xFFFBBF24);
    case 'yellow':
      return const Color(0xFFFDE047);
    case 'orange':
      return const Color(0xFFFB923C);
    case 'red':
      return const Color(0xFFF87171);
    case 'rose':
      return const Color(0xFFFB7185);
    case 'pink':
      return const Color(0xFFF472B6);
    case 'fuchsia':
      return const Color(0xFFE879F9);
    case 'slate':
      return const Color(0xFF64748B);
    case 'gray':
      return const Color(0xFF9CA3AF);
    default:
      return const Color(0xFF6366F1);
  }
}
