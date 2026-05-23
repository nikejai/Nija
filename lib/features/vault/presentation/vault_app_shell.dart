import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_features.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/security/encrypted_share_codec.dart';
import '../../../core/security/secure_clipboard.dart';
import '../../../infrastructure/adapters/secret_share_portability.dart';
import '../../../infrastructure/adapters/secret_share_portability_base.dart';
import 'add_vault_item_screen.dart';
import 'create_custom_type_screen.dart';
import 'note_editor_screen.dart';

typedef BiometricChanged = void Function(bool enabled);
typedef LanguageModeChanged = void Function(String mode);
typedef RotateMasterPassword =
    Future<void> Function({
      required String currentPassword,
      required String newPassword,
    });
typedef RotateRecoveryPhrase =
    Future<void> Function({
      required String currentRecoveryPhrase,
      required String newRecoveryPhrase,
    });
typedef PersistVaultData =
    Future<void> Function({
      required List<Map<String, dynamic>> items,
      required List<Map<String, dynamic>> notes,
      required List<Map<String, dynamic>> customTypeDefinitions,
    });
typedef VaultFileAction = Future<void> Function();
typedef CloudBackupAction = Future<void> Function();
typedef CloudBackupAccountRead = Future<String?> Function();
typedef CloudBackupAccountChange = Future<bool> Function();

class VaultAppShell extends StatefulWidget {
  const VaultAppShell({
    super.key,
    this.activeVaultName = 'vault.nija',
    this.vaultSizeBytes = 0,
    required this.recoveryWords,
    required this.initialItems,
    required this.initialNotes,
    required this.initialCustomTypeDefinitions,
    required this.languageMode,
    required this.onLanguageModeChanged,
    required this.biometricEnabled,
    required this.onBiometricChanged,
    required this.onPersistVaultData,
    required this.onRotateMasterPassword,
    required this.onRotateRecoveryPhrase,
    required this.onLockNow,
    required this.onExportVault,
    required this.onImportVault,
    required this.onBackupToCloud,
    required this.onRestoreFromCloud,
    required this.onReadCloudBackupAccount,
    required this.onChangeCloudBackupAccount,
  });

  final List<String> recoveryWords;
  final String activeVaultName;
  final int vaultSizeBytes;
  final List<Map<String, dynamic>> initialItems;
  final List<Map<String, dynamic>> initialNotes;
  final List<Map<String, dynamic>> initialCustomTypeDefinitions;
  final String languageMode;
  final LanguageModeChanged onLanguageModeChanged;
  final bool biometricEnabled;
  final BiometricChanged onBiometricChanged;
  final PersistVaultData onPersistVaultData;
  final RotateMasterPassword onRotateMasterPassword;
  final RotateRecoveryPhrase onRotateRecoveryPhrase;
  final VoidCallback onLockNow;
  final VaultFileAction onExportVault;
  final VaultFileAction onImportVault;
  final CloudBackupAction onBackupToCloud;
  final CloudBackupAction onRestoreFromCloud;
  final CloudBackupAccountRead onReadCloudBackupAccount;
  final CloudBackupAccountChange onChangeCloudBackupAccount;

  @override
  State<VaultAppShell> createState() => _VaultAppShellState();
}

class _VaultAppShellState extends State<VaultAppShell> {
  static const String _encryptedShareExtension = '.nijas';
  static const String _prefsKeyVaultSort = 'nija_pref_vault_sort_v1';
  static const String _prefsKeyNotesSort = 'nija_pref_notes_sort_v1';
  static const String _prefsKeyCloudBackupEnabled =
      'nija_pref_cloud_backup_enabled_v1';
  static const String _prefsKeyCloudBackupAuto =
      'nija_pref_cloud_backup_auto_v1';
  static const String _prefsKeyCloudBackupFrequency =
      'nija_pref_cloud_backup_frequency_v1';
  static const String _prefsKeyCloudBackupLastAt =
      'nija_pref_cloud_backup_last_at_v1';
  final _clipboard = SecureClipboard();
  final _encryptedShareCodec = EncryptedShareCodec();
  final SecretSharePortabilityAdapter _secretSharePortability =
      SecretSharePortabilityAdapterImpl();
  int _tabIndex = 0;
  String _query = '';
  String _notesQuery = '';
  String _allItemsQuery = '';
  String _allItemsFilterSearch = '';
  bool _notesFiltersExpanded = false;
  String _vaultSort = 'last_accessed';
  String _notesSort = 'last_accessed';
  String _vaultFilterType = 'all';
  String _notesFilterTag = 'all';
  String _vaultPinFilter = 'all';
  String _notesPinFilter = 'all';
  String _allItemsTypeFilter = 'all';
  Set<String> _allItemsFilterTypes = <String>{};
  bool _allItemsFilterFavoritesOnly = false;
  String _allItemsFilterDateRange = 'any';
  bool _cloudBackupEnabled = false;
  bool _cloudBackupAutoEnabled = false;
  String _cloudBackupFrequency = 'daily';
  int _cloudBackupLastAtEpochMs = 0;
  String _cloudBackupAccountLabel = 'Not connected';
  bool _vaultSelectionMode = false;
  bool _notesSelectionMode = false;
  bool _allItemsSelectionMode = false;
  final Set<String> _selectedVaultItemIds = <String>{};
  final Set<String> _selectedNoteIds = <String>{};
  final Set<String> _selectedAllItemsKeys = <String>{};
  late final List<Map<String, dynamic>> _customTypeDefinitions;
  late final List<Map<String, dynamic>> _items;
  late final List<Map<String, dynamic>> _notes;

  List<_IndexedEntry> _lastDeletedAllItems = <_IndexedEntry>[];
  Map<String, bool> _lastPinnedStateItemById = <String, bool>{};
  Map<String, bool> _lastPinnedStateNoteById = <String, bool>{};
  DateTime? _lastBackOnDashboardAt;

