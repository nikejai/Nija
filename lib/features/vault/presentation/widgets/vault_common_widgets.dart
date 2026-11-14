part of '../vault_app_shell.dart';

class _EntryMetadataPanel extends StatelessWidget {
  const _EntryMetadataPanel({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _EntryMetadataLine(
            label: 'Created',
            value: _entryCreatedLabel(entry),
          ),
          const SizedBox(height: 6),
          _EntryMetadataLine(
            label: 'Modified',
            value: _entryModifiedLabel(entry),
          ),
          const SizedBox(height: 6),
          _EntryMetadataLine(label: 'Device', value: _entryDeviceLabel(entry)),
        ],
      ),
    );
  }
}

class _EntryMetadataLine extends StatelessWidget {
  const _EntryMetadataLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

String _entryCreatedLabel(Map<String, dynamic> entry) {
  final value =
      entry['createdAt'] ?? entry['created_at'] ?? entry['documentUploadedAt'];
  return _formatEntryTimestamp(value, fallback: 'Unknown');
}

String _entryModifiedLabel(Map<String, dynamic> entry) {
  final activityAt = vaultEntryActivityAt(entry);
  if (activityAt != null) {
    return _formatEntryTimestamp(
      activityAt.toIso8601String(),
      fallback: 'Unknown',
    );
  }
  final legacy = entry['updated']?.toString().trim() ?? '';
  if (legacy.isNotEmpty && legacy.toLowerCase() != 'now') {
    return legacy;
  }
  return 'Unknown';
}

String _entryDeviceLabel(Map<String, dynamic> entry) {
  final label = entry['updatedByDevice']?.toString().trim() ?? '';
  final id = entry['deviceId']?.toString().trim() ?? '';
  if (label.isNotEmpty && id.isNotEmpty) {
    return '$label · ${_shortDeviceId(id)}';
  }
  if (label.isNotEmpty) return label;
  if (id.isNotEmpty) return _shortDeviceId(id);
  return 'Unknown';
}

String _shortDeviceId(String id) {
  if (id.length <= 8) return id;
  return id.substring(0, 8);
}

String _formatEntryTimestamp(Object? raw, {required String fallback}) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return fallback;
  if (value.toLowerCase() == 'now') return 'Now';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AllItemsTypeChip extends StatelessWidget {
  const _AllItemsTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 11,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: vaultPageHeadingStyle(context)),
        const SizedBox(height: 2),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

IconData _iconForHomeType(String type) {
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

Color _colorForHomeType(String type) {
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

class _HomeTypeCard extends StatelessWidget {
  const _HomeTypeCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const borderRadius = 14.0;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
}

class _AllItemsSelectionActionBar extends StatelessWidget {
  const _AllItemsSelectionActionBar({
    required this.onFavorite,
    required this.onDelete,
    required this.onMore,
  });

  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          _SelectionActionNavItem(
            key: const ValueKey('selection-action-favorite'),
            icon: Icons.star_outline,
            label: 'Favorite',
            onTap: onFavorite,
          ),
          _SelectionActionNavItem(
            key: const ValueKey('selection-action-delete'),
            icon: Icons.delete_outline,
            label: 'Delete',
            onTap: onDelete,
          ),
          _SelectionActionNavItem(
            key: const ValueKey('selection-action-more'),
            icon: Icons.more_horiz,
            label: 'More',
            onTap: onMore,
          ),
        ],
      ),
    );
  }
}

/// Desktop/tablet presentation for the existing All Items data and actions.
/// Mobile intentionally continues to use [VaultEntryList].

class _SelectionActionNavItem extends StatelessWidget {
  const _SelectionActionNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllItemsFilterState {
  const _AllItemsFilterState({
    required this.search,
    required this.selectedTypes,
    required this.favoritesOnly,
    required this.dateRange,
  });

  final String search;
  final Set<String> selectedTypes;
  final bool favoritesOnly;
  final String dateRange;
}

class _AllItemsFiltersOverlay extends StatefulWidget {
  const _AllItemsFiltersOverlay({
    required this.initialState,
    required this.typeOptions,
  });

  final _AllItemsFilterState initialState;
  final List<String> typeOptions;

