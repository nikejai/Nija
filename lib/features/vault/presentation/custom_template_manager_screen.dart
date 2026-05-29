part of 'vault_app_shell.dart';

class _CustomTemplateManagerScreen extends StatefulWidget {
  const _CustomTemplateManagerScreen({
    required this.initialDefinitions,
    required this.onCommit,
  });

  final List<Map<String, dynamic>> initialDefinitions;
  final Future<void> Function(List<Map<String, dynamic>> definitions) onCommit;

  @override
  State<_CustomTemplateManagerScreen> createState() =>
      _CustomTemplateManagerScreenState();
}

class _CustomTemplateManagerScreenState
    extends State<_CustomTemplateManagerScreen> {
  late final List<Map<String, dynamic>> _workingDefinitions;

  @override
  void initState() {
    super.initState();
    _workingDefinitions = widget.initialDefinitions
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom templates'),
        actions: [
          IconButton(
            key: const ValueKey('custom-template-add'),
            tooltip: 'Add custom template',
            onPressed: _addTemplate,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Custom templates', style: vaultPageHeadingStyle(context)),
                const SizedBox(height: 4),
                Text(
                  'Create reusable item types with your own fields.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _workingDefinitions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No custom templates yet.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _addTemplate,
                            icon: const Icon(Icons.add),
                            label: const Text('Add template'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: _workingDefinitions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final definition = _workingDefinitions[index];
                      final iconKey = definition['iconKey']?.toString();
                      final colorKey = definition['colorKey']?.toString();
                      final accent = _colorForCustomTemplateColorKey(colorKey);
                      final name = definition['name']?.toString() ?? 'Custom';
                      final fields =
                          (definition['fields'] as List<dynamic>? ??
                                  const <dynamic>[])
                              .length;
                      final colorScheme = Theme.of(context).colorScheme;
                      return Material(
                        color: colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          onTap: () => _editTemplate(index),
                          contentPadding: const EdgeInsets.fromLTRB(
                            12,
                            8,
                            8,
                            8,
                          ),
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _iconForCustomTemplateKey(iconKey),
                              color: accent,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '$fields fields',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editTemplate(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _confirmDeleteTemplate(index),
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
    );
  }

  Future<void> _addTemplate() async {
    final createdType = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const CreateCustomTypeScreen()),
    );
    if (!mounted || createdType == null) return;
    final name = createdType['name']?.toString().trim() ?? '';
    if (name.isEmpty) return;
    if (_hasTemplateNamed(name)) {
      _showDuplicateTemplateMessage();
      return;
    }
    setState(() => _workingDefinitions.add(createdType));
    await widget.onCommit(_snapshotDefinitions());
  }

  Future<void> _editTemplate(int index) async {
    final edited = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) =>
            CreateCustomTypeScreen(initialTemplate: _workingDefinitions[index]),
      ),
    );
    if (!mounted || edited == null) return;
    final editedName = edited['name']?.toString().trim() ?? '';
    if (editedName.isEmpty) return;
    if (_hasTemplateNamed(editedName, exceptIndex: index)) {
      _showDuplicateTemplateMessage();
      return;
    }
    setState(() => _workingDefinitions[index] = edited);
    await widget.onCommit(_snapshotDefinitions());
  }

  Future<void> _confirmDeleteTemplate(int index) async {
    final definition = _workingDefinitions[index];
    final name = definition['name']?.toString() ?? 'Custom';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.delete_outline,
                  size: 34,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Move to Trash?',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  '"$name" will be moved to trash.\nThis action can be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('Move to Trash'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || confirmed != true) return;
    setState(() => _workingDefinitions.removeAt(index));
    await widget.onCommit(_snapshotDefinitions());
  }

  List<Map<String, dynamic>> _snapshotDefinitions() {
    return _workingDefinitions
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  bool _hasTemplateNamed(String name, {int? exceptIndex}) {
    final normalized = name.toLowerCase();
    return _workingDefinitions.asMap().entries.any((entry) {
      if (entry.key == exceptIndex) return false;
      return (entry.value['name']?.toString().toLowerCase() ?? '') ==
          normalized;
    });
  }

  void _showDuplicateTemplateMessage() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.customTypeExists)));
  }
}