  @override
  void initState() {
    super.initState();
    _customTypeDefinitions = widget.initialCustomTypeDefinitions
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    _items = widget.initialItems
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    _notes = widget.initialNotes
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    if (_notes.isEmpty) {
      _notes.add(_buildRecoveryPhraseNote());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _persistVaultData();
      });
    }
    unawaited(_restoreSortPreferences());
    unawaited(_restoreCloudBackupPreference());
    unawaited(_refreshCloudBackupAccountLabel());
  }

  @override
  void dispose() {
    _clipboard.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildRecoveryPhraseNote() {
    final lines = <String>[
      'Recovery phrase',
      '',
      widget.recoveryWords.join(' '),
      '',
      'Keep this phrase offline and private.',
    ];
    final documentText = '${lines.join('\n')}\n';
    return {
      'id': 'note-recovery-phrase',
      'title': 'Recovery Phrase',
      'preview': 'Recovery phrase (plain copyable text).',
      'updated': 'Now',
      'pinned': true,
      'tags': ['recovery', 'security'],
      'delta': [
        {'insert': documentText},
      ],
      'blocks': [
        {'type': 'heading', 'text': 'Recovery phrase'},
        {
          'type': 'paragraph',
          'text': 'Seeded from your configured recovery phrase template.',
        },
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildVaultTab(context),
      _buildTypesTab(context),
      _buildFavoritesTab(context),
      _buildSettingsTab(context),
    ];

    return WillPopScope(
      onWillPop: () async {
        if (_allItemsSelectionMode) {
          _clearAllItemsSelection();
          return false;
        }
        if (_notesSelectionMode) {
          _clearNotesSelection();
          return false;
        }
        if (_vaultSelectionMode) {
          _clearVaultSelection();
          return false;
        }
        if (_tabIndex != 0) {
          setState(() => _tabIndex = 0);
          _lastBackOnDashboardAt = null;
          return false;
        }

        final now = DateTime.now();
        final shouldExit =
            _lastBackOnDashboardAt != null &&
            now.difference(_lastBackOnDashboardAt!) <
                const Duration(seconds: 2);
        if (shouldExit) {
          _lastBackOnDashboardAt = null;
          await SystemNavigator.pop();
          return false;
        }

        _lastBackOnDashboardAt = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Press back again to exit.')),
        );
        return false;
      },
      child: Scaffold(
        body: SafeArea(child: pages[_tabIndex]),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: Colors.transparent,
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: Color(0xFF6366F1),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                );
              }
              return const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Color(0xFF6366F1), size: 22);
              }
              return const IconThemeData(color: Color(0xFF6B7280), size: 22);
            }),
          ),
          child: NavigationBar(
            selectedIndex: _tabIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.shield_outlined),
                label: AppStrings.tabVault,
              ),
              NavigationDestination(
                icon: const Icon(Icons.grid_view_outlined),
                label: AppStrings.tabTypes,
              ),
              NavigationDestination(
                icon: const Icon(Icons.star_outline),
                label: AppStrings.tabNotes,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                label: AppStrings.tabSettings,
              ),
            ],
            onDestinationSelected: (value) => setState(() => _tabIndex = value),
          ),
        ),
        floatingActionButton: _tabIndex == 0 || _tabIndex == 1
            ? FloatingActionButton.small(
                onPressed: () => _openAddItemScreen(context),
                child: const Icon(Icons.add),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildVaultTab(BuildContext context) {
    final recentAll = <Map<String, dynamic>>[
      ..._items.map((item) => <String, dynamic>{'kind': 'item', 'entry': item}),
      ..._notes.map((note) => <String, dynamic>{'kind': 'note', 'entry': note}),
    ]..sort((a, b) {
        final av = a['entry'] as Map<String, dynamic>;
        final bv = b['entry'] as Map<String, dynamic>;
        return _updatedSortValue(
          bv['updated']?.toString() ?? '',
        ).compareTo(_updatedSortValue(av['updated']?.toString() ?? ''));
      });
    final recentItems = recentAll.take(4).toList();
    final typeCounts = <String, int>{};
    for (final item in _items) {
      final type = item['type']?.toString().trim();
      if (type == null || type.isEmpty) continue;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    final dashboardTypes = <MapEntry<String, int>>[
      MapEntry<String, int>('Notes', _notes.length),
      ...typeCounts.entries,
    ]..sort((a, b) => b.value.compareTo(a.value));

    return SafeArea(
      child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Nija',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _openAddItemScreen(context),
                    icon: const Icon(Icons.add, color: Color(0xFF6B7280)),
                    tooltip: 'Create',
                  ),
                  IconButton(
                    onPressed: widget.onLockNow,
                    icon: const Icon(Icons.lock_outline, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              Text(
                'All your important information,\nin one secure place.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Color(0xFF111827)),
                      decoration: InputDecoration(
                        hintText: 'Search your data...',
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF9CA3AF),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: () =>
                          _openAllItemsFiltersOverlay(_allTypeFilterOptions()),
                      icon: const Icon(Icons.tune, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.45,
                          ),
                      itemCount: dashboardTypes.take(6).length,
                      itemBuilder: (context, index) {
                        final entry = dashboardTypes[index];
                        return _HomeTypeCard(
                          label: entry.key,
                          count: entry.value,
                          icon: _iconForHomeType(entry.key),
                          accent: _colorForHomeType(entry.key),
                          onTap: () {
                            setState(() {
                              _allItemsTypeFilter = entry.key;
                              _tabIndex = 1;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Recent',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFF111827),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() => _tabIndex = 1),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Text(
                              'View all',
                              style: TextStyle(color: Color(0xFF4F46E5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (recentItems.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'No recent items yet.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      )
                    else
                      ...recentItems.map(
                        (row) {
                          final kind = row['kind']?.toString() ?? 'item';
                          final item = row['entry'] as Map<String, dynamic>;
                          final isNote = kind == 'note';
                          final type = isNote
                              ? 'Notes'
                              : (item['type']?.toString() ?? 'Unknown');
                          return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => isNote
                                  ? _openNoteDetail(context, item)
                                  : _openItemDetail(context, item),
                              onLongPress: () => isNote
                                  ? _showNoteQuickActions(context, item)
                                  : _showItemQuickActions(context, item),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: _colorForHomeType(
                                          type,
                                        ).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                        child: Icon(
                                          _iconForHomeType(type),
                                          size: 16,
                                          color: _colorForHomeType(type),
                                        ),
                                      ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title']?.toString() ?? '',
                                            style: const TextStyle(
                                              color: Color(0xFF111827),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '$type · ${item['updated']?.toString() ?? 'Now'}',
                                            style: const TextStyle(
                                              color: Color(0xFF6B7280),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildNotesTab(BuildContext context) {
    final tagOptions = _notesTagFilterOptions();
    final filtered = _notes.where((note) {
      final query = _notesQuery.trim().toLowerCase();
      final title = note['title']?.toString().toLowerCase() ?? '';
      final preview = note['preview']?.toString().toLowerCase() ?? '';
      final tags = (note['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => entry.toString().toLowerCase())
          .toList();
      final matchesTags = tags.any((tag) => tag.contains(query));
      final matchesQuery =
          query.isEmpty ||
          title.contains(query) ||
          preview.contains(query) ||
          matchesTags;
      final matchesTagFilter =
          _notesFilterTag == 'all' || tags.contains(_notesFilterTag);
      final pinned = note['pinned'] == true;
      final matchesPinned =
          _notesPinFilter == 'all' ||
          (_notesPinFilter == 'pinned' && pinned) ||
          (_notesPinFilter == 'unpinned' && !pinned);
      return matchesQuery && matchesPinned && matchesTagFilter;
    }).toList()..sort(_compareNotes);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          AppStrings.tabNotes,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          key: const ValueKey('notes-info-icon'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showNotesInfoDialog(context),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Color(0xFF52525B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.notesSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              _CountPill(label: '${filtered.length} notes'),
            ],
          ),
          if (_notesSelectionMode) ...[
            const SizedBox(height: 10),
            _SelectionActionBar(
              selectedCount: _selectedNoteIds.length,
              onClear: _clearNotesSelection,
              onPin: _togglePinSelectedNotes,
              onDelete: _deleteSelectedNotes,
            ),
          ],
          const SizedBox(height: 12),
          SearchBar(
            hintText: AppStrings.searchNotes,
            leading: const Icon(Icons.search),
            onChanged: (value) => setState(() => _notesQuery = value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SortSelector(
                  key: const ValueKey('notes-sort-selector'),
                  label: 'Sort by',
                  icon: Icons.sort,
                  selectedLabel: _selectorLabelForValue(_notesSort, const [
                    _SelectorOption(
                      value: 'last_accessed',
                      label: 'Last accessed',
                    ),
                    _SelectorOption(value: 'title', label: 'Title'),
                    _SelectorOption(value: 'tags', label: 'Tags'),
                  ]),
                  onTap: () => _openSelectorSheet(
                    title: 'Sort notes by',
                    value: _notesSort,
                    options: const [
                      _SelectorOption(
                        value: 'last_accessed',
                        label: 'Last accessed',
                      ),
                      _SelectorOption(value: 'title', label: 'Title'),
                      _SelectorOption(value: 'tags', label: 'Tags'),
                    ],
                    onSelected: _setNotesSort,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SortSelector(
                  key: const ValueKey('notes-filter-selector'),
                  label: 'Filter by',
                  icon: Icons.filter_alt_outlined,
                  selectedLabel: _selectorLabelForValue(
                    _notesFilterTag,
                    tagOptions
                        .map(
                          (tag) => _SelectorOption(
                            value: tag,
                            label: tag == 'all' ? 'All tags' : '#$tag',
                          ),
                        )
                        .toList(),
                  ),
                  onTap: () => _openSelectorSheet(
                    title: 'Filter notes by tag',
                    value: _notesFilterTag,
                    options: tagOptions
                        .map(
                          (tag) => _SelectorOption(
                            value: tag,
                            label: tag == 'all' ? 'All tags' : '#$tag',
                          ),
                        )
                        .toList(),
                    onSelected: (value) =>
                        setState(() => _notesFilterTag = value),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _notesPinFilter == 'all',
                onSelected: (_) => setState(() => _notesPinFilter = 'all'),
              ),
              ChoiceChip(
                label: const Text('Pinned'),
                selected: _notesPinFilter == 'pinned',
                onSelected: (_) => setState(() => _notesPinFilter = 'pinned'),
              ),
              ChoiceChip(
                label: const Text('Unpinned'),
                selected: _notesPinFilter == 'unpinned',
                onSelected: (_) => setState(() => _notesPinFilter = 'unpinned'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: ExpansionTile(
              initiallyExpanded: _notesFiltersExpanded,
              onExpansionChanged: (expanded) =>
                  setState(() => _notesFiltersExpanded = expanded),
              leading: const Icon(Icons.tune),
              title: const Text('Notes filters'),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(AppStrings.pinned),
                        selected: _notesPinFilter == 'pinned',
                        onSelected: (selected) => setState(
                          () => _notesPinFilter = selected ? 'pinned' : 'all',
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.sort, size: 16),
                        label: Text(AppStrings.pinnedFirst),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Expanded(
              child: _EmptyState(
                title: AppStrings.noNotesFound,
                subtitle: AppStrings.noNotesFoundHint,
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE4E4E7),
                ),
                itemBuilder: (context, index) {
                  final note = filtered[index];
                  final tags =
                      (note['tags'] as List<dynamic>? ?? const <dynamic>[])
                          .cast<String>()
                          .map((tag) => tag.trim())
                          .where(
                            (tag) =>
                                tag.isNotEmpty && tag.toLowerCase() != 'note',
                          )
                          .toList();
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      leading: _notesSelectionMode
                          ? Checkbox(
                              value: _selectedNoteIds.contains(
                                note['id']?.toString() ?? '',
                              ),
                              onChanged: (_) => _toggleNoteSelection(note),
                            )
                          : InkWell(
                              key: ValueKey('note-leading-${note['id']}'),
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => _enterNotesSelectionMode(note),
                              child: const CircleAvatar(
                                backgroundColor: Color(0xFFF3F4F6),
                                child: Icon(
                                  Icons.description_outlined,
                                  size: 18,
                                ),
                              ),
                            ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              note['title'].toString(),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (note['pinned'] == true)
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            _noteListPreviewText(note),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${AppStrings.lastAccessed}: ${note['updated']?.toString() ?? 'Now'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF71717A)),
                          ),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: tags
                                  .take(2)
                                  .map((tag) => _TinyChip(label: '#$tag'))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                      trailing: _notesSelectionMode
                          ? null
                          : const Icon(Icons.chevron_right),
                      onTap: () => _notesSelectionMode
                          ? _toggleNoteSelection(note)
                          : _openNoteDetail(context, note),
                      onLongPress: () => _notesSelectionMode
                          ? _toggleNoteSelection(note)
                          : _showNoteQuickActions(context, note),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showNotesInfoDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notes info'),
        content: const Text(
          'Notes are stored inside the same encrypted vault file. They are private by default and never synced as readable text.',
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

  Widget _buildTypesTab(BuildContext context) {
    final all = <Map<String, dynamic>>[
      ..._items.map((item) => <String, dynamic>{'kind': 'item', 'entry': item}),
      ..._notes.map((note) => <String, dynamic>{'kind': 'note', 'entry': note}),
    ];
    all.sort((a, b) {
      final av = a['entry'] as Map<String, dynamic>;
      final bv = b['entry'] as Map<String, dynamic>;
      return _updatedSortValue(
        bv['updated']?.toString() ?? '',
      ).compareTo(_updatedSortValue(av['updated']?.toString() ?? ''));
    });

    final typeOptions = <String>{'all', 'Notes'};
    for (final item in _items) {
      final type = item['type']?.toString().trim();
      if (type != null && type.isNotEmpty) typeOptions.add(type);
    }
    final sortedTypeOptions = typeOptions.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final query = _allItemsQuery.trim().toLowerCase();
    final filterSearch = _allItemsFilterSearch.trim().toLowerCase();
    final filtered = all.where((row) {
      final kind = row['kind']?.toString() ?? 'item';
      final entry = row['entry'] as Map<String, dynamic>;
      final type = kind == 'note'
          ? 'Notes'
          : (entry['type']?.toString().trim().isNotEmpty == true
                ? entry['type'].toString().trim()
                : 'Unknown');
      final title = entry['title']?.toString().toLowerCase() ?? '';
      final subtitle = (kind == 'note'
              ? entry['preview']?.toString()
              : entry['subtitle']?.toString())?.toLowerCase() ??
          '';
      final matchesQuery =
          query.isEmpty || title.contains(query) || subtitle.contains(query);
      final matchesOverlaySearch =
          filterSearch.isEmpty ||
          title.contains(filterSearch) ||
          subtitle.contains(filterSearch);
      final matchesType =
          _allItemsTypeFilter == 'all' || _allItemsTypeFilter == type;
      final matchesOverlayType =
          _allItemsFilterTypes.isEmpty || _allItemsFilterTypes.contains(type);
      final matchesFavorite = !_allItemsFilterFavoritesOnly || entry['pinned'] == true;
      final matchesDate = _matchesAllItemsDateFilter(
        entry['updated']?.toString() ?? '',
      );
      return matchesQuery &&
          matchesOverlaySearch &&
          matchesType &&
          matchesOverlayType &&
          matchesFavorite &&
          matchesDate;
    }).toList();
    return SafeArea(
      child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_allItemsSelectionMode)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _clearAllItemsSelection,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      'All Items',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: const Color(0xFF111827),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  const Spacer(),
                  if (_allItemsSelectionMode)
                    Text(
                      '${_selectedAllItemsKeys.length} Selected',
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const Spacer(),
                  if (_allItemsSelectionMode)
                    const SizedBox.shrink()
                  else
                    IconButton(
                      onPressed: () => _openAddItemScreen(context),
                      icon: const Icon(Icons.add, color: Color(0xFF6B7280)),
                    ),
                ],
              ),
              if (!_allItemsSelectionMode)
                Text(
                  '${filtered.length} items',
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Color(0xFF111827)),
                      decoration: InputDecoration(
                        hintText: 'Search all items...',
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF9CA3AF),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (value) => setState(() => _allItemsQuery = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_allItemsSelectionMode)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        onPressed: () => _openAllItemsFiltersOverlay(
                          sortedTypeOptions.where((t) => t != 'all').toList(),
                        ),
                        icon: const Icon(Icons.tune, color: Color(0xFF6B7280)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: sortedTypeOptions.map((type) {
                    final selected = _allItemsTypeFilter == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(type),
                        selected: selected,
                        onSelected: (_) => setState(
                          () => _allItemsTypeFilter = type,
                        ),
                        backgroundColor: const Color(0xFFF3F4F6),
                        selectedColor: const Color(0xFFE0E7FF),
                        labelStyle: TextStyle(
                          color: selected
                              ? const Color(0xFF3730A3)
                              : const Color(0xFF6B7280),
                        ),
                        side: BorderSide.none,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              if (_activeAllItemsFilterChips().isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ..._activeAllItemsFilterChips().map(
                      (chip) => _TinyChip(label: chip),
                    ),
                    InkWell(
                      onTap: _clearAllItemsOverlayFilters,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          'Clear all',
                          style: TextStyle(color: Color(0xFF4F46E5), fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (!_allItemsSelectionMode)
                const Text(
                  'Sort by: Modified (newest)',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No items found.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final row = filtered[index];
                          final kind = row['kind']?.toString() ?? 'item';
                          final entry = row['entry'] as Map<String, dynamic>;
                          final isNote = kind == 'note';
                          final type = isNote
                              ? 'Notes'
                              : (entry['type']?.toString() ?? 'Unknown');
                          final subtitle = isNote
                              ? entry['preview']?.toString() ?? ''
                              : entry['subtitle']?.toString() ?? '';
                          final updated = entry['updated']?.toString() ?? 'Now';
                          final selected = _selectedAllItemsKeys.contains(
                            _allItemsSelectionKey(row),
                          );
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                if (_allItemsSelectionMode) {
                                  _toggleAllItemsSelection(row);
                                  return;
                                }
                                if (isNote) {
                                  _openNoteDetail(context, entry);
                                } else {
                                  _openItemDetail(context, entry);
                                }
                              },
                              onLongPress: () {
                                if (_allItemsSelectionMode) {
                                  _toggleAllItemsSelection(row);
                                  return;
                                }
                                _enterAllItemsSelectionMode(row);
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                                child: Row(
                                  children: [
                                    if (_allItemsSelectionMode)
                                      Icon(
                                        selected
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: selected
                                            ? const Color(0xFF6366F1)
                                            : const Color(0xFF9CA3AF),
                                      )
                                    else
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: _colorForHomeType(type).withValues(
                                            alpha: 0.28,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _iconForHomeType(type),
                                          color: _colorForHomeType(type),
                                          size: 16,
                                        ),
                                      ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry['title']?.toString() ?? '',
                                            style: const TextStyle(
                                              color: Color(0xFF111827),
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$type · $updated',
                                            style: const TextStyle(
                                              color: Color(0xFF6B7280),
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (subtitle.isNotEmpty)
                                            Text(
                                              subtitle,
                                              style: const TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (!_allItemsSelectionMode &&
                                        entry['pinned'] == true)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(
                                          Icons.star,
                                          color: Color(0xFFF59E0B),
                                          size: 14,
                                        ),
                                      ),
                                    if (_allItemsSelectionMode)
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Color(0xFF9CA3AF),
                                        size: 18,
                                      )
                                    else
                                      IconButton(
                                        onPressed: () => isNote
                                            ? _showNoteQuickActions(context, entry)
                                            : _showItemQuickActions(context, entry),
                                        icon: const Icon(
                                          Icons.more_vert,
                                          color: Color(0xFF9CA3AF),
                                          size: 18,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_allItemsSelectionMode)
                _AllItemsSelectionActionBar(
                  onShare: _showSelectionActionComingSoon,
                  onMove: _showSelectionActionComingSoon,
                  onLock: _showSelectionActionComingSoon,
                  onDelete: _deleteSelectedAllItems,
                  onMore: _showAllItemsMoreActions,
                ),
            ],
          ),
      ),
    );
  }

  Widget _buildFavoritesTab(BuildContext context) {
    final favoriteItems = _items
        .where((item) => item['pinned'] == true)
        .map((item) => <String, dynamic>{'kind': 'item', 'entry': item})
        .toList();
    final favoriteNotes = _notes
        .where((note) => note['pinned'] == true)
        .map((note) => <String, dynamic>{'kind': 'note', 'entry': note})
        .toList();
    final allFavorites = <Map<String, dynamic>>[
      ...favoriteItems,
      ...favoriteNotes,
    ]..sort((a, b) {
        final av = a['entry'] as Map<String, dynamic>;
        final bv = b['entry'] as Map<String, dynamic>;
        return _updatedSortValue(
          bv['updated']?.toString() ?? '',
        ).compareTo(_updatedSortValue(av['updated']?.toString() ?? ''));
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: AppStrings.tabNotes, subtitle: 'Starred secrets'),
          const SizedBox(height: 10),
          Expanded(
            child: allFavorites.isEmpty
                ? const _EmptyState(
                    title: 'No favorites yet',
                    subtitle: 'Star items from quick actions to see them here.',
                  )
                : ListView.separated(
                    itemCount: allFavorites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final row = allFavorites[index];
                      final isNote = row['kind'] == 'note';
                      final entry = row['entry'] as Map<String, dynamic>;
                      final type = isNote
                          ? 'Notes'
                          : (entry['type']?.toString() ?? 'Unknown');
                      final subtitle = isNote
                          ? entry['preview']?.toString() ?? ''
                          : entry['subtitle']?.toString() ?? '';
                      final updated = entry['updated']?.toString() ?? 'Now';
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => isNote
                              ? _openNoteDetail(context, entry)
                              : _openItemDetail(context, entry),
                          onLongPress: () => isNote
                              ? _showNoteQuickActions(context, entry)
                              : _showItemQuickActions(context, entry),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _colorForHomeType(type).withValues(
                                      alpha: 0.28,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _iconForHomeType(type),
                                    color: _colorForHomeType(type),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry['title']?.toString() ?? '',
                                        style: const TextStyle(
                                          color: Color(0xFF111827),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$type · $updated',
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (subtitle.isNotEmpty)
                                        Text(
                                          subtitle,
                                          style: const TextStyle(
                                            color: Color(0xFF6B7280),
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(
                                    Icons.star,
                                    color: Color(0xFFF59E0B),
                                    size: 14,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => isNote
                                      ? _showNoteQuickActions(context, entry)
                                      : _showItemQuickActions(context, entry),
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Color(0xFF9CA3AF),
                                    size: 18,
                                  ),
                                ),
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

  int _updatedSortValue(String text) {
    final digits = RegExp(r'\d+').firstMatch(text)?.group(0);
    if (digits == null) return 0;
    return int.tryParse(digits) ?? 0;
  }

  int? _updatedAgeDays(String text) {
    final normalized = text.toLowerCase().trim();
    if (normalized.isEmpty || normalized == 'now') return 0;
    final digits = RegExp(r'\d+').firstMatch(normalized)?.group(0);
    final value = digits == null ? 0 : (int.tryParse(digits) ?? 0);
    if (normalized.contains('h')) return 0;
    if (normalized.contains('d')) return value;
    if (normalized.contains('w')) return value * 7;
    if (normalized.contains('m')) return value * 30;
    return 9999;
  }

  bool _matchesAllItemsDateFilter(String updatedText) {
    if (_allItemsFilterDateRange == 'any') return true;
    final ageDays = _updatedAgeDays(updatedText);
    if (ageDays == null) return false;
    switch (_allItemsFilterDateRange) {
      case 'today':
        return ageDays == 0;
      case 'last_7_days':
        return ageDays <= 7;
      case 'last_30_days':
        return ageDays <= 30;
      default:
        return true;
    }
  }

  List<String> _activeAllItemsFilterChips() {
    final chips = <String>[];
    if (_allItemsFilterSearch.trim().isNotEmpty) {
      chips.add(_allItemsFilterSearch.trim());
    }
    chips.addAll(_allItemsFilterTypes.toList()..sort());
    if (_allItemsFilterFavoritesOnly) chips.add('Favorites');
    if (_allItemsFilterDateRange == 'today') chips.add('Today');
    if (_allItemsFilterDateRange == 'last_7_days') chips.add('Last 7 Days');
    if (_allItemsFilterDateRange == 'last_30_days') chips.add('Last 30 Days');
    return chips;
  }

  void _clearAllItemsOverlayFilters() {
    setState(() {
      _allItemsFilterSearch = '';
      _allItemsFilterTypes = <String>{};
      _allItemsFilterFavoritesOnly = false;
      _allItemsFilterDateRange = 'any';
    });
  }

  Future<void> _openAllItemsFiltersOverlay(List<String> typeOptions) async {
    final applied = await Navigator.of(context).push<_AllItemsFilterState>(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _AllItemsFiltersOverlay(
          initialState: _AllItemsFilterState(
            search: _allItemsFilterSearch,
            selectedTypes: _allItemsFilterTypes,
            favoritesOnly: _allItemsFilterFavoritesOnly,
            dateRange: _allItemsFilterDateRange,
          ),
          typeOptions: typeOptions,
        ),
      ),
    );
    if (applied == null) return;
    setState(() {
      _allItemsFilterSearch = applied.search;
      _allItemsFilterTypes = applied.selectedTypes;
      _allItemsFilterFavoritesOnly = applied.favoritesOnly;
      _allItemsFilterDateRange = applied.dateRange;
    });
  }

  List<String> _allTypeFilterOptions() {
    final options = <String>{'Notes'};

    for (final item in _items) {
      final type = item['type']?.toString().trim();
      if (type != null && type.isNotEmpty) {
        options.add(type);
      }
    }

    for (final template in AddVaultItemScreen.templates) {
      final type = template.type.trim();
      if (type.isNotEmpty) {
        options.add(type);
      }
    }

    for (final definition in _customTypeDefinitions) {
      final type = definition['name']?.toString().trim();
      if (type != null && type.isNotEmpty) {
        options.add(type);
      }
    }

    final sorted = options.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  Widget _buildSettingsTab(BuildContext context) {
    final languageLabel = switch (widget.languageMode) {
      'en' => 'English',
      'es' => 'Español',
      _ => AppStrings.systemDefault,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: ListView(
        children: [
          _SectionHeader(
            title: AppStrings.tabSettings,
            subtitle: AppStrings.settingsSubtitle,
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language_outlined),
              title: Text(AppStrings.language),
              subtitle: Text(languageLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguagePicker(context),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Theme'),
              subtitle: const Text('Light (Dark mode coming later)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Light theme is active. Dark theme will be added later.',
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(AppStrings.vaultName),
              subtitle: Text(widget.activeVaultName),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.view_list_outlined),
              title: const Text('Custom templates'),
              subtitle: Text('${_customTypeDefinitions.length} templates'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCustomTemplateManager(context),
            ),
          ),
          const SizedBox(height: 10),
          ...[AppStrings.settingsSecurity, AppStrings.settingsAutoLock].map(
            (section) => Card(
              child: ListTile(
                leading: Icon(_iconForSetting(section)),
                title: Text(section),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (section == AppStrings.settingsSecurity) {
                    _showRotateMasterPasswordDialog(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppStrings.settingComingSoon)),
                    );
                  }
                },
              ),
            ),
          ),
          Card(
            child: SwitchListTile(
              key: const ValueKey('settings-cloud-backup-switch'),
              secondary: Icon(_cloudBackupIcon()),
              title: Text(_cloudBackupTitle()),
              subtitle: Text(
                AppFeatures.isPaidBuild
                    ? (_cloudBackupEnabled
                          ? 'Enabled for this device.'
                          : 'Disabled for this device.')
                    : 'Available in paid version',
              ),
              value: _cloudBackupEnabled,
              onChanged: AppFeatures.isPaidBuild
                  ? (value) => _setCloudBackupEnabled(value)
                  : null,
            ),
          ),
          if (AppFeatures.isPaidBuild && _cloudBackupEnabled) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cloud backup status',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _cloudBackupLastAtEpochMs <= 0
                          ? 'Last backup: Never'
                          : 'Last backup: ${DateTime.fromMillisecondsSinceEpoch(_cloudBackupLastAtEpochMs)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.account_circle_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Backup account',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _cloudBackupAccountLabel,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton(
                                  onPressed: _handleChangeCloudBackupAccount,
                                  child: Text(
                                    _cloudBackupAccountLabel == 'Not connected'
                                        ? 'Select account'
                                        : 'Change account',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      key: const ValueKey('settings-cloud-backup-auto-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto backup'),
                      subtitle: const Text(
                        'Runs while app is active. Backup timing is selected automatically based on app usage.',
                      ),
                      value: _cloudBackupAutoEnabled,
                      onChanged: (value) => _setCloudBackupAutoEnabled(value),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Backup frequency'),
                      subtitle: Text(
                        _cloudBackupFrequency == 'weekly'
                            ? 'Weekly'
                            : _cloudBackupFrequency == 'monthly'
                            ? 'Monthly'
                            : 'Daily',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showCloudBackupFrequencyPicker,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('settings-cloud-backup-now'),
                            onPressed: _handleCloudBackupNow,
                            icon: Icon(_cloudBackupIcon()),
                            label: const Text('Backup now'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('settings-cloud-restore-now'),
                            onPressed: widget.onRestoreFromCloud,
                            icon: const Icon(Icons.restore_outlined),
                            label: const Text('Restore backup'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sd_storage_outlined),
              title: const Text('Vault size'),
              subtitle: Text(_formatBytes(widget.vaultSizeBytes)),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: SwitchListTile(
              key: const ValueKey('settings-biometrics-switch'),
              secondary: Icon(
                _iconForSetting(AppStrings.settingsBiometricUnlock),
              ),
              title: Text(AppStrings.settingsBiometricUnlock),
              value: widget.biometricEnabled,
              onChanged: widget.onBiometricChanged,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              key: const ValueKey('settings-import-encrypted-secret'),
              leading: const Icon(Icons.lock_open_outlined),
              title: Text(AppStrings.importEncryptedSecret),
              trailing: const Icon(Icons.chevron_right),
              onTap: _importEncryptedSecret,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              key: const ValueKey('settings-default-vault-filter'),
              leading: const Icon(Icons.filter_list),
              title: const Text('Default sort for keys'),
              subtitle: Text(_vaultSort == 'title' ? 'Title' : 'Last accessed'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showSortDefaultsDialog(context, isNotes: false),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              key: const ValueKey('settings-default-notes-filter'),
              leading: const Icon(Icons.filter_alt_outlined),
              title: const Text('Default sort for notes'),
              subtitle: Text(
                _notesSort == 'title'
                    ? 'Title'
                    : _notesSort == 'tags'
                    ? 'Tags'
                    : 'Last accessed',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showSortDefaultsDialog(context, isNotes: true),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onExportVault,
              icon: const Icon(Icons.file_upload_outlined),
              label: Text(AppStrings.settingsExportVault),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onLockNow,
              child: Text(AppStrings.lockVaultNow),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRotateMasterPasswordDialog(BuildContext context) async {
    final currentController = TextEditingController();
    final nextController = TextEditingController();
    final confirmController = TextEditingController();
    try {
      final values = await showDialog<(String, String)>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setLocalState) {
            final canSubmit =
                currentController.text.trim().isNotEmpty &&
                nextController.text.trim().isNotEmpty &&
                nextController.text == confirmController.text;
            return AlertDialog(
              title: const Text('Rotate master password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentController,
                    obscureText: true,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Current master password',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nextController,
                    obscureText: true,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'New master password',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Confirm new master password',
                      helperText: confirmController.text.isEmpty || canSubmit
                          ? null
                          : 'Passwords do not match',
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
                  onPressed: canSubmit
                      ? () => Navigator.of(context).pop((
                          currentController.text.trim(),
                          nextController.text.trim(),
                        ))
                      : null,
                  child: const Text('Rotate'),
                ),
              ],
            );
          },
        ),
      );
      if (values == null) return;
      await widget.onRotateMasterPassword(
        currentPassword: values.$1,
        newPassword: values.$2,
      );
    } finally {
      currentController.dispose();
      nextController.dispose();
      confirmController.dispose();
    }
  }

  Future<void> _showLanguagePicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(AppStrings.language)),
              _languageOptionTile(context, 'system', AppStrings.systemDefault),
              _languageOptionTile(context, 'en', 'English'),
              _languageOptionTile(context, 'es', 'Español'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null || selected == widget.languageMode) return;
    widget.onLanguageModeChanged(selected);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.languageUpdated)));
  }

  Widget _languageOptionTile(BuildContext context, String mode, String label) {
    final selected = widget.languageMode == mode;
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(mode),
    );
  }

  Future<void> _openItemDetail(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _ItemDetailScreen(
          item: item,
          customTypeDefinitions: _customTypeDefinitions,
          showDeleteAction: true,
          onCopy: (value) async {
            await _clipboard.copySensitive(value);
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(AppStrings.copySuccess)));
          },
          onShareSecurely: () => _shareEncryptedSecret(
            plainText: _itemPlainText(item),
            suggestedBaseName: item['title']?.toString() ?? 'item',
            contentType: 'vault_item',
          ),
        ),
      ),
    );
    if (result == null) return;
    final idx = _items.indexWhere(
      (entry) => entry['id']?.toString() == item['id']?.toString(),
    );
    if (idx == -1) return;
    if (result['__delete__'] == true) {
      setState(() => _items.removeAt(idx));
      await _persistVaultData();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.itemDeleted)));
      return;
    }
    setState(() => _items[idx] = result);
    await _persistVaultData();
  }

  Future<void> _openNoteDetail(
    BuildContext context,
    Map<String, dynamic> note,
  ) async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => NoteViewScreen(
          note: note,
          showDeleteAction: true,
          onAutoSave: _upsertNoteAndPersist,
        ),
      ),
    );
    if (updated == null) return;

    final idx = _notes.indexWhere(
      (entry) => entry['id']?.toString() == note['id']?.toString(),
    );
    if (idx == -1) return;

    if (updated['__delete__'] == true) {
      setState(() => _notes.removeAt(idx));
      await _persistVaultData();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.noteDeleted)));
      return;
    }

    setState(() => _notes[idx] = updated);
    await _persistVaultData();
  }

  Future<void> _openAddItemScreen(BuildContext context) async {
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => NewItemCategoryScreen(
          customTypeDefinitions: _customTypeDefinitions,
          onCreateNote: () async {
            return Navigator.of(context).push<Map<String, dynamic>>(
              MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
            );
          },
        ),
      ),
    );

    if (created == null) return;
    final kind = created['kind']?.toString() ?? 'item';
    final entry = created['entry'];
    if (entry is! Map<String, dynamic>) return;
    if (kind == 'note') {
      setState(() => _notes.insert(0, Map<String, dynamic>.from(entry)));
      await _persistVaultData();
      return;
    }
    setState(() => _items.insert(0, Map<String, dynamic>.from(entry)));
    await _persistVaultData();
  }

  Future<void> _openCreateCustomTypeScreen(BuildContext context) async {
    final createdType = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const CreateCustomTypeScreen()),
    );
    if (createdType == null) return;

    final name = createdType['name']?.toString() ?? '';
    if (name.isEmpty) return;

    final exists = _customTypeDefinitions.any(
      (definition) =>
          definition['name']?.toString().toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.customTypeExists)));
      return;
    }

    setState(() => _customTypeDefinitions.add(createdType));
    await _persistVaultData();
  }

  Future<void> _showCustomTemplateManager(BuildContext context) async {
    final working = _customTypeDefinitions
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();

    final updated = await Navigator.of(
      context,
    ).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(
        builder: (pageContext) {
          return StatefulBuilder(
            builder: (pageContext, setPageState) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Custom templates'),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        final createdType =
                            await Navigator.of(pageContext).push<Map<String, dynamic>>(
                              MaterialPageRoute(
                                builder: (_) => const CreateCustomTypeScreen(),
                              ),
                            );
                        if (createdType == null) return;
                        final name = createdType['name']?.toString().trim() ?? '';
                        if (name.isEmpty) return;
                        final exists = working.any(
                          (definition) =>
                              definition['name']?.toString().toLowerCase() ==
                              name.toLowerCase(),
                        );
                        if (exists) {
                          if (!pageContext.mounted) return;
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            SnackBar(content: Text(AppStrings.customTypeExists)),
                          );
                          return;
                        }
                        setPageState(() => working.add(createdType));
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                body: Column(
                  children: [
                    Expanded(
                      child: working.isEmpty
                          ? const Center(
                              child: Text(
                                'No custom templates yet.',
                                style: TextStyle(color: Color(0xFF6B7280)),
                              ),
                            )
                          : ListView.separated(
                              itemCount: working.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (itemContext, index) {
                                final definition = working[index];
                                final iconKey = definition['iconKey']?.toString();
                                final name =
                                    definition['name']?.toString() ?? 'Custom';
                                final fields =
                                    (definition['fields'] as List<dynamic>? ??
                                            const <dynamic>[])
                                        .length;
                                return ListTile(
                                  leading: Icon(
                                    _iconForCustomTemplateKey(iconKey),
                                    color: _colorForCustomTemplateKey(iconKey),
                                  ),
                                  title: Text(name),
                                  subtitle: Text('$fields fields'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () async {
                                          final edited = await Navigator.of(
                                            itemContext,
                                          ).push<Map<String, dynamic>>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  CreateCustomTypeScreen(
                                                    initialTemplate: definition,
                                                  ),
                                            ),
                                          );
                                          if (edited == null) return;
                                          final editedName =
                                              edited['name']?.toString().trim() ??
                                              '';
                                          if (editedName.isEmpty) return;
                                          final existsWithOther = working
                                              .asMap()
                                              .entries
                                              .any(
                                                (entry) =>
                                                    entry.key != index &&
                                                    (entry.value['name']
                                                                ?.toString()
                                                                .toLowerCase() ??
                                                            '') ==
                                                        editedName.toLowerCase(),
                                              );
                                          if (existsWithOther) {
                                            if (!itemContext.mounted) return;
                                            ScaffoldMessenger.of(
                                              itemContext,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  AppStrings.customTypeExists,
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          setPageState(() => working[index] = edited);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () async {
                                          final confirmed =
                                              await showModalBottomSheet<bool>(
                                                context: itemContext,
                                                backgroundColor: Colors.transparent,
                                                builder: (sheetContext) {
                                                  return Container(
                                                    decoration: const BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.vertical(
                                                        top: Radius.circular(22),
                                                      ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          16,
                                                          14,
                                                          16,
                                                          18,
                                                        ),
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
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.w700,
                                                            fontSize: 20,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          '“$name” will be moved to trash.\nThis action can be undone.',
                                                          textAlign: TextAlign.center,
                                                          style: const TextStyle(
                                                            color: Color(0xFF6B7280),
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 14),
                                                        SizedBox(
                                                          width: double.infinity,
                                                          child: FilledButton(
                                                            style: FilledButton.styleFrom(
                                                              backgroundColor:
                                                                  const Color(0xFFEF4444),
                                                              foregroundColor:
                                                                  Colors.white,
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical: 14,
                                                                  ),
                                                            ),
                                                            onPressed: () => Navigator.of(
                                                              sheetContext,
                                                            ).pop(true),
                                                            child: const Text(
                                                              'Move to Trash',
                                                            ),
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () => Navigator.of(
                                                            sheetContext,
                                                          ).pop(false),
                                                          child: const Text('Cancel'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              );
                                          if (confirmed != true) return;
                                          setPageState(
                                            () => working.removeAt(index),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: () => Navigator.of(pageContext).pop(working),
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                ),
              );
            },
          );
        },
      ),
    );

    if (updated == null) return;
    setState(() {
      _customTypeDefinitions
        ..clear()
        ..addAll(updated);
    });
    await _persistVaultData();
  }

  Future<void> _showAddNoteSheet(BuildContext context) async {
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(onAutoSave: _upsertNoteAndPersist),
      ),
    );
    if (created == null) return;
    setState(() => _notes.insert(0, created));
    await _persistVaultData();
  }

  void _upsertNoteAndPersist(Map<String, dynamic> note) {
    final id = note['id']?.toString();
    if (id == null || id.isEmpty) return;
    final idx = _notes.indexWhere((entry) => entry['id']?.toString() == id);
    if (idx == -1) {
      setState(() => _notes.insert(0, note));
    } else {
      setState(() => _notes[idx] = note);
    }
    unawaited(_persistVaultData());
  }

  Future<void> _openTypeItemsScreen(BuildContext context, String type) async {
    final items = type == AppStrings.secureNotes
        ? _notes
        : _items.where((entry) => entry['type']?.toString() == type).toList();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TypeItemsScreen(
          type: type,
          items: items,
          onOpenItem: type == AppStrings.secureNotes
              ? null
              : (item) => _openItemDetail(context, item),
          onOpenNote: type == AppStrings.secureNotes
              ? (note) => _openNoteDetail(context, note)
              : null,
          onItemActions: type == AppStrings.secureNotes
              ? null
              : (item) => _showItemQuickActions(context, item),
          onNoteActions: type == AppStrings.secureNotes
              ? (note) => _showNoteQuickActions(context, note)
              : null,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _persistVaultData() async {
    try {
      await widget.onPersistVaultData(
        items: _items,
        notes: _notes,
        customTypeDefinitions: _customTypeDefinitions,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to persist vault updates. Please retry.'),
        ),
      );
    }
  }

  int _compareVaultItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aPinned = a['pinned'] == true ? 1 : 0;
    final bPinned = b['pinned'] == true ? 1 : 0;
    final pinCmp = bPinned.compareTo(aPinned);
    if (pinCmp != 0) return pinCmp;
    if (_vaultSort == 'title') {
      final titleCmp = (a['title']?.toString() ?? '').toLowerCase().compareTo(
        (b['title']?.toString() ?? '').toLowerCase(),
      );
      if (titleCmp != 0) return titleCmp;
    }
    return _updatedRank(b).compareTo(_updatedRank(a));
  }

  int _compareNotes(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aPinned = a['pinned'] == true ? 1 : 0;
    final bPinned = b['pinned'] == true ? 1 : 0;
    final pinCmp = bPinned.compareTo(aPinned);
    if (pinCmp != 0) return pinCmp;
    if (_notesSort == 'title') {
      final titleCmp = (a['title']?.toString() ?? '').toLowerCase().compareTo(
        (b['title']?.toString() ?? '').toLowerCase(),
      );
      if (titleCmp != 0) return titleCmp;
    }
    if (_notesSort == 'tags') {
      final aTag = _firstTag(a);
      final bTag = _firstTag(b);
      final tagCmp = aTag.compareTo(bTag);
      if (tagCmp != 0) return tagCmp;
    }
    return _updatedRank(b).compareTo(_updatedRank(a));
  }

  String _firstTag(Map<String, dynamic> note) {
    final tags =
        (note['tags'] as List<dynamic>? ?? const <dynamic>[])
            .map((entry) => entry.toString().trim().toLowerCase())
            .where((entry) => entry.isNotEmpty)
            .toList()
          ..sort();
    if (tags.isEmpty) return 'zzzz';
    return tags.first;
  }

  int _updatedRank(Map<String, dynamic> entry) {
    final updated = entry['updated']?.toString().trim() ?? '';
    if (updated.toLowerCase() == 'now') return 999999999;
    return 0;
  }

  Future<void> _restoreSortPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vault = prefs.getString(_prefsKeyVaultSort);
      final notes = prefs.getString(_prefsKeyNotesSort);
      if (!mounted) return;
      setState(() {
        _vaultSort = (vault == 'title' || vault == 'last_accessed')
            ? vault!
            : _vaultSort;
        _notesSort =
            (notes == 'title' || notes == 'last_accessed' || notes == 'tags')
            ? notes!
            : _notesSort;
      });
    } catch (_) {
      // Ignore preference read failures.
    }
  }

  Future<void> _restoreCloudBackupPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefsKeyCloudBackupEnabled) ?? false;
      final auto = prefs.getBool(_prefsKeyCloudBackupAuto) ?? false;
      final frequency =
          prefs.getString(_prefsKeyCloudBackupFrequency) ?? 'daily';
      final lastAt = prefs.getInt(_prefsKeyCloudBackupLastAt) ?? 0;
      if (!mounted) return;
      setState(() {
        _cloudBackupEnabled = enabled && AppFeatures.isPaidBuild;
        _cloudBackupAutoEnabled = auto && AppFeatures.isPaidBuild;
        _cloudBackupFrequency =
            (frequency == 'weekly' || frequency == 'monthly')
            ? frequency
            : 'daily';
        _cloudBackupLastAtEpochMs = lastAt;
      });
    } catch (_) {
      // Ignore preference read failures.
    }
  }

  Future<void> _setCloudBackupEnabled(bool enabled) async {
    if (!AppFeatures.isPaidBuild) return;
    setState(() => _cloudBackupEnabled = enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyCloudBackupEnabled, enabled);
    } catch (_) {}
  }

  Future<void> _setCloudBackupAutoEnabled(bool enabled) async {
    if (!AppFeatures.isPaidBuild) return;
    setState(() => _cloudBackupAutoEnabled = enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyCloudBackupAuto, enabled);
    } catch (_) {}
  }

  Future<void> _setCloudBackupFrequency(String value) async {
    if (!AppFeatures.isPaidBuild) return;
    if (value != 'daily' && value != 'weekly' && value != 'monthly') return;
    setState(() => _cloudBackupFrequency = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyCloudBackupFrequency, value);
    } catch (_) {}
  }

  Future<void> _showCloudBackupFrequencyPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Backup frequency')),
            ListTile(
              title: const Text('Daily'),
              trailing: _cloudBackupFrequency == 'daily'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop('daily'),
            ),
            ListTile(
              title: const Text('Weekly'),
              trailing: _cloudBackupFrequency == 'weekly'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop('weekly'),
            ),
            ListTile(
              title: const Text('Monthly'),
              trailing: _cloudBackupFrequency == 'monthly'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop('monthly'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _setCloudBackupFrequency(selected);
  }

  Future<void> _handleCloudBackupNow() async {
    await widget.onBackupToCloud();
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() => _cloudBackupLastAtEpochMs = now);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyCloudBackupLastAt, now);
    } catch (_) {}
  }

  Future<void> _refreshCloudBackupAccountLabel() async {
    final label = await widget.onReadCloudBackupAccount();
    if (!mounted) return;
    setState(() => _cloudBackupAccountLabel = (label == null || label.isEmpty)
        ? 'Not connected'
        : label);
  }

  Future<void> _handleChangeCloudBackupAccount() async {
    final ok = await widget.onChangeCloudBackupAccount();
    await _refreshCloudBackupAccountLabel();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Backup account updated.' : 'Unable to change backup account.',
        ),
      ),
    );
  }

  String _cloudBackupTitle() {
    if (kIsWeb) return 'Cloud backup';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Backup to Google Drive';
      case TargetPlatform.iOS:
        return 'Backup to iCloud';
      default:
        return 'Cloud backup';
    }
  }

  IconData _cloudBackupIcon() {
    if (kIsWeb) return Icons.cloud_outlined;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return Icons.backup_outlined;
      case TargetPlatform.iOS:
        return Icons.cloud_upload_outlined;
      default:
        return Icons.cloud_outlined;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit += 1;
    }
    final decimals = value >= 100 ? 0 : value >= 10 ? 1 : 2;
    return '${value.toStringAsFixed(decimals)} ${units[unit]}';
    }

  Future<void> _setVaultSort(String value) async {
    if (value != 'title' && value != 'last_accessed') return;
    setState(() => _vaultSort = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyVaultSort, value);
    } catch (_) {}
  }

  Future<void> _setNotesSort(String value) async {
    if (value != 'title' && value != 'last_accessed' && value != 'tags') {
      return;
    }
    setState(() => _notesSort = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyNotesSort, value);
    } catch (_) {}
  }

  Future<void> _showSortDefaultsDialog(
    BuildContext context, {
    required bool isNotes,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                isNotes ? 'Default sort for notes' : 'Default sort for keys',
              ),
            ),
            ListTile(
              title: const Text('Last accessed'),
              trailing: (isNotes ? _notesSort : _vaultSort) == 'last_accessed'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop('last_accessed'),
            ),
            ListTile(
              title: const Text('Title'),
              trailing: (isNotes ? _notesSort : _vaultSort) == 'title'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop('title'),
            ),
            if (isNotes)
              ListTile(
                title: const Text('Tags'),
                trailing: _notesSort == 'tags' ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop('tags'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null) return;
    if (isNotes) {
      await _setNotesSort(selected);
    } else {
      await _setVaultSort(selected);
    }
  }

  String _selectorLabelForValue(String value, List<_SelectorOption> options) {
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return options.isEmpty ? '' : options.first.label;
  }

  Future<void> _openSelectorSheet({
    required String title,
    required String value,
    required List<_SelectorOption> options,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(title)),
            ...options.map(
              (option) => ListTile(
                title: Text(option.label),
                trailing: option.value == value
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(option.value),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || selected == value) return;
    onSelected(selected);
  }

  void _enterVaultSelectionMode(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      _vaultSelectionMode = true;
      _selectedVaultItemIds.add(id);
    });
  }

  void _enterNotesSelectionMode(Map<String, dynamic> note) {
    final id = note['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      _notesSelectionMode = true;
      _selectedNoteIds.add(id);
    });
  }

  void _toggleVaultItemSelection(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      if (_selectedVaultItemIds.contains(id)) {
        _selectedVaultItemIds.remove(id);
      } else {
        _selectedVaultItemIds.add(id);
      }
      if (_selectedVaultItemIds.isEmpty) {
        _vaultSelectionMode = false;
      }
    });
  }

  void _toggleNoteSelection(Map<String, dynamic> note) {
    final id = note['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      if (_selectedNoteIds.contains(id)) {
        _selectedNoteIds.remove(id);
      } else {
        _selectedNoteIds.add(id);
      }
      if (_selectedNoteIds.isEmpty) {
        _notesSelectionMode = false;
      }
    });
  }

  void _clearVaultSelection() {
    setState(() {
      _vaultSelectionMode = false;
      _selectedVaultItemIds.clear();
    });
  }

  void _clearNotesSelection() {
    setState(() {
      _notesSelectionMode = false;
      _selectedNoteIds.clear();
    });
  }

  String _allItemsSelectionKey(Map<String, dynamic> row) {
    final kind = row['kind']?.toString() ?? 'item';
    final entry = row['entry'] as Map<String, dynamic>;
    final id = entry['id']?.toString() ?? '';
    return '$kind:$id';
  }

  void _enterAllItemsSelectionMode(Map<String, dynamic> row) {
    final key = _allItemsSelectionKey(row);
    if (key.endsWith(':')) return;
    setState(() {
      _allItemsSelectionMode = true;
      _selectedAllItemsKeys.add(key);
    });
  }

  void _toggleAllItemsSelection(Map<String, dynamic> row) {
    final key = _allItemsSelectionKey(row);
    if (key.endsWith(':')) return;
    setState(() {
      if (_selectedAllItemsKeys.contains(key)) {
        _selectedAllItemsKeys.remove(key);
      } else {
        _selectedAllItemsKeys.add(key);
      }
      if (_selectedAllItemsKeys.isEmpty) {
        _allItemsSelectionMode = false;
      }
    });
  }

  void _clearAllItemsSelection() {
    setState(() {
      _allItemsSelectionMode = false;
      _selectedAllItemsKeys.clear();
    });
  }

  Future<void> _togglePinSelectedAllItems() async {
    if (_selectedAllItemsKeys.isEmpty) return;
    final selectedItemIds = _selectedAllItemsKeys
        .where((key) => key.startsWith('item:'))
        .map((key) => key.substring(5))
        .toSet();
    final selectedNoteIds = _selectedAllItemsKeys
        .where((key) => key.startsWith('note:'))
        .map((key) => key.substring(5))
        .toSet();
    final selectedItems = _items
        .where((item) => selectedItemIds.contains(item['id']?.toString() ?? ''))
        .toList();
    final selectedNotes = _notes
        .where((note) => selectedNoteIds.contains(note['id']?.toString() ?? ''))
        .toList();
    if (selectedItems.isEmpty && selectedNotes.isEmpty) return;
    final shouldPin =
        selectedItems.any((item) => item['pinned'] != true) ||
        selectedNotes.any((note) => note['pinned'] != true);
    _lastPinnedStateItemById = <String, bool>{
      for (final item in selectedItems)
        item['id']?.toString() ?? '': item['pinned'] == true,
    };
    _lastPinnedStateNoteById = <String, bool>{
      for (final note in selectedNotes)
        note['id']?.toString() ?? '': note['pinned'] == true,
    };
    setState(() {
      for (final item in _items) {
        if (selectedItemIds.contains(item['id']?.toString() ?? '')) {
          item['pinned'] = shouldPin;
        }
      }
      for (final note in _notes) {
        if (selectedNoteIds.contains(note['id']?.toString() ?? '')) {
          note['pinned'] = shouldPin;
        }
      }
      _allItemsSelectionMode = false;
      _selectedAllItemsKeys.clear();
    });
    await _persistVaultData();
    if (!mounted) return;
    final changedCount =
        _lastPinnedStateItemById.length + _lastPinnedStateNoteById.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shouldPin
              ? '$changedCount item(s) added to favorites'
              : '$changedCount item(s) removed from favorites',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: _undoAllItemsPinChange,
        ),
      ),
    );
  }

  Future<void> _deleteSelectedAllItems() async {
    if (_selectedAllItemsKeys.isEmpty) return;
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline, size: 34, color: Color(0xFFEF4444)),
              const SizedBox(height: 10),
              const Text(
                'Move to Trash?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '${_selectedAllItemsKeys.length} items will be moved to trash.\nThis action can be undone.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Move to Trash'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldDelete != true) return;
    final selectedItemIds = _selectedAllItemsKeys
        .where((key) => key.startsWith('item:'))
        .map((key) => key.substring(5))
        .toSet();
    final selectedNoteIds = _selectedAllItemsKeys
        .where((key) => key.startsWith('note:'))
        .map((key) => key.substring(5))
        .toSet();
    _lastDeletedAllItems = <_IndexedEntry>[
      for (var i = 0; i < _items.length; i++)
        if (selectedItemIds.contains(_items[i]['id']?.toString() ?? ''))
          _IndexedEntry(
            kind: 'item',
            index: i,
            entry: _deepCopyEntry(_items[i]),
          ),
      for (var i = 0; i < _notes.length; i++)
        if (selectedNoteIds.contains(_notes[i]['id']?.toString() ?? ''))
          _IndexedEntry(
            kind: 'note',
            index: i,
            entry: _deepCopyEntry(_notes[i]),
          ),
    ];
    setState(() {
      _items.removeWhere((item) => selectedItemIds.contains(item['id']?.toString() ?? ''));
      _notes.removeWhere((note) => selectedNoteIds.contains(note['id']?.toString() ?? ''));
      _allItemsSelectionMode = false;
      _selectedAllItemsKeys.clear();
    });
    await _persistVaultData();
    if (!mounted) return;
    final deletedCount = _lastDeletedAllItems.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$deletedCount items moved to trash'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: _undoAllItemsDelete,
        ),
      ),
    );
  }

  void _showSelectionActionComingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.settingComingSoon)));
  }

  Future<void> _showAllItemsMoreActions() async {
    if (_selectedAllItemsKeys.isEmpty) return;
    final selectedItemIds = _selectedAllItemsKeys
        .where((key) => key.startsWith('item:'))
        .map((key) => key.substring(5))
        .toSet();
    final selectedNoteIds = _selectedAllItemsKeys
        .where((key) => key.startsWith('note:'))
        .map((key) => key.substring(5))
        .toSet();
    final selectedItems = _items
        .where((item) => selectedItemIds.contains(item['id']?.toString() ?? ''))
        .toList();
    final selectedNotes = _notes
        .where((note) => selectedNoteIds.contains(note['id']?.toString() ?? ''))
        .toList();
    final hasNonFavorite =
        selectedItems.any((item) => item['pinned'] != true) ||
        selectedNotes.any((note) => note['pinned'] != true);
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(hasNonFavorite ? Icons.star_outline : Icons.star),
              title: Text(
                hasNonFavorite ? 'Add to Favorites' : 'Remove from Favorites',
              ),
              onTap: () => Navigator.of(context).pop('favorite'),
            ),
            ListTile(
              enabled: false,
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('Export'),
            ),
            ListTile(
              enabled: false,
              leading: const Icon(Icons.category_outlined),
              title: const Text('Change Category'),
            ),
            ListTile(
              enabled: false,
              leading: const Icon(Icons.label_outlined),
              title: const Text('Add Tags'),
            ),
            ListTile(
              enabled: false,
              leading: const Icon(Icons.merge_type_outlined),
              title: const Text('Merge'),
            ),
          ],
        ),
      ),
    );
    if (selected == 'favorite') {
      await _togglePinSelectedAllItems();
    }
  }

  Future<void> _undoAllItemsDelete() async {
    if (_lastDeletedAllItems.isEmpty) return;
    setState(() {
      final itemSnapshots = _lastDeletedAllItems
          .where((entry) => entry.kind == 'item')
          .toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      for (final snapshot in itemSnapshots) {
        final insertAt = snapshot.index.clamp(0, _items.length) as int;
        _items.insert(insertAt, _deepCopyEntry(snapshot.entry));
      }
      final noteSnapshots = _lastDeletedAllItems
          .where((entry) => entry.kind == 'note')
          .toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      for (final snapshot in noteSnapshots) {
        final insertAt = snapshot.index.clamp(0, _notes.length) as int;
        _notes.insert(insertAt, _deepCopyEntry(snapshot.entry));
      }
      _lastDeletedAllItems = <_IndexedEntry>[];
    });
    await _persistVaultData();
  }

  Future<void> _undoAllItemsPinChange() async {
    if (_lastPinnedStateItemById.isEmpty && _lastPinnedStateNoteById.isEmpty) {
      return;
    }
    setState(() {
      for (final item in _items) {
        final id = item['id']?.toString() ?? '';
        final previous = _lastPinnedStateItemById[id];
        if (previous != null) item['pinned'] = previous;
      }
      for (final note in _notes) {
        final id = note['id']?.toString() ?? '';
        final previous = _lastPinnedStateNoteById[id];
        if (previous != null) note['pinned'] = previous;
      }
      _lastPinnedStateItemById = <String, bool>{};
      _lastPinnedStateNoteById = <String, bool>{};
    });
    await _persistVaultData();
  }

  Map<String, dynamic> _deepCopyEntry(Map<String, dynamic> entry) {
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(entry)) as Map);
  }

  Future<void> _deleteSelectedVaultItems() async {
    if (_selectedVaultItemIds.isEmpty) return;
    setState(() {
      _items.removeWhere(
        (item) => _selectedVaultItemIds.contains(item['id']?.toString() ?? ''),
      );
      _vaultSelectionMode = false;
      _selectedVaultItemIds.clear();
    });
    await _persistVaultData();
  }

  Future<void> _deleteSelectedNotes() async {
    if (_selectedNoteIds.isEmpty) return;
    setState(() {
      _notes.removeWhere(
        (note) => _selectedNoteIds.contains(note['id']?.toString() ?? ''),
      );
      _notesSelectionMode = false;
      _selectedNoteIds.clear();
    });
    await _persistVaultData();
  }

  Future<void> _togglePinSelectedVaultItems() async {
    if (_selectedVaultItemIds.isEmpty) return;
    final selectedItems = _items
        .where(
          (item) =>
              _selectedVaultItemIds.contains(item['id']?.toString() ?? ''),
        )
        .toList();
    if (selectedItems.isEmpty) return;
    final shouldPin = selectedItems.any((item) => item['pinned'] != true);
    setState(() {
      for (final item in _items) {
        final id = item['id']?.toString() ?? '';
        if (_selectedVaultItemIds.contains(id)) {
          item['pinned'] = shouldPin;
        }
      }
    });
    await _persistVaultData();
  }

  Future<void> _togglePinSelectedNotes() async {
    if (_selectedNoteIds.isEmpty) return;
    final selectedNotes = _notes
        .where(
          (note) => _selectedNoteIds.contains(note['id']?.toString() ?? ''),
        )
        .toList();
    if (selectedNotes.isEmpty) return;
    final shouldPin = selectedNotes.any((note) => note['pinned'] != true);
    setState(() {
      for (final note in _notes) {
        final id = note['id']?.toString() ?? '';
        if (_selectedNoteIds.contains(id)) {
          note['pinned'] = shouldPin;
        }
      }
    });
    await _persistVaultData();
  }

  String _itemPlainText(Map<String, dynamic> item) {
    final buffer = StringBuffer();
    buffer.writeln(item['title']?.toString() ?? 'Untitled');
    buffer.writeln('Type: ${item['type']?.toString() ?? 'Item'}');
    final fields = (item['fields'] as List<dynamic>? ?? const <dynamic>[])
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    for (final field in fields) {
      final label = field['label']?.toString() ?? 'Field';
      final value = field['value']?.toString() ?? '';
      if (value.trim().isEmpty) continue;
      buffer.writeln('$label: $value');
    }
    return buffer.toString().trim();
  }

  String _notePlainText(Map<String, dynamic> note) {
    final buffer = StringBuffer();
    buffer.writeln(note['title']?.toString() ?? 'Untitled note');
    final fullText = _extractNoteBodyShareText(note);
    if (fullText.isNotEmpty) {
      buffer.writeln(fullText);
    }
    return buffer.toString().trim();
  }

  String _noteListPreviewText(Map<String, dynamic> note) {
    final delta = note['delta'];
    if (delta is! List) {
      return note['preview']?.toString() ?? '';
    }
    try {
      final lines = <String>[];
      final currentLine = StringBuffer();
      var orderedIndex = 0;
      for (final raw in delta) {
        final op = Map<String, dynamic>.from(raw as Map);
        final insert = op['insert'];
        if (insert is! String) continue;
        final attrs = Map<String, dynamic>.from(
          (op['attributes'] as Map?) ?? const <String, dynamic>{},
        );
        final parts = insert.split('\n');
        for (var i = 0; i < parts.length; i++) {
          final isLineBreak = i < parts.length - 1;
          if (parts[i].isNotEmpty) {
            currentLine.write(parts[i]);
          }
          if (!isLineBreak) continue;
          final lineText = currentLine.toString().trim();
          currentLine.clear();
          if (lineText.isEmpty) {
            if (attrs['list'] != 'ordered') orderedIndex = 0;
            continue;
          }
          final listType = attrs['list']?.toString();
          if (listType == 'ordered') {
            orderedIndex += 1;
            lines.add('$orderedIndex. $lineText');
          } else if (listType == 'bullet') {
            orderedIndex = 0;
            lines.add('• $lineText');
          } else {
            orderedIndex = 0;
            lines.add(lineText);
          }
          if (lines.length >= 2) {
            return lines.join(' ');
          }
        }
      }
      final trailing = currentLine.toString().trim();
      if (trailing.isNotEmpty) {
        lines.add(trailing);
      }
      if (lines.isNotEmpty) return lines.join(' ');
    } catch (_) {
      // Fallback below.
    }
    return note['preview']?.toString() ?? '';
  }

  String _extractNoteBodyShareText(Map<String, dynamic> note) {
    final delta = note['delta'];
    if (delta is List) {
      try {
        final lines = <String>[];
        final currentLine = StringBuffer();
        final segmentAttrs = <Map<String, dynamic>>[];
        var orderedIndex = 0;

        String applyInlineAttrs(String text, Map<String, dynamic> attrs) {
          var out = text;
          if (attrs['code'] == true) out = '`$out`';
          if (attrs['bold'] == true) out = '**$out**';
          if (attrs['italic'] == true) out = '_${out}_';
          if (attrs['strike'] == true) out = '~~$out~~';
          return out;
        }

        String applyBlockAttrs(String content, Map<String, dynamic> attrs) {
          final listType = attrs['list']?.toString();
          if (listType == 'ordered') {
            orderedIndex += 1;
            return '$orderedIndex. $content';
          }
          if (listType == 'bullet') {
            orderedIndex = 0;
            return '• $content';
          }
          if (listType == 'checked') {
            orderedIndex = 0;
            return '[x] $content';
          }
          if (listType == 'unchecked') {
            orderedIndex = 0;
            return '[ ] $content';
          }
          orderedIndex = 0;
          if (attrs['header'] == 1) return '# $content';
          if (attrs['header'] == 2) return '## $content';
          if (attrs['header'] == 3) return '### $content';
          if (attrs['blockquote'] == true) return '> $content';
          if (attrs['code-block'] == true) return '```$content```';
          return content;
        }

        for (final raw in delta) {
          final op = Map<String, dynamic>.from(raw as Map);
          final insert = op['insert'];
          if (insert is! String) continue;
          final attrs = Map<String, dynamic>.from(
            (op['attributes'] as Map?) ?? const <String, dynamic>{},
          );

          final parts = insert.split('\n');
          for (var i = 0; i < parts.length; i++) {
            final segment = parts[i];
            final isLineBreak = i < parts.length - 1;
            if (segment.isNotEmpty) {
              currentLine.write(applyInlineAttrs(segment, attrs));
              segmentAttrs.add(attrs);
            }
            if (!isLineBreak) continue;

            final content = currentLine.toString().trim();
            final baseAttrs = segmentAttrs.isNotEmpty
                ? Map<String, dynamic>.from(segmentAttrs.last)
                : <String, dynamic>{};
            final lineAttrs = <String, dynamic>{...baseAttrs, ...attrs};
            if (content.isNotEmpty) {
              lines.add(applyBlockAttrs(content, lineAttrs));
            } else {
              orderedIndex = 0;
            }
            currentLine.clear();
            segmentAttrs.clear();
          }
        }

        final trailing = currentLine.toString().trim();
        if (trailing.isNotEmpty) {
          final trailingAttrs = segmentAttrs.isNotEmpty
              ? segmentAttrs.last
              : const <String, dynamic>{};
          lines.add(applyBlockAttrs(trailing, trailingAttrs));
        }

        if (lines.isNotEmpty) {
          return lines.join('\n').trim();
        }
      } catch (_) {
        // Fallback handled below.
      }
    }
    return note['preview']?.toString().trim() ?? '';
  }

  List<String> _vaultTypeFilterOptions() {
    final types =
        _items
            .map((entry) => entry['type']?.toString().trim() ?? '')
            .where((entry) => entry.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['all', ...types];
  }

  List<String> _notesTagFilterOptions() {
    final tags = <String>{};
    for (final note in _notes) {
      final raw = (note['tags'] as List<dynamic>? ?? const <dynamic>[]);
      for (final entry in raw) {
        final cleaned = entry.toString().trim().toLowerCase();
        if (cleaned.isNotEmpty) {
          tags.add(cleaned);
        }
      }
    }
    final sorted = tags.toList()..sort();
    return ['all', ...sorted];
  }

  Future<void> _showNoteQuickActions(
    BuildContext context,
    Map<String, dynamic> note,
  ) async {
    final pinned = note['pinned'] == true;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('note-action-pin'),
              leading: Icon(pinned ? Icons.star_outline : Icons.star),
              title: Text(pinned ? AppStrings.unpin : AppStrings.pin),
              onTap: () => Navigator.of(context).pop('pin'),
            ),
            ListTile(
              key: const ValueKey('note-action-delete'),
              leading: const Icon(Icons.delete_outline),
              title: Text(AppStrings.delete),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
            ListTile(
              key: const ValueKey('note-action-share'),
              leading: const Icon(Icons.share_outlined),
              title: Text(AppStrings.sharePlainText),
              onTap: () => Navigator.of(context).pop('share_plain'),
            ),
            ListTile(
              key: const ValueKey('note-action-share-encrypted'),
              leading: const Icon(Icons.enhanced_encryption_outlined),
              title: Text(AppStrings.shareEncryptedFile),
              onTap: () => Navigator.of(context).pop('share_encrypted'),
            ),
            ListTile(
              key: const ValueKey('note-action-export-encrypted'),
              leading: const Icon(Icons.file_download_outlined),
              title: Text(AppStrings.exportEncryptedFile),
              onTap: () => Navigator.of(context).pop('export_encrypted'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    final idx = _notes.indexWhere(
      (entry) => entry['id']?.toString() == note['id']?.toString(),
    );
    if (idx == -1) return;
    if (selected == 'pin') {
      setState(() => _notes[idx]['pinned'] = !pinned);
      await _persistVaultData();
      return;
    }
    if (selected == 'share_plain') {
      final content = _notePlainText(note);
      await _clipboard.copySensitive(content);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.sharedTextCopied)));
      return;
    }
    if (selected == 'share_encrypted') {
      if (!mounted) return;
      await _shareEncryptedSecret(
        plainText: _notePlainText(note),
        suggestedBaseName: note['title']?.toString() ?? 'note',
        contentType: 'note',
      );
      return;
    }
    if (selected == 'export_encrypted') {
      if (!mounted) return;
      await _exportEncryptedSecret(
        plainText: _notePlainText(note),
        suggestedBaseName: note['title']?.toString() ?? 'note',
        contentType: 'note',
      );
      return;
    }
    setState(() => _notes.removeAt(idx));
    await _persistVaultData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.noteDeleted)));
  }

  Future<void> _showItemQuickActions(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final pinned = item['pinned'] == true;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('item-action-pin'),
              leading: Icon(pinned ? Icons.star_outline : Icons.star),
              title: Text(pinned ? AppStrings.unpin : AppStrings.pin),
              onTap: () => Navigator.of(context).pop('pin'),
            ),
            ListTile(
              key: const ValueKey('item-action-delete'),
              leading: const Icon(Icons.delete_outline),
              title: Text(AppStrings.delete),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
            ListTile(
              key: const ValueKey('item-action-share'),
              leading: const Icon(Icons.share_outlined),
              title: Text(AppStrings.sharePlainText),
              onTap: () => Navigator.of(context).pop('share_plain'),
            ),
            ListTile(
              key: const ValueKey('item-action-share-encrypted'),
              leading: const Icon(Icons.enhanced_encryption_outlined),
              title: Text(AppStrings.shareEncryptedFile),
              onTap: () => Navigator.of(context).pop('share_encrypted'),
            ),
            ListTile(
              key: const ValueKey('item-action-export-encrypted'),
              leading: const Icon(Icons.file_download_outlined),
              title: Text(AppStrings.exportEncryptedFile),
              onTap: () => Navigator.of(context).pop('export_encrypted'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    final idx = _items.indexWhere(
      (entry) => entry['id']?.toString() == item['id']?.toString(),
    );
    if (idx == -1) return;
    if (selected == 'pin') {
      setState(() => _items[idx]['pinned'] = !pinned);
      await _persistVaultData();
      return;
    }
    if (selected == 'share_plain') {
      final content = _itemPlainText(item);
      await _clipboard.copySensitive(content);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.sharedTextCopied)));
      return;
    }
    if (selected == 'share_encrypted') {
      if (!mounted) return;
      await _shareEncryptedSecret(
        plainText: _itemPlainText(item),
        suggestedBaseName: item['title']?.toString() ?? 'item',
        contentType: 'vault_item',
      );
      return;
    }
    if (selected == 'export_encrypted') {
      if (!mounted) return;
      await _exportEncryptedSecret(
        plainText: _itemPlainText(item),
        suggestedBaseName: item['title']?.toString() ?? 'item',
        contentType: 'vault_item',
      );
      return;
    }
    setState(() => _items.removeAt(idx));
    await _persistVaultData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.itemDeleted)));
  }

  Future<void> _shareEncryptedSecret({
    required String plainText,
    required String suggestedBaseName,
    required String contentType,
  }) async {
    final choice = await _promptEncryptedShareInputs(
      context,
      suggestedBaseName: suggestedBaseName,
      title: AppStrings.shareEncryptedFile,
      actionLabel: AppStrings.shareEncryptedFile,
    );
    if (choice == null) return;

    try {
      final payload = await _encryptedShareCodec.encode(
        plainText: plainText,
        password: choice.password,
        fileName: choice.fileName,
        contentType: contentType,
      );
      final ok = await _secretSharePortability.shareEncryptedFile(
        suggestedName: choice.fileName,
        content: payload,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppStrings.encryptedShareSuccess
                : AppStrings.encryptedShareFailed,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.encryptedShareFailed)));
    }
  }

  Future<void> _exportEncryptedSecret({
    required String plainText,
    required String suggestedBaseName,
    required String contentType,
  }) async {
    final choice = await _promptEncryptedShareInputs(
      context,
      suggestedBaseName: suggestedBaseName,
      title: AppStrings.exportEncryptedFile,
      actionLabel: AppStrings.exportEncryptedFile,
    );
    if (choice == null) return;

    try {
      final payload = await _encryptedShareCodec.encode(
        plainText: plainText,
        password: choice.password,
        fileName: choice.fileName,
        contentType: contentType,
      );
      final ok = await _secretSharePortability.exportEncryptedFile(
        suggestedName: choice.fileName,
        content: payload,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppStrings.encryptedExportSuccess
                : AppStrings.encryptedExportFailed,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.encryptedExportFailed)));
    }
  }

  Future<_EncryptedShareChoice?> _promptEncryptedShareInputs(
    BuildContext context, {
    required String suggestedBaseName,
    required String title,
    required String actionLabel,
  }) async {
    final passwordController = TextEditingController();
    final fileNameController = TextEditingController(
      text: '${_sanitizeFileName(suggestedBaseName)}$_encryptedShareExtension',
    );
    try {
      final result = await showDialog<_EncryptedShareChoice>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setLocalState) {
            final rawName = fileNameController.text.trim();
            final hasName = rawName.isNotEmpty;
            final hasPassword = passwordController.text.trim().isNotEmpty;
            final canShare = hasName && hasPassword;
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fileNameController,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: const InputDecoration(labelText: 'File name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    onChanged: (_) => setLocalState(() {}),
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
                          final normalizedName = _ensureEncryptedShareExtension(
                            fileNameController.text.trim(),
                          );
                          Navigator.of(context).pop(
                            _EncryptedShareChoice(
                              fileName: normalizedName,
                              password: passwordController.text,
                            ),
                          );
                        }
                      : null,
                  child: Text(actionLabel),
                ),
              ],
            );
          },
        ),
      );
      return result;
    } finally {
      passwordController.dispose();
      fileNameController.dispose();
    }
  }

  String _ensureEncryptedShareExtension(String fileName) {
    if (fileName.toLowerCase().endsWith(_encryptedShareExtension)) {
      return fileName;
    }
    return '$fileName$_encryptedShareExtension';
  }

  String _sanitizeFileName(String raw) {
    final normalized = raw.trim().isEmpty ? 'secret' : raw.trim();
    final clean = normalized.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return clean.isEmpty ? 'secret' : clean;
  }

  Future<void> _importEncryptedSecret() async {
    final imported = await _secretSharePortability.importEncryptedFile();
    if (imported == null || !mounted) return;
    final password = await _promptSecretImportPassword(context);
    if (password == null || password.trim().isEmpty || !mounted) return;
    try {
      final decoded = await _encryptedShareCodec.decode(
        encoded: imported.content,
        password: password.trim(),
      );
      final applied = _applyImportedSecret(decoded);
      if (!applied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.encryptedSecretImportFailed)),
        );
        return;
      }
      await _persistVaultData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImported)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImportFailed)),
      );
    }
  }

  Future<String?> _promptSecretImportPassword(BuildContext context) async {
    final controller = TextEditingController();
    try {
      return showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setLocalState) {
            final canContinue = controller.text.trim().isNotEmpty;
            return AlertDialog(
              title: Text(AppStrings.importEncryptedSecret),
              content: TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                onChanged: (_) => setLocalState(() {}),
                decoration: InputDecoration(
                  labelText: AppStrings.encryptedSecretPassword,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canContinue
                      ? () => Navigator.of(context).pop(controller.text.trim())
                      : null,
                  child: const Text('Import'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  bool _applyImportedSecret(DecryptedSharePayload payload) {
    final normalized = payload.contentType.trim().toLowerCase();
    if (normalized == 'note') {
      final note = _noteFromImported(payload.plainText);
      if (note == null) return false;
      setState(() => _notes.insert(0, note));
      return true;
    }
    if (normalized == 'vault_item') {
      final item = _itemFromImported(payload.plainText);
      if (item == null) return false;
      setState(() => _items.insert(0, item));
      return true;
    }
    return false;
  }

  Map<String, dynamic>? _noteFromImported(String plainText) {
    final lines = plainText.split('\n');
    final nonEmpty = lines.where((line) => line.trim().isNotEmpty).toList();
    if (nonEmpty.isEmpty) return null;
    final title = nonEmpty.first.trim();
    final body = lines.skip(1).join('\n').trim();
    final id = 'note-imported-${DateTime.now().microsecondsSinceEpoch}';
    return {
      'id': id,
      'title': title,
      'preview': body.isEmpty ? title : body.split('\n').first.trim(),
      'updated': 'Now',
      'pinned': false,
      'tags': <String>['imported'],
      'delta': [
        {'insert': '${body.isEmpty ? title : body}\n'},
      ],
    };
  }

  Map<String, dynamic>? _itemFromImported(String plainText) {
    final lines = plainText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;
    final title = lines.first;
    String type = 'Item';
    final fields = <Map<String, dynamic>>[];
    for (final line in lines.skip(1)) {
      if (line.startsWith('Type: ')) {
        final parsedType = line.substring(6).trim();
        if (parsedType.isNotEmpty) type = parsedType;
        continue;
      }
      final sep = line.indexOf(':');
      if (sep <= 0 || sep >= line.length - 1) continue;
      final label = line.substring(0, sep).trim();
      final value = line.substring(sep + 1).trim();
      if (label.isEmpty || value.isEmpty) continue;
      fields.add({'label': label, 'value': value, 'sensitive': false});
    }
    final subtitle = fields.isEmpty
        ? 'Imported secret'
        : fields.first['value']?.toString() ?? 'Imported secret';
    final id = 'item-imported-${DateTime.now().microsecondsSinceEpoch}';
    return {
      'id': id,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'updated': 'Now',
      'pinned': false,
      'fields': fields,
    };
  }
}

class _EncryptedShareChoice {
  const _EncryptedShareChoice({required this.fileName, required this.password});

  final String fileName;
  final String password;
}

class _SortSelector extends StatelessWidget {
  const _SortSelector({
    super.key,
    required this.label,
    required this.icon,
    required this.selectedLabel,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String selectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF52525B)),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Expanded(child: Text(selectedLabel)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectorOption {
  const _SelectorOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    required this.selectionMode,
    required this.selected,
    required this.onLeadingTap,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onLeadingTap;

  @override
  Widget build(BuildContext context) {
    final tags = (item['tags'] as List<dynamic>? ?? const <dynamic>[])
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: selectionMode
            ? Checkbox(value: selected, onChanged: (_) => onTap())
            : InkWell(
                key: ValueKey('vault-leading-${item['id']}'),
                borderRadius: BorderRadius.circular(10),
                onTap: onLeadingTap,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconForType(item['type'].toString()), size: 18),
                ),
              ),
        title: Text(
          item['title'].toString(),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 2),
            Text(item['subtitle'].toString()),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF0F2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item['type']?.toString() ?? 'Item',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3F3F46),
                ),
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags
                    .take(2)
                    .map((tag) => _TinyChip(label: '#$tag'))
                    .toList(),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${AppStrings.lastAccessed}: ${item['updated']?.toString() ?? 'Now'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: const Color(0xFF71717A),
              ),
            ),
            if (item['pinned'] == true)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
              ),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'Card':
        return Icons.credit_card;
      case 'Identity':
        return Icons.badge_outlined;
      default:
        return Icons.key_outlined;
    }
  }
}

