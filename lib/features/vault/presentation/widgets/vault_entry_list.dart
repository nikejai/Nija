import 'package:flutter/material.dart';

enum VaultEntryTrailingMode { none, chevron, more }

class VaultListEntry {
  const VaultListEntry({
    required this.entry,
    required this.kind,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.updated,
    required this.pinned,
    this.icon,
    this.color,
  });

  final Map<String, dynamic> entry;
  final String kind;
  final String type;
  final String title;
  final String subtitle;
  final String updated;
  final bool pinned;
  final IconData? icon;
  final Color? color;
}

abstract class VaultListEntryAdapter {
  const VaultListEntryAdapter();

  bool canAdapt(Map<String, dynamic> row);

  VaultListEntry adapt(Map<String, dynamic> row);

  Map<String, dynamic> entryFrom(Map<String, dynamic> row) =>
      row['entry'] as Map<String, dynamic>;
}

class VaultItemListEntryAdapter extends VaultListEntryAdapter {
  const VaultItemListEntryAdapter({this.iconForType, this.colorForType});

  final IconData Function(String type)? iconForType;
  final Color Function(String type)? colorForType;

  @override
  bool canAdapt(Map<String, dynamic> row) =>
      (row['kind']?.toString() ?? 'item') == 'item';

  @override
  VaultListEntry adapt(Map<String, dynamic> row) {
    final entry = entryFrom(row);
    return VaultListEntry(
      entry: entry,
      kind: 'item',
      type: entry['type']?.toString() ?? 'Unknown',
      title: entry['title']?.toString() ?? '',
      subtitle: entry['subtitle']?.toString() ?? '',
      updated:
          row['updatedLabel']?.toString() ??
          entry['updated']?.toString() ??
          'Now',
      pinned: entry['pinned'] == true,
      icon: iconForType?.call(entry['type']?.toString() ?? 'Unknown'),
      color: colorForType?.call(entry['type']?.toString() ?? 'Unknown'),
    );
  }
}

class VaultNoteListEntryAdapter extends VaultListEntryAdapter {
  const VaultNoteListEntryAdapter();

  @override
  bool canAdapt(Map<String, dynamic> row) => row['kind']?.toString() == 'note';

  @override
  VaultListEntry adapt(Map<String, dynamic> row) {
    final entry = entryFrom(row);
    return VaultListEntry(
      entry: entry,
      kind: 'note',
      type: 'Notes',
      title: entry['title']?.toString() ?? '',
      subtitle: entry['preview']?.toString() ?? '',
      updated:
          row['updatedLabel']?.toString() ??
          entry['updated']?.toString() ??
          'Now',
      pinned: entry['pinned'] == true,
      icon: Icons.description_outlined,
      color: const Color(0xFFA78BFA),
    );
  }
}

class VaultDocumentListEntryAdapter extends VaultListEntryAdapter {
  const VaultDocumentListEntryAdapter();

  @override
  bool canAdapt(Map<String, dynamic> row) {
    final entry = entryFrom(row);
    return row['kind']?.toString() == 'item' &&
        (entry['type']?.toString() == 'Documents' ||
            entry['document'] is Map ||
            entry['documentFileName'] != null);
  }

  @override
  VaultListEntry adapt(Map<String, dynamic> row) {
    final entry = entryFrom(row);
    final document = entry['document'] is Map
        ? Map<String, dynamic>.from(entry['document'] as Map)
        : const <String, dynamic>{};
    final extension =
        entry['documentExtension']?.toString().trim().toUpperCase() ??
        document['extension']?.toString().trim().toUpperCase() ??
        'FILE';
    final sizeBytes = _documentSizeBytes(entry, document);
    final updated =
        row['updatedLabel']?.toString() ??
        entry['updated']?.toString() ??
        'Now';
    return VaultListEntry(
      entry: entry,
      kind: 'item',
      type: extension.isEmpty ? 'FILE' : extension,
      title: entry['title']?.toString().trim().isNotEmpty == true
          ? entry['title'].toString()
          : entry['documentFileName']?.toString() ??
                document['fileName']?.toString() ??
                'Document',
      subtitle: entry['subtitle']?.toString() ?? '',
      updated: '$updated · ${_formatDocumentBytes(sizeBytes)}',
      pinned: entry['pinned'] == true,
      icon: Icons.insert_drive_file_outlined,
      color: const Color(0xFFFB7185),
    );
  }

  int _documentSizeBytes(
    Map<String, dynamic> entry,
    Map<String, dynamic> document,
  ) {
    final raw = entry['documentSizeBytes'] ?? document['sizeBytes'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }
}

class VaultEntryList extends StatelessWidget {
  const VaultEntryList({
    super.key,
    required this.rows,
    required this.adapters,
    required this.keyForRow,
    required this.onTap,
    required this.onLongPress,
    this.onMoreTap,
    this.selectionMode = false,
    this.selectedKeys = const <String>{},
    this.trailingMode = VaultEntryTrailingMode.more,
    this.forceFavoriteIndicator = false,
    this.shrinkWrap = false,
    this.physics,
    this.separatorBuilder,
    this.iconAlpha = 0.28,
    this.rowPadding = const EdgeInsets.fromLTRB(10, 10, 8, 10),
  });

