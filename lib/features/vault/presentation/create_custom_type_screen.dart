import 'package:flutter/material.dart';

import 'widgets/vault_page_heading.dart';

class CreateCustomTypeScreen extends StatefulWidget {
  const CreateCustomTypeScreen({super.key, this.initialTemplate});

  final Map<String, dynamic>? initialTemplate;

  @override
  State<CreateCustomTypeScreen> createState() => _CreateCustomTypeScreenState();
}

class _CreateCustomTypeScreenState extends State<CreateCustomTypeScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<_FieldRow> _rows = <_FieldRow>[];
  int _step = 0;
  String _iconKey = _availableTemplateIcons.first.key;
  String _colorKey = _availableTemplateColors.first.key;

  bool get _isEditing => widget.initialTemplate != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTemplate;
    if (initial != null) {
      _nameController.text = initial['name']?.toString() ?? '';
      _descriptionController.text = initial['description']?.toString() ?? '';
      final iconKey = initial['iconKey']?.toString();
      if (iconKey != null &&
          _availableTemplateIcons.any((option) => option.key == iconKey)) {
        _iconKey = iconKey;
      }
      final colorKey = initial['colorKey']?.toString();
      if (colorKey != null &&
          _availableTemplateColors.any((option) => option.key == colorKey)) {
        _colorKey = colorKey;
      }
      final fields = (initial['fields'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      if (fields.isEmpty) {
        _rows.add(_FieldRow());
      } else {
        for (final field in fields) {
          _rows.add(
            _FieldRow(
              keyText: field['key']?.toString() ?? '',
              valueType: field['valueType']?.toString() ?? 'text',
            ),
          );
        }
      }
    } else {
      _rows.add(_FieldRow());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (final row in _rows) {
      row.keyController.dispose();
    }
    super.dispose();
  }

  bool get _canContinue => _nameController.text.trim().isNotEmpty;

  bool get _canSave {
    if (_nameController.text.trim().isEmpty) return false;
    return _rows.any((row) => row.keyController.text.trim().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Template' : 'New Template'),
      ),
      body: SafeArea(
        child: _step == 0 ? _buildTemplateDetails() : _buildFieldsStep(),
      ),
    );
  }

  Widget _buildTemplateDetails() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        Text(
          _isEditing ? 'Edit custom template' : 'Create custom template',
          style: vaultPageHeadingStyle(context),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the template name, icon, color, and fields used for new vault items.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(64),
            onTap: _pickIcon,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                shape: BoxShape.circle,
                border: Border.all(color: _colorForKey(_colorKey)),
              ),
              child: Icon(
                _iconForKey(_iconKey),
                color: _colorForKey(_colorKey),
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: InkWell(
            key: const ValueKey('custom-template-add-icon'),
            borderRadius: BorderRadius.circular(8),
            onTap: _pickIcon,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Add Icon',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Template Name',
            hintText: 'e.g. Car Details',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            hintText: 'Add a short description',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        const Text(
          'Category Color',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: _availableTemplateColors.map((option) {
            final selected = _colorKey == option.key;
            return InkWell(
              onTap: () => setState(() => _colorKey = option.key),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF6366F1)
                        : const Color(0xFFD1D5DB),
                    width: selected ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: option.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canContinue ? () => setState(() => _step = 1) : null,
            child: Text(_isEditing ? 'Edit fields' : 'Next'),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldsStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        Text(
          _isEditing ? 'Edit template fields' : 'Template fields',
          style: vaultPageHeadingStyle(context),
        ),
        const SizedBox(height: 4),
        Text(
          'Add the fields this custom item type should collect.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Fields',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _step = 0),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Details'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: row.keyController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Field key (example: Expiry date)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: row.valueType,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'text',
                          child: Text('String text'),
                        ),
                        DropdownMenuItem(
                          value: 'number',
                          child: Text('Number'),
                        ),
                        DropdownMenuItem(value: 'date', child: Text('Date')),
                        DropdownMenuItem(
                          value: 'password',
                          child: Text('Password / secret'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => row.valueType = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Value type',
                      ),
                    ),
                    if (_rows.length > 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _rows.removeAt(index).keyController.dispose();
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove field'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _rows.add(_FieldRow())),
            icon: const Icon(Icons.add),
            label: const Text('Add field'),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('custom-template-fields-save'),
            onPressed: _canSave ? _save : null,
            icon: const Icon(Icons.save_outlined),
            label: Text(_isEditing ? 'Save changes' : 'Save template'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickIcon() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    'Choose icon',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.92,
                        ),
                    itemCount: _availableTemplateIcons.length,
                    itemBuilder: (context, index) {
                      final option = _availableTemplateIcons[index];
                      final selected = _iconKey == option.key;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).pop(option.key),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFE0E7FF)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF6366F1)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                option.icon,
                                color: selected
                                    ? const Color(0xFF4F46E5)
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                option.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
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
      },
    );
    if (selected == null) return;
    setState(() => _iconKey = selected);
  }

  IconData _iconForKey(String key) {
    return _availableTemplateIcons
        .firstWhere(
          (option) => option.key == key,
          orElse: () => _availableTemplateIcons.first,
        )
        .icon;
  }

  Color _colorForKey(String key) {
    return _availableTemplateColors
        .firstWhere(
          (option) => option.key == key,
          orElse: () => _availableTemplateColors.first,
        )
        .color;
  }

  void _save() {
    final fields = _rows
        .where((row) => row.keyController.text.trim().isNotEmpty)
        .map(
          (row) => {
            'key': row.keyController.text.trim(),
            'valueType': row.valueType,
          },
        )
        .toList();

    Navigator.of(context).pop({
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'iconKey': _iconKey,
      'colorKey': _colorKey,
      'fields': fields,
    });
  }
}