IconData _iconForSetting(String section) {
  if (section == AppStrings.settingsSecurity) return Icons.security_outlined;
  if (section == AppStrings.settingsVaultBackup) return Icons.backup_outlined;
  if (section == AppStrings.settingsBiometricUnlock) return Icons.fingerprint;
  if (section == AppStrings.settingsRecoveryPhrase) return Icons.key_outlined;
  if (section == AppStrings.settingsAutoLock) return Icons.lock_clock_outlined;
  if (section == AppStrings.settingsExportVault) {
    return Icons.file_upload_outlined;
  }
  if (section == AppStrings.settingsDangerZone) {
    return Icons.warning_amber_outlined;
  }
  return Icons.settings_outlined;
}

class _ItemDetailScreen extends StatefulWidget {
  const _ItemDetailScreen({
    required this.item,
    required this.onCopy,
    required this.onShareSecurely,
    required this.customTypeDefinitions,
    this.showDeleteAction = false,
  });

  final Map<String, dynamic> item;
  final ValueChanged<String> onCopy;
  final Future<void> Function() onShareSecurely;
  final List<Map<String, dynamic>> customTypeDefinitions;
  final bool showDeleteAction;

  @override
  State<_ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<_ItemDetailScreen> {
  final Set<int> _revealedIndexes = <int>{};
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.item['pinned'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final fields = (widget.item['fields'] as List<dynamic>? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    final itemType = widget.item['type']?.toString() ?? 'Item';
    final title = widget.item['title']?.toString() ?? 'Untitled';
    final created = widget.item['created_at']?.toString() ?? 'Unknown';
    final modified = widget.item['updated']?.toString() ?? 'Now';
    final primarySecret = _extractPrimarySecret(fields);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _closeWithUpdates();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            onPressed: _closeWithUpdates,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(itemType),
          actions: [
            IconButton(
              onPressed: () => setState(() => _isFavorite = !_isFavorite),
              icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
              tooltip: 'Favorite',
            ),
            TextButton(
              onPressed: () async {
                final updated = await Navigator.of(context)
                    .push<Map<String, dynamic>>(
                      MaterialPageRoute(
                        builder: (_) => AddVaultItemScreen(
                          customTypeDefinitions: widget.customTypeDefinitions,
                          initialItem: widget.item,
                        ),
                      ),
                    );
                if (updated == null || !context.mounted) return;
                if (_isFavorite != (widget.item['pinned'] == true)) {
                  updated['pinned'] = _isFavorite;
                }
                Navigator.of(context).pop(updated);
              },
              child: Text(AppStrings.edit),
            ),
            if (widget.showDeleteAction)
              IconButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(<String, dynamic>{'__delete__': true}),
                icon: const Icon(Icons.delete_outline),
                tooltip: AppStrings.delete,
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF4F46E5),
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: List.generate(fields.length, (index) {
                          final field = fields[index];
                          final sensitive = field['sensitive'] == true;
                          final revealed = _revealedIndexes.contains(index);
                          final value = field['value']?.toString() ?? '';
                          final displayValue = sensitive && !revealed
                              ? '••••••••••'
                              : value;
                          return Column(
                            children: [
                              if (index > 0)
                                const Divider(height: 16, thickness: 0.5),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          field['label']?.toString() ?? 'Field',
                                          style: const TextStyle(
                                            color: Color(0xFF6B7280),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          displayValue,
                                          style: const TextStyle(
                                            color: Color(0xFF111827),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (sensitive)
                                    IconButton(
                                      icon: Icon(
                                        revealed
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (revealed) {
                                            _revealedIndexes.remove(index);
                                          } else {
                                            _revealedIndexes.add(index);
                                          }
                                        });
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 18),
                                    onPressed: value.isEmpty
                                        ? null
                                        : () => widget.onCopy(value),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _metadataRow('Category', itemType),
                    const SizedBox(height: 8),
                    _metadataRow('Created', created),
                    const SizedBox(height: 8),
                    _metadataRow('Modified', modified),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: primarySecret == null
                            ? null
                            : () => widget.onCopy(primarySecret),
                        child: const Text('Copy Password'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => widget.onShareSecurely(),
                        child: const Text('Share Securely'),
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

  String? _extractPrimarySecret(List<Map<String, dynamic>> fields) {
    if (fields.isEmpty) return null;
    for (final field in fields) {
      final label = field['label']?.toString().toLowerCase() ?? '';
      if (label.contains('password') || label.contains('passcode')) {
        final value = field['value']?.toString() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    for (final field in fields) {
      if (field['sensitive'] == true) {
        final value = field['value']?.toString() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    final fallback = fields.first['value']?.toString() ?? '';
    return fallback.isEmpty ? null : fallback;
  }

  Widget _metadataRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _closeWithUpdates() {
    final pinnedWas = widget.item['pinned'] == true;
    if (pinnedWas == _isFavorite) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(
      context,
    ).pop(<String, dynamic>{...widget.item, 'pinned': _isFavorite});
  }
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

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 11,
          color: const Color(0xFF3F3F46),
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
        Text(title, style: Theme.of(context).textTheme.titleLarge),
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
    default:
      return Icons.auto_awesome_outlined;
  }
}

Color _colorForCustomTemplateKey(String? key) {
  switch (key) {
    case 'lock':
      return const Color(0xFF60A5FA);
    case 'note':
      return const Color(0xFFFBBF24);
    case 'id':
      return const Color(0xFF34D399);
    case 'wallet':
      return const Color(0xFF22C55E);
    case 'folder':
      return const Color(0xFFFB923C);
    case 'heart':
      return const Color(0xFFF472B6);
    case 'star':
      return const Color(0xFFF59E0B);
    case 'spark':
      return const Color(0xFF6366F1);
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeItemsScreen extends StatelessWidget {
  const _TypeItemsScreen({
    required this.type,
    required this.items,
    this.onOpenItem,
    this.onOpenNote,
    this.onItemActions,
    this.onNoteActions,
  });

  final String type;
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>>? onOpenItem;
  final ValueChanged<Map<String, dynamic>>? onOpenNote;
  final ValueChanged<Map<String, dynamic>>? onItemActions;
  final ValueChanged<Map<String, dynamic>>? onNoteActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(type)),
      body: items.isEmpty
          ? _EmptyState(
              title: AppStrings.noItemsYet,
              subtitle: AppStrings.noItemsYetHint,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final title = item['title']?.toString() ?? 'Untitled';
                final subtitle =
                    item['subtitle']?.toString() ??
                    item['preview']?.toString() ??
                    '';
                final updated = item['updated']?.toString() ?? '';

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    title: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: subtitle.isEmpty
                        ? null
                        : Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (updated.isNotEmpty)
                          Text(
                            updated,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'More actions',
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {
                            if (onNoteActions != null) {
                              onNoteActions!(item);
                              return;
                            }
                            onItemActions?.call(item);
                          },
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onLongPress: () {
                      if (onNoteActions != null) {
                        onNoteActions!(item);
                        return;
                      }
                      onItemActions?.call(item);
                    },
                    onTap: () {
                      if (onOpenNote != null) {
                        onOpenNote!(item);
                        return;
                      }
                      if (onOpenItem != null) {
                        onOpenItem!(item);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF0F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF3F3F46),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.selectedCount,
    required this.onClear,
    required this.onPin,
    required this.onDelete,
  });

  final int selectedCount;
  final VoidCallback onClear;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const ValueKey('selection-clear'),
          onPressed: onClear,
          icon: const Icon(Icons.arrow_back),
        ),
        Text(
          '$selectedCount',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        IconButton(
          key: const ValueKey('selection-pin'),
          onPressed: onPin,
          icon: const Icon(Icons.star_outline),
          tooltip: AppStrings.pin,
        ),
        IconButton(
          key: const ValueKey('selection-delete'),
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          tooltip: AppStrings.deleteSelected,
        ),
      ],
    );
  }
}

class _AllItemsSelectionActionBar extends StatelessWidget {
  const _AllItemsSelectionActionBar({
    required this.onShare,
    required this.onMove,
    required this.onLock,
    required this.onDelete,
    required this.onMore,
  });

  final VoidCallback onShare;
  final VoidCallback onMove;
  final VoidCallback onLock;
  final VoidCallback onDelete;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          _SelectionActionNavItem(
            key: const ValueKey('selection-action-share'),
            icon: Icons.ios_share_outlined,
            label: 'Share',
            onTap: onShare,
          ),
          _SelectionActionNavItem(
            key: const ValueKey('selection-action-move'),
            icon: Icons.drive_file_move_outline,
            label: 'Move',
            onTap: onMove,
          ),
          _SelectionActionNavItem(
            key: const ValueKey('selection-action-lock'),
            icon: Icons.lock_outline,
            label: 'Lock',
            onTap: onLock,
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
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: const Color(0xFF374151)),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndexedEntry {
  const _IndexedEntry({
    required this.kind,
    required this.index,
    required this.entry,
  });

  final String kind;
  final int index;
  final Map<String, dynamic> entry;
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
  State<_AllItemsFiltersOverlay> createState() => _AllItemsFiltersOverlayState();
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
      color: Colors.white,
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
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
                      fillColor: const Color(0xFFF7F8FC),
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
                    children: [
                      ('any', 'Anytime'),
                      ('today', 'Today'),
                      ('last_7_days', 'Last 7 Days'),
                      ('last_30_days', 'Last 30 Days'),
                    ].map((row) {
                      final selected = row.$1 == _dateRange;
                      return ChoiceChip(
                        label: Text(row.$2),
                        selected: selected,
                        onSelected: (_) => setState(() => _dateRange = row.$1),
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
                    const Text(
                      'No active filters',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
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
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          if (trailing != null) trailing,
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
