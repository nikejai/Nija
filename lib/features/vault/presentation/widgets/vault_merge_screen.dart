import 'package:flutter/material.dart';
import 'package:nija/application/services/vault_merge_helper.dart';
import 'package:nija/domain/models/vault_payload.dart';

class VaultMergeScreen extends StatefulWidget {
  const VaultMergeScreen({
    super.key,
    required this.plan,
    required this.currentPayload,
    required this.importedPayload,
    required this.mergeHelper,
    this.importedSourceLabel = 'Imported vault',
  });

  final VaultMergePlan plan;
  final VaultPayload currentPayload;
  final VaultPayload importedPayload;
  final VaultMergeHelper mergeHelper;
  final String importedSourceLabel;

  @override
  State<VaultMergeScreen> createState() => _VaultMergeScreenState();
}

class _VaultMergeScreenState extends State<VaultMergeScreen> {
  late final Map<String, VaultMergeSource> _selections;
  late final Set<String> _expandedEntryKeys;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _selections = <String, VaultMergeSource>{
      for (final entry in widget.plan.entries)
        entry.key: entry.status == VaultMergeEntryStatus.importedOnly
            ? VaultMergeSource.imported
            : VaultMergeSource.current,
    };
    _expandedEntryKeys = widget.plan.entries
        .where((entry) => entry.needsResolution)
        .take(2)
        .map((entry) => entry.key)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = widget.plan.entries.where(_matchesFilter).toList();
    final unresolved = widget.plan.entries.where((entry) {
      final selected = _selections[entry.key];
      return entry.needsResolution && selected == null;
    }).length;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Review Conflicts',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _showMergeHelp,
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('all', 'All (${widget.plan.totalCount})'),
                      _filterChip(
                        'conflicts',
                        'Conflicts (${_trueConflictCount()})',
                      ),
                      _filterChip(
                        'deletions',
                        'Deletions (${_deletionReviewCount()})',
                      ),
                      _filterChip(
                        'passwords',
                        'Passwords (${_passwordCount()})',
                      ),
                      _filterChip('notes', 'Notes (${_kindCount('note')})'),
                      _filterChip('others', 'Others (${_otherCount()})'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _filter == 'conflicts'
                      ? 'Items changed in both vaults and need a version choice.'
                      : _filter == 'deletions'
                      ? 'Items missing from ${widget.importedSourceLabel.toLowerCase()}. Choose whether to keep or remove them.'
                      : 'Review all compared entries. Conflicts and deletions need a decision.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.plan.conflictCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${_trueConflictCount()} conflicts, ${_deletionReviewCount()} deletions, ${widget.plan.identicalCount} identical, ${_autoMergeCount()} automatic.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _MergeEntryCard(
                entry: filtered[index],
                selected: _selections[filtered[index].key],
                expanded: _expandedEntryKeys.contains(filtered[index].key),
                onToggleExpanded: () => _toggleExpanded(filtered[index].key),
                onSelected: (source) =>
                    setState(() => _selections[filtered[index].key] = source),
                onViewDifferences: () => _showEntryDifferences(filtered[index]),
                importedSourceLabel: widget.importedSourceLabel,
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            side: BorderSide(color: colorScheme.outline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => _selectAll(VaultMergeSource.current),
                          child: const Text('Accept all from current'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            side: BorderSide(color: colorScheme.outline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () =>
                              _selectAll(VaultMergeSource.imported),
                          child: Text(
                            'Accept all from ${_sourceActionLabel(widget.importedSourceLabel)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        disabledBackgroundColor:
                            colorScheme.surfaceContainerHighest,
                        disabledForegroundColor: colorScheme.onSurfaceVariant,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: unresolved == 0 ? _completeMerge : null,
                      child: Text(
                        unresolved == 0
                            ? 'Apply Merge'
                            : 'Resolve $unresolved items',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _filter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(VaultMergeEntry entry) {
    return switch (_filter) {
      'conflicts' => entry.status == VaultMergeEntryStatus.conflict,
      'deletions' => entry.status == VaultMergeEntryStatus.currentOnly,
      'passwords' => entry.kind == 'item' && _isPasswordEntry(entry),
      'notes' => entry.kind == 'note',
      'others' => entry.kind != 'note' && !_isPasswordEntry(entry),
      _ => true,
    };
  }

  int _trueConflictCount() {
    return widget.plan.entries
        .where((entry) => entry.status == VaultMergeEntryStatus.conflict)
        .length;
  }

  int _deletionReviewCount() {
    return widget.plan.entries
        .where((entry) => entry.status == VaultMergeEntryStatus.currentOnly)
        .length;
  }

  int _kindCount(String kind) {
    return widget.plan.entries.where((entry) => entry.kind == kind).length;
  }

  int _passwordCount() {
    return widget.plan.entries.where(_isPasswordEntry).length;
  }

  int _otherCount() {
    return widget.plan.entries
        .where((entry) => entry.kind != 'note' && !_isPasswordEntry(entry))
        .length;
  }

  int _autoMergeCount() {
    return widget.plan.entries
        .where(
          (entry) =>
              !entry.needsResolution &&
              entry.status != VaultMergeEntryStatus.identical,
        )
        .length;
  }

  bool _isPasswordEntry(VaultMergeEntry entry) {
    final normalized = '${entry.title} ${entry.type}'.toLowerCase();
    return normalized.contains('password') ||
        normalized.contains('login') ||
        normalized.contains('account') ||
        normalized.contains('wifi') ||
        normalized.contains('wi-fi');
  }

  void _toggleExpanded(String key) {
    setState(() {
      if (_expandedEntryKeys.contains(key)) {
        _expandedEntryKeys.remove(key);
      } else {
        _expandedEntryKeys.add(key);
      }
    });
  }

  void _selectAll(VaultMergeSource source) {
    setState(() {
      for (final entry in widget.plan.entries) {
        if (source == VaultMergeSource.current && entry.current == null) {
          _selections[entry.key] = VaultMergeSource.imported;
        } else if (source == VaultMergeSource.imported &&
            entry.imported == null) {
          _selections[entry.key] = VaultMergeSource.current;
        } else {
          _selections[entry.key] = source;
        }
      }
    });
  }

  void _completeMerge() {
    final merged = widget.mergeHelper.merge(
      current: widget.currentPayload,
      imported: widget.importedPayload,
      selections: _selections,
    );
    Navigator.of(context).pop(merged);
  }

  Future<void> _showMergeHelp() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vault merge'),
        content: const Text(
          'Nothing is changed until you tap Apply Merge. Imported-only entries '
          'are added automatically. Conflicts and possible deletions need a '
          'version choice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEntryDifferences(VaultMergeEntry entry) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.84,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (context, controller) {
          final colorScheme = Theme.of(context).colorScheme;
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                entry.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Compare the current vault version with ${widget.importedSourceLabel.toLowerCase()}.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _MergeVersionPreview(
                title: 'Current vault',
                entry: entry.current,
                kind: entry.kind,
              ),
              const SizedBox(height: 12),
              _MergeVersionPreview(
                title: widget.importedSourceLabel,
                entry: entry.imported,
                kind: entry.kind,
              ),
            ],
          );
        },
      ),
    );
  }

  String _sourceActionLabel(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized == 'cloud backup') return 'cloud';
    if (normalized == 'imported vault') return 'imported';
    return normalized.isEmpty ? 'imported' : normalized;
  }
}