class _FieldRow {
  _FieldRow({String keyText = '', this.valueType = 'text'})
    : keyController = TextEditingController(text: keyText);

  final TextEditingController keyController;
  String valueType;
}

class _TemplateIconOption {
  const _TemplateIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const List<_TemplateIconOption> _availableTemplateIcons = [
  _TemplateIconOption(key: 'lock', label: 'Lock', icon: Icons.lock_outline),
  _TemplateIconOption(
    key: 'note',
    label: 'Note',
    icon: Icons.sticky_note_2_outlined,
  ),
  _TemplateIconOption(key: 'id', label: 'Identity', icon: Icons.badge_outlined),
  _TemplateIconOption(
    key: 'wallet',
    label: 'Finance',
    icon: Icons.account_balance_wallet_outlined,
  ),
  _TemplateIconOption(
    key: 'folder',
    label: 'Documents',
    icon: Icons.folder_outlined,
  ),
  _TemplateIconOption(
    key: 'heart',
    label: 'Health',
    icon: Icons.favorite_outline,
  ),
  _TemplateIconOption(key: 'star', label: 'Favorite', icon: Icons.star_outline),
  _TemplateIconOption(
    key: 'spark',
    label: 'Custom',
    icon: Icons.auto_awesome_outlined,
  ),
  _TemplateIconOption(key: 'key', label: 'Key', icon: Icons.key_outlined),
  _TemplateIconOption(
    key: 'password',
    label: 'Password',
    icon: Icons.password_outlined,
  ),
  _TemplateIconOption(
    key: 'credit_card',
    label: 'Card',
    icon: Icons.credit_card,
  ),
  _TemplateIconOption(
    key: 'bank',
    label: 'Bank',
    icon: Icons.account_balance_outlined,
  ),
  _TemplateIconOption(
    key: 'receipt',
    label: 'Receipt',
    icon: Icons.receipt_long_outlined,
  ),
  _TemplateIconOption(
    key: 'car',
    label: 'Vehicle',
    icon: Icons.directions_car_outlined,
  ),
  _TemplateIconOption(key: 'home', label: 'Home', icon: Icons.home_outlined),
  _TemplateIconOption(key: 'work', label: 'Work', icon: Icons.work_outline),
  _TemplateIconOption(
    key: 'travel',
    label: 'Travel',
    icon: Icons.flight_takeoff_outlined,
  ),
  _TemplateIconOption(
    key: 'passport',
    label: 'Passport',
    icon: Icons.airplane_ticket_outlined,
  ),
  _TemplateIconOption(
    key: 'calendar',
    label: 'Date',
    icon: Icons.event_outlined,
  ),
  _TemplateIconOption(
    key: 'phone',
    label: 'Phone',
    icon: Icons.phone_iphone_outlined,
  ),
  _TemplateIconOption(
    key: 'email',
    label: 'Email',
    icon: Icons.alternate_email,
  ),
  _TemplateIconOption(key: 'wifi', label: 'Wi-Fi', icon: Icons.wifi_outlined),
  _TemplateIconOption(key: 'server', label: 'Server', icon: Icons.dns_outlined),
  _TemplateIconOption(key: 'code', label: 'Code', icon: Icons.code_outlined),
  _TemplateIconOption(
    key: 'database',
    label: 'Database',
    icon: Icons.storage_outlined,
  ),
  _TemplateIconOption(key: 'cloud', label: 'Cloud', icon: Icons.cloud_outlined),
  _TemplateIconOption(
    key: 'medical',
    label: 'Medical',
    icon: Icons.medical_services_outlined,
  ),
  _TemplateIconOption(key: 'pet', label: 'Pet', icon: Icons.pets_outlined),
  _TemplateIconOption(
    key: 'school',
    label: 'School',
    icon: Icons.school_outlined,
  ),
  _TemplateIconOption(
    key: 'shopping',
    label: 'Shopping',
    icon: Icons.shopping_bag_outlined,
  ),
  _TemplateIconOption(
    key: 'gift',
    label: 'Gift',
    icon: Icons.card_giftcard_outlined,
  ),
  _TemplateIconOption(key: 'photo', label: 'Photo', icon: Icons.photo_outlined),
  _TemplateIconOption(key: 'link', label: 'Link', icon: Icons.link_outlined),
];

class _TemplateColorOption {
  const _TemplateColorOption({required this.key, required this.color});

