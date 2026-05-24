import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  });

  final List<Map<String, dynamic>> customTypeDefinitions;
  final Map<String, dynamic>? initialItem;
  final String? fixedType;

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
  late final TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    _tagsController = TextEditingController();
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
    _tagsController.dispose();
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
    final tags = (item['tags'] as List<dynamic>? ?? const <dynamic>[])
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    _tagsController.text = tags.join(', ');
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            Card(
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
                            color: categoryColor.withValues(alpha: 0.18),
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
                        decoration: const InputDecoration(hintText: 'Category'),
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
                      final isRevealed = _revealedSensitiveFields.contains(key);
                      final obscure = field.sensitive && !isLong && !isRevealed;
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
                            hintText: hint,
                            suffixIcon: field.sensitive && !isLong
                                ? SizedBox(
                                    width: 56,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () {
                                            setState(() {
                                              if (isRevealed) {
                                                _revealedSensitiveFields.remove(
                                                  key,
                                                );
                                              } else {
                                                _revealedSensitiveFields.add(
                                                  key,
                                                );
                                              }
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              isRevealed
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              size: 17,
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () async {
                                            await Clipboard.setData(
                                              ClipboardData(
                                                text: controller.text,
                                              ),
                                            );
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(Icons.copy, size: 17),
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
                    TextField(
                      controller: _tagsController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(hintText: 'Add tags'),
                    ),
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
          ],
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

  void _save() {
    final title = _controllers['Title']!.text.trim();

    String subtitle = '';
    for (final field in _template.fields) {
      if (field.label == 'Title') continue;
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
    final tags = _tagsController.text
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();

    Navigator.of(context).pop({
      ...Map<String, dynamic>.from(widget.initialItem ?? const {}),
      'id':
          widget.initialItem?['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'type': _type,
      'title': title,
      'subtitle': subtitle,
      'updated': 'Now',
      'pinned': widget.initialItem?['pinned'] == true,
      'tags': tags,
      'fields': fields,
    });
  }
}

class NewItemCategoryScreen extends StatefulWidget {
  const NewItemCategoryScreen({
    super.key,
    required this.customTypeDefinitions,
    this.onCreateNote,
  });

  final List<Map<String, dynamic>> customTypeDefinitions;
  final Future<Map<String, dynamic>?> Function()? onCreateNote;

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
      body: Column(
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
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final option = filtered[index];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: option.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(option.icon, color: option.color, size: 18),
                    ),
                    title: Text(option.type),
                    subtitle: Text(option.subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      if (option.kind == 'note' &&
                          widget.onCreateNote != null) {
                        final createdNote = await widget.onCreateNote!.call();
                        if (createdNote == null || !context.mounted) return;
                        await _showSavedSuccessSheet(context);
                        if (!context.mounted) return;
                        Navigator.of(
                          context,
                        ).pop({'kind': 'note', 'entry': createdNote});
                        return;
                      }
                      final createdItem = await Navigator.of(context)
                          .push<Map<String, dynamic>>(
                            MaterialPageRoute(
                              builder: (_) => AddVaultItemScreen(
                                customTypeDefinitions:
                                    widget.customTypeDefinitions,
                                fixedType: option.type,
                              ),
                            ),
                          );
                      if (createdItem == null || !context.mounted) return;
                      await _showSavedSuccessSheet(context);
                      if (!context.mounted) return;
                      Navigator.of(
                        context,
                      ).pop({'kind': 'item', 'entry': createdItem});
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSavedSuccessSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
              const SizedBox(height: 10),
              const Text(
                'Entry saved',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Your new entry has been saved successfully.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
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
  return [note, ...custom, ...builtIn];
}

String _subtitleForType(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('password') || normalized.contains('login')) {
    return 'Website, app, Wi-Fi and more';
  }
  if (normalized.contains('note')) return 'Secure notes and memos';
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