class _MergeEntryCard extends StatelessWidget {
  const _MergeEntryCard({
    required this.entry,
    required this.selected,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSelected,
    required this.onViewDifferences,
    required this.importedSourceLabel,
  });

  final VaultMergeEntry entry;
  final VaultMergeSource? selected;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<VaultMergeSource> onSelected;
  final VoidCallback onViewDifferences;
  final String importedSourceLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 8, 10, expanded ? 8 : 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onToggleExpanded,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _accentForMergeEntry(entry),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      _iconForMergeEntry(entry),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${entry.type} • ${_statusLabel(entry.status)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
              if (entry.current != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MergeChoiceRow(
                    title: 'Current Vault',
                    subtitle: _metadataLine(entry.current!),
                    selected: selected == VaultMergeSource.current,
                    onTap: () => onSelected(VaultMergeSource.current),
                  ),
                ),
              if (entry.imported != null)
                _MergeChoiceRow(
                  title: importedSourceLabel,
                  subtitle: _metadataLine(entry.imported!),
                  selected: selected == VaultMergeSource.imported,
                  onTap: () => onSelected(VaultMergeSource.imported),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onViewDifferences,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 2, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'View differences',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForMergeEntry(VaultMergeEntry entry) {
    if (entry.kind == 'note') return Icons.description_outlined;
    final normalized = entry.type.toLowerCase();
    if (normalized.contains('password') || normalized.contains('login')) {
      return Icons.lock_outline;
    }
    if (normalized.contains('bank') || normalized.contains('finance')) {
      return Icons.account_balance_outlined;
    }
    return Icons.shield_outlined;
  }

  Color _accentForMergeEntry(VaultMergeEntry entry) {
    if (entry.kind == 'note') return const Color(0xFFEAB308);
    final normalized = entry.type.toLowerCase();
    if (normalized.contains('bank') || normalized.contains('finance')) {
      return const Color(0xFF22C55E);
    }
    if (normalized.contains('password') || normalized.contains('login')) {
      return const Color(0xFF3B82F6);
    }
    return const Color(0xFFEF4444);
  }

  String _statusLabel(VaultMergeEntryStatus status) {
    return switch (status) {
      VaultMergeEntryStatus.identical => 'Identical',
      VaultMergeEntryStatus.currentOnly => 'Only in current',
      VaultMergeEntryStatus.importedOnly => 'Only in imported',
      VaultMergeEntryStatus.conflict => 'Updated in both',
    };
  }

  String _metadataLine(Map<String, dynamic> entry) {
    final version = entry['version']?.toString();
    final updatedAt = entry['updatedAt']?.toString();
    final device = entry['updatedByDevice']?.toString();
    final parts = <String>[
      if (version != null && version.isNotEmpty) 'v$version',
      if (updatedAt != null && updatedAt.isNotEmpty) updatedAt,
      if (device != null && device.isNotEmpty) device,
    ];
    return parts.isEmpty ? 'No metadata' : parts.join(' • ');
  }
}

class _MergeChoiceRow extends StatelessWidget {
  const _MergeChoiceRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = selected
        ? colorScheme.primary.withValues(alpha: 0.1)
        : colorScheme.surface;
    final borderColor = selected
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final foregroundColor = selected
        ? colorScheme.onSurface
        : colorScheme.onSurface;
    final subtitleColor = selected
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.16),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: foregroundColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (selected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Selected',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? colorScheme.primary : colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, color: colorScheme.onPrimary, size: 14)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MergeVersionPreview extends StatelessWidget {
  const _MergeVersionPreview({
    required this.title,
    required this.entry,
    required this.kind,
  });

  final String title;
  final Map<String, dynamic>? entry;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final data = entry;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: data == null
            ? _MissingVersionCard(title: title)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (kind == 'note')
                    _MergeNotePreview(note: data)
                  else
                    _MergeItemPreview(item: data),
                ],
              ),
      ),
    );
  }
}