  final String key;
  final Color color;
}

const List<_TemplateColorOption> _availableTemplateColors = [
  _TemplateColorOption(key: 'purple', color: Color(0xFF8B5CF6)),
  _TemplateColorOption(key: 'indigo', color: Color(0xFF6366F1)),
  _TemplateColorOption(key: 'blue', color: Color(0xFF60A5FA)),
  _TemplateColorOption(key: 'sky', color: Color(0xFF38BDF8)),
  _TemplateColorOption(key: 'cyan', color: Color(0xFF22D3EE)),
  _TemplateColorOption(key: 'teal', color: Color(0xFF2DD4BF)),
  _TemplateColorOption(key: 'green', color: Color(0xFF4ADE80)),
  _TemplateColorOption(key: 'emerald', color: Color(0xFF10B981)),
  _TemplateColorOption(key: 'lime', color: Color(0xFFA3E635)),
  _TemplateColorOption(key: 'amber', color: Color(0xFFFBBF24)),
  _TemplateColorOption(key: 'yellow', color: Color(0xFFFDE047)),
  _TemplateColorOption(key: 'orange', color: Color(0xFFFB923C)),
  _TemplateColorOption(key: 'red', color: Color(0xFFF87171)),
  _TemplateColorOption(key: 'rose', color: Color(0xFFFB7185)),
  _TemplateColorOption(key: 'pink', color: Color(0xFFF472B6)),
  _TemplateColorOption(key: 'fuchsia', color: Color(0xFFE879F9)),
  _TemplateColorOption(key: 'slate', color: Color(0xFF64748B)),
  _TemplateColorOption(key: 'gray', color: Color(0xFF9CA3AF)),
];
