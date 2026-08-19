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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom templates',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Reusable item types',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  key: const ValueKey('custom-template-add'),
                  onPressed: _addTemplate,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.onSurface,
                    foregroundColor: colorScheme.surface,
                    minimumSize: const Size(82, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 860,
                        minHeight: constraints.maxHeight - 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CustomTemplatePanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Custom templates',
                                  style: vaultPageHeadingStyle(context),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Create reusable item types with your own fields.',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_workingDefinitions.isEmpty)
                            _CustomTemplatePanel(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No custom templates yet.',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Add a template to create a custom vault category.',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  FilledButton.icon(
                                    onPressed: _addTemplate,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add template'),
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._workingDefinitions.asMap().entries.map((entry) {
                              final index = entry.key;
                              final definition = entry.value;
                              final iconKey = definition['iconKey']?.toString();
                              final colorKey = definition['colorKey']
                                  ?.toString();
                              final accent = _colorForCustomTemplateColorKey(
                                colorKey,
                              );
                              final name =
                                  definition['name']?.toString() ?? 'Custom';
                              final fields =
                                  (definition['fields'] as List<dynamic>? ??
                                          const <dynamic>[])
                                      .length;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _CustomTemplatePanel(
                                  padding: EdgeInsets.zero,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      onTap: () => _editTemplate(index),
                                      contentPadding: const EdgeInsets.fromLTRB(
                                        14,
                                        10,
                                        8,
                                        10,
                                      ),
                                      leading: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          _iconForCustomTemplateKey(iconKey),
                                          color: accent,
                                          size: 21,
                                        ),
                                      ),
                                      title: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w800,
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
                                            tooltip: 'Edit template',
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            onPressed: () =>
                                                _editTemplate(index),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete template',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            onPressed: () =>
                                                _confirmDeleteTemplate(index),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
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
    final confirmed = await showVaultConfirmSheet(
      context: context,
      title: 'Move to Trash?',
      message: '"$name" will be moved to trash.\nThis action can be undone.',
      confirmLabel: 'Move to Trash',
      destructive: true,
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

class _CustomTemplatePanel extends StatelessWidget {
  const _CustomTemplatePanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