class _MissingVersionCard extends StatelessWidget {
  const _MissingVersionCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.remove_circle_outline,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Not present in this vault version.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MergeItemPreview extends StatelessWidget {
  const _MergeItemPreview({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final type = item['type']?.toString().trim().isNotEmpty == true
        ? item['type'].toString().trim()
        : 'Item';
    final title = item['title']?.toString().trim().isNotEmpty == true
        ? item['title'].toString().trim()
        : 'Untitled';
    final fields = (item['fields'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((field) => Map<String, dynamic>.from(field))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.lock_outline,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (fields.isEmpty)
          Text(
            'No fields',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: List.generate(fields.length, (index) {
                final field = fields[index];
                final label =
                    field['label']?.toString().trim().isNotEmpty == true
                    ? field['label'].toString().trim()
                    : 'Field';
                final value = field['value']?.toString() ?? '';
                final sensitive = field['sensitive'] == true;
                return Column(
                  children: [
                    if (index > 0)
                      Divider(height: 1, color: colorScheme.outlineVariant),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (sensitive) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.visibility_outlined,
                                        size: 13,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  value.isEmpty ? 'Empty' : value,
                                  style: TextStyle(
                                    color: value.isEmpty
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        const SizedBox(height: 12),
        _MergeMetadataLine(label: 'Category', value: type),
        _MergeMetadataLine(
          label: 'Updated',
          value: _mergePreviewValue(item, 'updatedAt', 'updated'),
        ),
        _MergeMetadataLine(
          label: 'Device',
          value: _mergePreviewValue(item, 'updatedByDevice', 'deviceId'),
        ),
      ],
    );
  }
}

class _MergeNotePreview extends StatelessWidget {
  const _MergeNotePreview({required this.note});

  final Map<String, dynamic> note;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = note['title']?.toString().trim().isNotEmpty == true
        ? note['title'].toString().trim()
        : 'Untitled note';
    final body = _notePlainText(note).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.description_outlined,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: SelectableText(
            body.isEmpty ? 'Empty note' : body,
            style: TextStyle(
              color: body.isEmpty
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MergeMetadataLine(
          label: 'Updated',
          value: _mergePreviewValue(note, 'updatedAt', 'updated'),
        ),
        _MergeMetadataLine(
          label: 'Device',
          value: _mergePreviewValue(note, 'updatedByDevice', 'deviceId'),
        ),
      ],
    );
  }
}

class _MergeMetadataLine extends StatelessWidget {
  const _MergeMetadataLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
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
      ),
    );
  }
}

String _mergePreviewValue(
  Map<String, dynamic> entry,
  String primaryKey,
  String fallbackKey,
) {
  final primary = entry[primaryKey]?.toString().trim() ?? '';
  if (primary.isNotEmpty) return primary;
  return entry[fallbackKey]?.toString().trim() ?? '';
}

String _notePlainText(Map<String, dynamic> note) {
  final delta = note['delta'];
  if (delta is List) {
    final buffer = StringBuffer();
    for (final op in delta) {
      if (op is Map) {
        final insert = op['insert'];
        if (insert is String) buffer.write(insert);
      }
    }
    final value = buffer.toString();
    if (value.trim().isNotEmpty) return value;
  }
  return note['preview']?.toString() ?? '';
}