  final List<Map<String, dynamic>> rows;
  final List<VaultListEntryAdapter> adapters;
  final String Function(Map<String, dynamic> row) keyForRow;
  final void Function(Map<String, dynamic> row) onTap;
  final void Function(Map<String, dynamic> row) onLongPress;
  final void Function(Map<String, dynamic> row)? onMoreTap;
  final bool selectionMode;
  final Set<String> selectedKeys;
  final VaultEntryTrailingMode trailingMode;
  final bool forceFavoriteIndicator;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final IndexedWidgetBuilder? separatorBuilder;
  final double iconAlpha;
  final EdgeInsetsGeometry rowPadding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: rows.length,
      shrinkWrap: shrinkWrap,
      physics: physics,
      separatorBuilder:
          separatorBuilder ?? (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final row = rows[index];
        final listEntry = _adapt(row);
        final selected = selectedKeys.contains(keyForRow(row));
        return _VaultEntryTile(
          entry: listEntry,
          selected: selected,
          selectionMode: selectionMode,
          trailingMode: trailingMode,
          forceFavoriteIndicator: forceFavoriteIndicator,
          iconAlpha: iconAlpha,
          padding: rowPadding,
          onTap: () => onTap(row),
          onLongPress: () => onLongPress(row),
          onMoreTap: onMoreTap == null ? null : () => onMoreTap!(row),
        );
      },
    );
  }

  VaultListEntry _adapt(Map<String, dynamic> row) {
    for (final adapter in adapters) {
      if (adapter.canAdapt(row)) return adapter.adapt(row);
    }
    return const VaultItemListEntryAdapter().adapt(row);
  }
}

class _VaultEntryTile extends StatelessWidget {
  const _VaultEntryTile({
    required this.entry,
    required this.selected,
    required this.selectionMode,
    required this.trailingMode,
    required this.forceFavoriteIndicator,
    required this.iconAlpha,
    required this.padding,
    required this.onTap,
    required this.onLongPress,
    this.onMoreTap,
  });

  final VaultListEntry entry;
  final bool selected;
  final bool selectionMode;
  final VaultEntryTrailingMode trailingMode;
  final bool forceFavoriteIndicator;
  final double iconAlpha;
  final EdgeInsetsGeometry padding;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    const borderRadius = 12.0;
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final metaStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontSize: 12,
    );
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              if (selectionMode)
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF9CA3AF),
                )
              else
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: (entry.color ?? _colorForVaultEntryType(entry.type))
                        .withValues(alpha: iconAlpha),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    entry.icon ?? _iconForVaultEntryType(entry.type),
                    color: entry.color ?? _colorForVaultEntryType(entry.type),
                    size: 16,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text('${entry.type} · ${entry.updated}', style: metaStyle),
                    if (entry.subtitle.isNotEmpty)
                      Text(
                        entry.subtitle,
                        style: metaStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (!selectionMode && (entry.pinned || forceFavoriteIndicator))
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                ),
              _buildTrailing(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    switch (trailingMode) {
      case VaultEntryTrailingMode.none:
        return const SizedBox.shrink();
      case VaultEntryTrailingMode.chevron:
        return Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 18,
        );
      case VaultEntryTrailingMode.more:
        return IconButton(
          onPressed: onMoreTap,
          icon: Icon(
            Icons.more_vert,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 18,
          ),
        );
    }
  }
}

IconData _iconForVaultEntryType(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('note')) return Icons.description_outlined;
  if (normalized.contains('password') || normalized.contains('login')) {
    return Icons.lock_outline;
  }
  if (normalized.contains('ident')) return Icons.badge_outlined;
  if (normalized.contains('finan') || normalized.contains('bank')) {
    return Icons.account_balance_wallet_outlined;
  }
  if (normalized.contains('document')) return Icons.folder_outlined;
  if (normalized.contains('health')) return Icons.favorite_outline;
  return Icons.shield_outlined;
}

Color _colorForVaultEntryType(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('note')) return const Color(0xFFA78BFA);
  if (normalized.contains('password') || normalized.contains('login')) {
    return const Color(0xFF60A5FA);
  }
  if (normalized.contains('ident')) return const Color(0xFF34D399);
  if (normalized.contains('finan') || normalized.contains('bank')) {
    return const Color(0xFFFBBF24);
  }
  if (normalized.contains('document')) return const Color(0xFFFB923C);
  if (normalized.contains('health')) return const Color(0xFFF472B6);
  return const Color(0xFF93C5FD);
}

String _formatDocumentBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}
