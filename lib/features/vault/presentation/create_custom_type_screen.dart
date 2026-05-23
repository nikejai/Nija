import 'package:flutter/material.dart';

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
      final fields =
          (initial['fields'] as List<dynamic>? ?? const <dynamic>[])
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
      appBar: AppBar(title: Text(_step == 0 ? 'New Template' : 'Template Fields')),
      body: SafeArea(child: _step == 0 ? _buildTemplateDetails() : _buildFieldsStep()),
    );
  }

  Widget _buildTemplateDetails() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(64),
            onTap: _pickIcon,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD9D6FE)),
              ),
              child: Icon(
                _iconForKey(_iconKey),
                color: const Color(0xFF6366F1),
                size: 34,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Add Icon',
            style: TextStyle(
              color: Color(0xFF6366F1),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Template Name',
            hintText: 'e.g. Car Details',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          children: _availableTemplateColors.map((option) {
            final selected = _colorKey == option.key;
            return InkWell(
              onTap: () => setState(() => _colorKey = option.key),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 32,
                height: 32,
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
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canContinue ? () => setState(() => _step = 1) : null,
            child: const Text('Next'),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldsStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('Back'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: const Text('Save'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Fields', style: Theme.of(context).textTheme.titleMedium),
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
                        color: const Color(0xFF171717),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'text', child: Text('String text')),
                        DropdownMenuItem(value: 'number', child: Text('Number')),
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
                      decoration: const InputDecoration(labelText: 'Value type'),
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
      ],
    );
  }

  Future<void> _pickIcon() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: _availableTemplateIcons.map((option) {
              return ListTile(
                leading: Icon(option.icon),
                title: Text(option.label),
                trailing:
                    _iconKey == option.key ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(option.key),
              );
            }).toList(),
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() => _iconKey = selected);
  }

  IconData _iconForKey(String key) {
    return _availableTemplateIcons
        .firstWhere((option) => option.key == key, orElse: () => _availableTemplateIcons.first)
        .icon;
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
  _TemplateIconOption(
    key: 'star',
    label: 'Favorite',
    icon: Icons.star_outline,
  ),
  _TemplateIconOption(
    key: 'spark',
    label: 'Custom',
    icon: Icons.auto_awesome_outlined,
  ),
];

class _TemplateColorOption {
  const _TemplateColorOption({required this.key, required this.color});

  final String key;
  final Color color;
}

const List<_TemplateColorOption> _availableTemplateColors = [
  _TemplateColorOption(key: 'purple', color: Color(0xFF8B5CF6)),
  _TemplateColorOption(key: 'blue', color: Color(0xFF60A5FA)),
  _TemplateColorOption(key: 'green', color: Color(0xFF4ADE80)),
  _TemplateColorOption(key: 'amber', color: Color(0xFFFBBF24)),
  _TemplateColorOption(key: 'orange', color: Color(0xFFFB923C)),
  _TemplateColorOption(key: 'red', color: Color(0xFFF87171)),
  _TemplateColorOption(key: 'gray', color: Color(0xFFE5E7EB)),
];