  @override
  State<_AllItemsFiltersOverlay> createState() =>
      _AllItemsFiltersOverlayState();
}

class _AllItemsFiltersOverlayState extends State<_AllItemsFiltersOverlay> {
  late final TextEditingController _searchController;
  late Set<String> _selectedTypes;
  late bool _favoritesOnly;
  late String _dateRange;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialState.search);
    _searchController.addListener(() => setState(() {}));
    _selectedTypes = {...widget.initialState.selectedTypes};
    _favoritesOnly = widget.initialState.favoritesOnly;
    _dateRange = widget.initialState.dateRange;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: SizedBox.expand(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _reset,
                          child: const Text('Reset'),
                        ),
                      ),
                    ),
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _apply,
                          child: const Text('Done'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [
                    _sectionTitle('Search'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search all items...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Type'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.typeOptions.map((type) {
                        final selected = _selectedTypes.contains(type);
                        return FilterChip(
                          label: Text(type),
                          selected: selected,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (_) {
                            setState(() {
                              if (selected) {
                                _selectedTypes.remove(type);
                              } else {
                                _selectedTypes.add(type);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    _filterRow(
                      label: 'Favorites',
                      trailing: Switch(
                        value: _favoritesOnly,
                        onChanged: (value) =>
                            setState(() => _favoritesOnly = value),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle('Date Modified'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                            ('any', 'Anytime'),
                            ('today', 'Today'),
                            ('last_7_days', 'Last 7 Days'),
                            ('last_30_days', 'Last 30 Days'),
                          ].map((row) {
                            final selected = row.$1 == _dateRange;
                            return ChoiceChip(
                              label: Text(row.$2),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _dateRange = row.$1),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 18),
                    _filterRow(
                      label: 'Active Filters',
                      value:
                          '${(_searchController.text.trim().isNotEmpty ? 1 : 0) + _selectedTypes.length + (_favoritesOnly ? 1 : 0) + (_dateRange == 'any' ? 0 : 1)}',
                    ),
                    const SizedBox(height: 8),
                    if (_activeFilterChips().isEmpty)
                      Text(
                        'No active filters',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _activeFilterChips().map((chip) {
                          return InputChip(
                            label: Text(chip.label),
                            onDeleted: () => _removeActiveFilter(chip),
                          );
                        }).toList(),
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

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _filterRow({required String label, String? value, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (value != null)
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ?trailing,
        ],
      ),
    );
  }

  void _reset() {
    setState(() {
      _searchController.clear();
      _selectedTypes = <String>{};
      _favoritesOnly = false;
      _dateRange = 'any';
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      _AllItemsFilterState(
        search: _searchController.text,
        selectedTypes: _selectedTypes,
        favoritesOnly: _favoritesOnly,
        dateRange: _dateRange,
      ),
    );
  }

  List<_ActiveFilterChip> _activeFilterChips() {
    final chips = <_ActiveFilterChip>[];
    final search = _searchController.text.trim();
    if (search.isNotEmpty) {
      chips.add(_ActiveFilterChip(key: 'search', label: 'Search: $search'));
    }
    for (final type in _selectedTypes.toList()..sort()) {
      chips.add(_ActiveFilterChip(key: 'type:$type', label: type));
    }
    if (_favoritesOnly) {
      chips.add(const _ActiveFilterChip(key: 'favorites', label: 'Favorites'));
    }
    if (_dateRange != 'any') {
      chips.add(
        _ActiveFilterChip(
          key: 'date',
          label: switch (_dateRange) {
            'today' => 'Today',
            'last_7_days' => 'Last 7 Days',
            'last_30_days' => 'Last 30 Days',
            _ => 'Date',
          },
        ),
      );
    }
    return chips;
  }

  void _removeActiveFilter(_ActiveFilterChip chip) {
    setState(() {
      if (chip.key == 'search') {
        _searchController.clear();
        return;
      }
      if (chip.key.startsWith('type:')) {
        final type = chip.key.substring('type:'.length);
        _selectedTypes.remove(type);
        return;
      }
      if (chip.key == 'favorites') {
        _favoritesOnly = false;
        return;
      }
      if (chip.key == 'date') {
        _dateRange = 'any';
      }
    });
  }
}

class _ActiveFilterChip {
  const _ActiveFilterChip({required this.key, required this.label});

  final String key;
  final String label;
}
