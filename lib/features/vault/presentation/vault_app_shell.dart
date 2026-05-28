import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_features.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/security/encrypted_share_codec.dart';
import '../../../core/security/secure_clipboard.dart';
import '../../../domain/validators/vault_validators.dart';
import '../../../infrastructure/adapters/secret_share_portability.dart';
import '../../../infrastructure/adapters/secret_share_portability_base.dart';
import 'add_vault_item_screen.dart';
import 'create_custom_type_screen.dart';
import 'document_upload_screen.dart';
import 'note_editor_screen.dart';
import 'widgets/vault_entry_list.dart';
import 'widgets/vault_page_heading.dart';

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
typedef PersistVaultDocument =
    Future<String> Function({
      required String documentId,
      required List<int> bytes,
    });
typedef ReadVaultDocument =
    Future<List<int>> Function({required String sectionName});
typedef LifecycleLockSuppressed = void Function(bool suppressed);
typedef VaultFileAction = Future<void> Function();
typedef CloudBackupAction = Future<void> Function();
typedef CloudBackupAccountRead = Future<String?> Function();
typedef CloudBackupAccountChange = Future<bool> Function();
typedef RenameVault = Future<void> Function(String name);
typedef ReadVaultInternals = Future<Map<String, dynamic>> Function();

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
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
    this.autoLockSeconds = 300,
    this.onAutoLockSecondsChanged,
    required this.biometricEnabled,
    required this.onBiometricChanged,
    required this.onPersistVaultData,
    this.onPersistVaultDocument,
    this.onReadVaultDocument,
    this.onLifecycleLockSuppressed,
    required this.onRotateMasterPassword,
    required this.onRotateRecoveryPhrase,
    required this.onLockNow,
    required this.onExportVault,
    required this.onImportVault,
    required this.onBackupToCloud,
    required this.onRestoreFromCloud,
    required this.onReadCloudBackupAccount,
    required this.onChangeCloudBackupAccount,
    this.onRenameVault,
    this.onReadVaultInternals,
  });

  final List<String> recoveryWords;
  final String activeVaultName;
  final int vaultSizeBytes;
  final List<Map<String, dynamic>> initialItems;
  final List<Map<String, dynamic>> initialNotes;
  final List<Map<String, dynamic>> initialCustomTypeDefinitions;
  final String languageMode;
  final LanguageModeChanged onLanguageModeChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final int autoLockSeconds;
  final ValueChanged<int>? onAutoLockSecondsChanged;
  final bool biometricEnabled;
  final BiometricChanged onBiometricChanged;
  final PersistVaultData onPersistVaultData;
  final PersistVaultDocument? onPersistVaultDocument;
  final ReadVaultDocument? onReadVaultDocument;
  final LifecycleLockSuppressed? onLifecycleLockSuppressed;
  final RotateMasterPassword onRotateMasterPassword;
  final RotateRecoveryPhrase onRotateRecoveryPhrase;
  final VoidCallback onLockNow;
  final VaultFileAction onExportVault;
  final VaultFileAction onImportVault;
  final CloudBackupAction onBackupToCloud;
  final CloudBackupAction onRestoreFromCloud;
  final CloudBackupAccountRead onReadCloudBackupAccount;
  final CloudBackupAccountChange onChangeCloudBackupAccount;
  final RenameVault? onRenameVault;
  final ReadVaultInternals? onReadVaultInternals;

  @override
  State<VaultAppShell> createState() => _VaultAppShellState();
}

class _VaultAppShellState extends State<VaultAppShell> {
  static const MethodChannel _documentOpenChannel = MethodChannel(
    'nija/document_open',
  );
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
  final _allItemsSearchController = TextEditingController();
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
  bool _importingEncryptedSecret = false;
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
  late final List<VaultListEntryAdapter> _vaultListEntryAdapters;
  late String _activeVaultName;

  List<_IndexedEntry> _lastDeletedAllItems = <_IndexedEntry>[];
  Map<String, bool> _lastPinnedStateItemById = <String, bool>{};
  Map<String, bool> _lastPinnedStateNoteById = <String, bool>{};
  DateTime? _lastBackOnDashboardAt;

  @override
  void initState() {
    super.initState();
    _activeVaultName = widget.activeVaultName;
    _customTypeDefinitions = widget.initialCustomTypeDefinitions
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    _items = widget.initialItems
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    _notes = widget.initialNotes
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    _vaultListEntryAdapters = [
      const VaultDocumentListEntryAdapter(),
      VaultItemListEntryAdapter(
        iconForType: _iconForDashboardType,
        colorForType: _colorForDashboardType,
      ),
      const VaultNoteListEntryAdapter(),
    ];
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
  void didUpdateWidget(covariant VaultAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeVaultName != widget.activeVaultName) {
      _activeVaultName = widget.activeVaultName;
    }
    if (!listEquals(oldWidget.initialItems, widget.initialItems)) {
      _items
        ..clear()
        ..addAll(
          widget.initialItems.map((entry) => Map<String, dynamic>.from(entry)),
        );
      _selectedVaultItemIds.clear();
      _selectedAllItemsKeys.removeWhere((key) => key.startsWith('item:'));
    }
    if (!listEquals(oldWidget.initialNotes, widget.initialNotes)) {
      _notes
        ..clear()
        ..addAll(
          widget.initialNotes.map((entry) => Map<String, dynamic>.from(entry)),
        );
      _selectedNoteIds.clear();
      _selectedAllItemsKeys.removeWhere((key) => key.startsWith('note:'));
    }
    if (!listEquals(
      oldWidget.initialCustomTypeDefinitions,
      widget.initialCustomTypeDefinitions,
    )) {
      _customTypeDefinitions
        ..clear()
        ..addAll(
          widget.initialCustomTypeDefinitions.map(
            (entry) => Map<String, dynamic>.from(entry),
          ),
        );
    }
  }

  @override
  void dispose() {
    _allItemsSearchController.dispose();
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pages = [
      _buildVaultTab(context),
      _buildTypesTab(context),
      _buildFavoritesTab(context),
      _buildSettingsTab(context),
      if (kDebugMode) _buildDebugInternalsTab(context),
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
            backgroundColor: colorScheme.surface,
            indicatorColor: Colors.transparent,
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
              states,
            ) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  color: colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                );
              }
              return TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
              if (states.contains(WidgetState.selected)) {
                return IconThemeData(color: colorScheme.primary, size: 22);
              }
              return IconThemeData(
                color: colorScheme.onSurfaceVariant,
                size: 22,
              );
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
              if (kDebugMode)
                const NavigationDestination(
                  icon: Icon(Icons.bug_report_outlined),
                  label: 'Debug',
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
    final colorScheme = Theme.of(context).colorScheme;
    final recentAll =
        <Map<String, dynamic>>[
              ..._items.map(
                (item) => <String, dynamic>{'kind': 'item', 'entry': item},
              ),
              ..._notes.map(
                (note) => <String, dynamic>{'kind': 'note', 'entry': note},
              ),
            ]
            .where((row) {
              final entry = row['entry'] as Map<String, dynamic>;
              return _activityAt(entry) != null;
            })
            .map((row) {
              final entry = row['entry'] as Map<String, dynamic>;
              return {...row, 'updatedLabel': _activityLabel(entry)};
            })
            .toList()
          ..sort((a, b) {
            final av = a['entry'] as Map<String, dynamic>;
            final bv = b['entry'] as Map<String, dynamic>;
            return _activityAt(bv)!.compareTo(_activityAt(av)!);
          });
    final recentItems = recentAll.take(4).toList();
    final typeCounts = <String, int>{};
    for (final item in _items) {
      final type = item['type']?.toString().trim();
      if (type == null || type.isEmpty) continue;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    final dashboardTypes = <MapEntry<String, int>>[
      if (_notes.isNotEmpty) MapEntry<String, int>('Notes', _notes.length),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nija', style: vaultPageHeadingStyle(context)),
                    Text(
                      _activeVaultName,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _openAddItemScreen(context),
                  icon: Icon(Icons.add, color: colorScheme.onSurfaceVariant),
                  tooltip: 'Create',
                ),
                IconButton(
                  onPressed: widget.onLockNow,
                  icon: Icon(
                    Icons.lock_outline,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Text(
              'All your important information,\nin one secure place.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search your data...',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      prefixIcon: Icon(
                        Icons.search,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => setState(() => _query = value),
                    onSubmitted: _applyDashboardSearchToAllItems,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    key: const ValueKey('dashboard-filter-selector'),
                    onPressed: () => _openAllItemsFiltersOverlay(
                      _allTypeFilterOptions(),
                      showAllItemsOnApply: true,
                    ),
                    icon: Icon(Icons.tune, color: colorScheme.onSurfaceVariant),
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
                        icon: _iconForDashboardType(entry.key),
                        accent: _colorForDashboardType(entry.key),
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
                            ?.copyWith(fontWeight: FontWeight.w700),
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
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        'No recent items yet.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    VaultEntryList(
                      rows: recentItems,
                      adapters: _vaultListEntryAdapters,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      iconAlpha: 0.2,
                      rowPadding: const EdgeInsets.all(12),
                      trailingMode: VaultEntryTrailingMode.chevron,
                      keyForRow: _vaultListKeyForRow,
                      onTap: (row) => _openVaultListRow(context, row),
                      onLongPress: (row) =>
                          _showVaultListRowQuickActions(context, row),
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
                          style: vaultPageHeadingStyle(context),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          key: const ValueKey('notes-info-icon'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showNotesInfoDialog(context),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                              child: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: const Icon(
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
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    final all = <Map<String, dynamic>>[
      ..._items.map((item) => <String, dynamic>{'kind': 'item', 'entry': item}),
      ..._notes.map((note) => <String, dynamic>{'kind': 'note', 'entry': note}),
    ];
    all.sort((a, b) {
      final av = a['entry'] as Map<String, dynamic>;
      final bv = b['entry'] as Map<String, dynamic>;
      return _entryUpdatedSortValue(bv).compareTo(_entryUpdatedSortValue(av));
    });

    final sortedTypeOptions = ['all', ..._allTypeFilterOptions()];

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
      final subtitle =
          (kind == 'note'
                  ? entry['preview']?.toString()
                  : entry['subtitle']?.toString())
              ?.toLowerCase() ??
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
      final matchesFavorite =
          !_allItemsFilterFavoritesOnly || entry['pinned'] == true;
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
                  Text('All Items', style: vaultPageHeadingStyle(context)),
                const Spacer(),
                if (_allItemsSelectionMode)
                  Text(
                    '${_selectedAllItemsKeys.length} Selected',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const Spacer(),
                if (_allItemsSelectionMode)
                  const SizedBox.shrink()
                else
                  IconButton(
                    onPressed: () => _openAddItemScreen(context),
                    icon: Icon(Icons.add, color: colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
            if (!_allItemsSelectionMode)
              Text(
                '${filtered.length} items',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _allItemsSearchController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search all items...',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      prefixIcon: Icon(
                        Icons.search,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) =>
                        setState(() => _allItemsQuery = value),
                  ),
                ),
                const SizedBox(width: 8),
                if (!_allItemsSelectionMode)
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: () => _openAllItemsFiltersOverlay(
                        sortedTypeOptions.where((t) => t != 'all').toList(),
                      ),
                      icon: Icon(
                        Icons.tune,
                        color: colorScheme.onSurfaceVariant,
                      ),
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
                      label: Text(type == 'all' ? 'All' : type),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _allItemsTypeFilter = type),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      selectedColor: colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
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
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Clear all',
                        style: TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (!_allItemsSelectionMode)
              Text(
                'Sort by: Modified (newest)',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No items found.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : VaultEntryList(
                      rows: filtered,
                      adapters: _vaultListEntryAdapters,
                      selectionMode: _allItemsSelectionMode,
                      selectedKeys: _selectedAllItemsKeys,
                      keyForRow: _allItemsSelectionKey,
                      trailingMode: _allItemsSelectionMode
                          ? VaultEntryTrailingMode.chevron
                          : VaultEntryTrailingMode.more,
                      onTap: (row) {
                        if (_allItemsSelectionMode) {
                          _toggleAllItemsSelection(row);
                          return;
                        }
                        _openVaultListRow(context, row);
                      },
                      onLongPress: (row) {
                        if (_allItemsSelectionMode) {
                          _toggleAllItemsSelection(row);
                          return;
                        }
                        _enterAllItemsSelectionMode(row);
                      },
                      onMoreTap: (row) =>
                          _showVaultListRowQuickActions(context, row),
                    ),
            ),
            if (_allItemsSelectionMode)
              _AllItemsSelectionActionBar(
                onFavorite: _togglePinSelectedAllItems,
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
    final allFavorites =
        <Map<String, dynamic>>[...favoriteItems, ...favoriteNotes]
          ..sort((a, b) {
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
          _SectionHeader(
            title: AppStrings.tabNotes,
            subtitle: 'Starred secrets',
          ),
          const SizedBox(height: 10),
          Expanded(
            child: allFavorites.isEmpty
                ? const _EmptyState(
                    title: 'No favorites yet',
                    subtitle: 'Star items from quick actions to see them here.',
                  )
                : VaultEntryList(
                    rows: allFavorites,
                    adapters: _vaultListEntryAdapters,
                    keyForRow: _vaultListKeyForRow,
                    trailingMode: VaultEntryTrailingMode.more,
                    forceFavoriteIndicator: true,
                    onTap: (row) => _openVaultListRow(context, row),
                    onLongPress: (row) =>
                        _showVaultListRowQuickActions(context, row),
                    onMoreTap: (row) =>
                        _showVaultListRowQuickActions(context, row),
                  ),
          ),
        ],
      ),
    );
  }

  String _vaultListKeyForRow(Map<String, dynamic> row) {
    final kind = row['kind']?.toString() ?? 'item';
    final entry = row['entry'] as Map<String, dynamic>;
    final id = entry['id']?.toString() ?? '';
    return '$kind:$id';
  }

  void _openVaultListRow(BuildContext context, Map<String, dynamic> row) {
    final kind = row['kind']?.toString() ?? 'item';
    final entry = row['entry'] as Map<String, dynamic>;
    if (kind == 'note') {
      _openNoteDetail(context, entry);
    } else if (_isDocumentItem(entry)) {
      _openDocumentDetail(context, entry);
    } else {
      _openItemDetail(context, entry);
    }
  }

  void _showVaultListRowQuickActions(
    BuildContext context,
    Map<String, dynamic> row,
  ) {
    final kind = row['kind']?.toString() ?? 'item';
    final entry = row['entry'] as Map<String, dynamic>;
    if (kind == 'note') {
      _showNoteQuickActions(context, entry);
    } else if (_isDocumentItem(entry)) {
      _showDocumentQuickActions(context, entry);
    } else {
      _showItemQuickActions(context, entry);
    }
  }

  bool _isDocumentItem(Map<String, dynamic> item) {
    return item['type']?.toString() == 'Documents' ||
        item['documentSection'] != null ||
        item['documentFileName'] != null;
  }

  Future<void> _openDocumentDetail(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final accessedItem = _markItemLastAccessed(item);
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _DocumentDetailScreen(
          item: accessedItem,
          onReadDocument: widget.onReadVaultDocument,
          onShareEncryptedDocument: _shareEncryptedDocument,
          onExportEncryptedDocument: _exportEncryptedDocument,
          showDeleteAction: true,
        ),
      ),
    );
    if (result == null) {
      if (mounted) setState(() {});
      return;
    }
    final idx = _items.indexWhere(
      (entry) => entry['id']?.toString() == accessedItem['id']?.toString(),
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
    setState(() => _items[idx] = _preserveLastAccessedAt(result, _items[idx]));
    await _persistVaultData();
  }

  int _updatedSortValue(String text) {
    final digits = RegExp(r'\d+').firstMatch(text)?.group(0);
    if (digits == null) return 0;
    return int.tryParse(digits) ?? 0;
  }

  int _entryUpdatedSortValue(Map<String, dynamic> entry) {
    final timestamp =
        _parseEntryTimestamp(entry['updatedAt']) ??
        _parseEntryTimestamp(entry['documentUploadedAt']) ??
        _parseEntryTimestamp(entry['createdAt']);
    if (timestamp != null) return timestamp.millisecondsSinceEpoch;
    return _updatedRank(entry);
  }

  int _lastAccessedSortValue(Map<String, dynamic> entry) {
    final parsed = _lastAccessedAt(entry);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
    return _updatedRank(entry);
  }

  DateTime? _lastAccessedAt(Map<String, dynamic> entry) {
    return _parseEntryTimestamp(entry['lastAccessedAt']);
  }

  DateTime? _activityAt(Map<String, dynamic> entry) {
    return _lastAccessedAt(entry) ??
        _parseEntryTimestamp(entry['updatedAt']) ??
        _parseEntryTimestamp(entry['documentUploadedAt']) ??
        _parseEntryTimestamp(entry['createdAt']);
  }

  DateTime? _parseEntryTimestamp(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String _activityLabel(Map<String, dynamic> entry) {
    final activityAt = _activityAt(entry);
    if (activityAt == null) return 'Now';
    return _relativeTimeLabel(activityAt);
  }

  String _relativeTimeLabel(DateTime timestamp) {
    final elapsed = DateTime.now().toUtc().difference(timestamp.toUtc());
    if (elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
    if (elapsed.inDays == 1) return '1d ago';
    return '${elapsed.inDays}d ago';
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

  void _applyDashboardSearchToAllItems(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    setState(() {
      _query = query;
      _allItemsQuery = query;
      _allItemsSearchController.text = query;
      _allItemsSearchController.selection = TextSelection.collapsed(
        offset: query.length,
      );
      _tabIndex = 1;
    });
  }

  Map<String, dynamic>? _customTypeDefinitionForType(String type) {
    final normalized = type.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final definition in _customTypeDefinitions) {
      final name = definition['name']?.toString().trim().toLowerCase();
      if (name == normalized) return definition;
    }
    return null;
  }

  IconData _iconForDashboardType(String type) {
    final definition = _customTypeDefinitionForType(type);
    final iconKey = definition?['iconKey']?.toString();
    if (iconKey != null) return _iconForCustomTemplateKey(iconKey);
    return _iconForHomeType(type);
  }

  Color _colorForDashboardType(String type) {
    final definition = _customTypeDefinitionForType(type);
    final colorKey = definition?['colorKey']?.toString();
    if (colorKey != null) return _colorForCustomTemplateColorKey(colorKey);
    return _colorForHomeType(type);
  }

  Future<void> _openAllItemsFiltersOverlay(
    List<String> typeOptions, {
    bool showAllItemsOnApply = false,
  }) async {
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
      if (showAllItemsOnApply) {
        _tabIndex = 1;
      }
    });
  }

  List<String> _allTypeFilterOptions() {
    final options = <String>{};

    if (_notes.isNotEmpty) {
      options.add('Notes');
    }

    for (final item in _items) {
      final type = item['type']?.toString().trim();
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

    final defaultViewLabel = _vaultSort == 'title' ? 'Title' : 'All Items';
    final themeLabel = switch (widget.themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };
    final autoLockLabel = _formatAutoLockSeconds(widget.autoLockSeconds);
    final backupSubtitle = AppFeatures.isPaidBuild
        ? (_cloudBackupEnabled
              ? _cloudBackupLastAtEpochMs <= 0
                    ? 'Last backup: Never'
                    : 'Last backup: ${DateTime.fromMillisecondsSinceEpoch(_cloudBackupLastAtEpochMs)}'
              : 'Backup your data locally')
        : 'Available in paid version';

    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Text('Settings', style: vaultPageHeadingStyle(context)),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Account',
            children: [
              _SettingsRow(
                icon: Icons.dashboard_customize_outlined,
                title: 'Nija User',
                subtitle: _activeVaultName,
                onTap: () => _showRenameVaultDialog(context),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Security',
            children: [
              _SettingsRow(
                icon: Icons.lock_outline,
                title: 'Master Password',
                subtitle: 'Change your master password',
                onTap: () => _showRotateMasterPasswordDialog(context),
              ),
              _SettingsRow(
                key: const ValueKey('settings-auto-lock-row'),
                icon: Icons.key_outlined,
                title: AppStrings.settingsAutoLock,
                subtitle: 'Lock Nija automatically',
                value: autoLockLabel,
                onTap: () => _showAutoLockPicker(context),
              ),
              _SettingsRow(
                key: const ValueKey('settings-biometrics-switch'),
                icon: _iconForSetting(AppStrings.settingsBiometricUnlock),
                title: AppStrings.settingsBiometricUnlock,
                subtitle: 'Unlock using fingerprint or face',
                trailing: Switch(
                  value: widget.biometricEnabled,
                  onChanged: widget.onBiometricChanged,
                ),
              ),
              _SettingsRow(
                icon: Icons.shield_outlined,
                title: 'Security & Encryption',
                subtitle: 'View encryption details and key info',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppStrings.settingComingSoon)),
                  );
                },
              ),
            ],
          ),
          _SettingsSection(
            title: 'Cloud Backup',
            children: [
              _SettingsRow(
                key: const ValueKey('settings-cloud-backup-switch'),
                icon: _cloudBackupIcon(),
                title: _cloudBackupTitle(),
                subtitle: backupSubtitle,
                onTap: AppFeatures.isPaidBuild
                    ? () => _setCloudBackupEnabled(!_cloudBackupEnabled)
                    : null,
              ),
              if (AppFeatures.isPaidBuild && _cloudBackupEnabled) ...[
                _SettingsRow(
                  key: const ValueKey('settings-cloud-backup-auto-switch'),
                  icon: Icons.schedule_outlined,
                  title: 'Auto backup',
                  subtitle: _cloudBackupFrequency == 'weekly'
                      ? 'Weekly'
                      : _cloudBackupFrequency == 'monthly'
                      ? 'Monthly'
                      : 'Daily',
                  trailing: Switch(
                    value: _cloudBackupAutoEnabled,
                    onChanged: _setCloudBackupAutoEnabled,
                  ),
                  onTap: _showCloudBackupFrequencyPicker,
                ),
                _SettingsRow(
                  icon: Icons.account_circle_outlined,
                  title: 'Backup account',
                  subtitle: _cloudBackupAccountLabel,
                  onTap: _handleChangeCloudBackupAccount,
                ),
                _SettingsActionRow(
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('settings-cloud-backup-now'),
                      onPressed: _handleCloudBackupNow,
                      icon: Icon(_cloudBackupIcon()),
                      label: const Text('Backup now'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('settings-cloud-restore-now'),
                      onPressed: widget.onRestoreFromCloud,
                      icon: const Icon(Icons.restore_outlined),
                      label: const Text('Restore'),
                    ),
                  ],
                ),
              ],
            ],
          ),
          _SettingsSection(
            title: 'Data',
            children: [
              _SettingsRow(
                key: const ValueKey('settings-import-encrypted-secret'),
                icon: Icons.file_download_outlined,
                title: 'Import',
                subtitle: _importingEncryptedSecret
                    ? 'Importing data...'
                    : 'Import data from a file',
                trailing: _importingEncryptedSecret
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _importingEncryptedSecret
                    ? null
                    : _importEncryptedSecret,
              ),
              _SettingsRow(
                icon: Icons.file_upload_outlined,
                title: 'Export',
                subtitle: 'Export data to a file',
                onTap: widget.onExportVault,
              ),
              _SettingsRow(
                icon: Icons.sd_storage_outlined,
                title: 'Vault size',
                subtitle: _formatBytes(widget.vaultSizeBytes),
              ),
              _SettingsRow(
                icon: Icons.delete_outline,
                iconColor: const Color(0xFFFF5D5D),
                title: 'Clear Data',
                subtitle: 'Permanently delete all your data',
                danger: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppStrings.settingComingSoon)),
                  );
                },
              ),
            ],
          ),
          _SettingsSection(
            title: 'Preferences',
            children: [
              _SettingsRow(
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: 'Choose app appearance',
                value: themeLabel,
                onTap: () => _showThemePicker(context),
              ),
              _SettingsRow(
                key: const ValueKey('settings-default-vault-filter'),
                icon: Icons.grid_view_outlined,
                title: 'Default View',
                subtitle: 'Choose your default start view',
                value: defaultViewLabel,
                onTap: () => _showSortDefaultsDialog(context, isNotes: false),
              ),
              _SettingsRow(
                key: const ValueKey('settings-default-notes-filter'),
                icon: Icons.filter_alt_outlined,
                title: 'Default notes sort',
                subtitle: _notesSort == 'title'
                    ? 'Title'
                    : _notesSort == 'tags'
                    ? 'Tags'
                    : 'Last accessed',
                onTap: () => _showSortDefaultsDialog(context, isNotes: true),
              ),
              _SettingsRow(
                icon: Icons.folder_outlined,
                title: 'Categories',
                subtitle: '${_customTypeDefinitions.length} custom templates',
                onTap: () => _showCustomTemplateManager(context),
              ),
              _SettingsRow(
                icon: Icons.notifications_none_outlined,
                title: 'Notifications',
                subtitle: 'Manage reminders and alerts',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppStrings.settingComingSoon)),
                  );
                },
              ),
              _SettingsRow(
                icon: Icons.language_outlined,
                title: AppStrings.language,
                subtitle: languageLabel,
                onTap: () => _showLanguagePicker(context),
              ),
            ],
          ),
          _SettingsSection(
            title: 'About',
            children: [
              _SettingsRow(
                icon: Icons.info_outline,
                title: 'About Nija',
                subtitle: 'Version 1.0.0',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nija version 1.0.0')),
                  );
                },
              ),
              _SettingsRow(
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'Get help and contact support',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppStrings.settingComingSoon)),
                  );
                },
              ),
              _SettingsRow(
                icon: Icons.verified_user_outlined,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppStrings.settingComingSoon)),
                  );
                },
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                title: 'Terms of Use',
                subtitle: 'Read our terms and conditions',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppStrings.settingComingSoon)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: widget.onLockNow,
            child: Text(AppStrings.lockVaultNow),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugInternalsTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: FutureBuilder<Map<String, dynamic>>(
        future: widget.onReadVaultInternals?.call(),
        builder: (context, snapshot) {
          final data = snapshot.data;
          return ListView(
            children: [
              const _SectionHeader(
                title: 'Vault internals',
                subtitle: 'Debug-only storage metadata and encrypted sections.',
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError || data == null)
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.error_outline,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    title: const Text('Unable to read internals'),
                    subtitle: Text(
                      snapshot.error?.toString() ?? 'No data',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              else ...[
                _DebugInfoCard(
                  title: 'Snapshot',
                  rows: _debugRows(data, const [
                    'format',
                    'formatVersion',
                    'schemaVersion',
                    'storageLayoutVersion',
                    'manifestVersion',
                    'snapshotBytes',
                  ]),
                ),
                const SizedBox(height: 10),
                _DebugInfoCard(
                  title: 'Identity',
                  rows: _debugRows(data, const [
                    'vaultId',
                    'vaultVersionId',
                    'revision',
                    'createdAt',
                    'updatedAt',
                    'lastModifiedByDeviceId',
                  ]),
                ),
                const SizedBox(height: 10),
                _DebugInfoCard(
                  title: 'Crypto',
                  rows: _debugMapRows(data['crypto']),
                ),
                const SizedBox(height: 10),
                _DebugInfoCard(
                  title: 'Encrypted sections',
                  rows: _debugMapRows(data['encryptedSections']),
                ),
                const SizedBox(height: 10),
                _DebugInfoCard(
                  title: 'Working folder',
                  rows: _workingFolderRows(data['workingStore']),
                ),
                const SizedBox(height: 10),
                _DebugInfoCard(
                  title: 'Working files',
                  rows: _workingFileRows(data['workingStore']),
                ),
                const SizedBox(height: 10),
                _DebugInfoCard(
                  title: 'Session',
                  rows: [
                    MapEntry<String, String>(
                      'activeVaultName',
                      _activeVaultName,
                    ),
                    MapEntry<String, String>(
                      'vaultSizeBytes',
                      widget.vaultSizeBytes.toString(),
                    ),
                    MapEntry<String, String>('items', _items.length.toString()),
                    MapEntry<String, String>('notes', _notes.length.toString()),
                    MapEntry<String, String>(
                      'customTypes',
                      _customTypeDefinitions.length.toString(),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<MapEntry<String, String>> _debugRows(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    return keys
        .where((key) => data.containsKey(key))
        .map((key) => MapEntry<String, String>(key, data[key].toString()))
        .toList();
  }

  List<MapEntry<String, String>> _debugMapRows(dynamic value) {
    if (value is! Map) return const <MapEntry<String, String>>[];
    return value.entries
        .map(
          (entry) => MapEntry<String, String>(
            entry.key.toString(),
            entry.value.toString(),
          ),
        )
        .toList();
  }

  List<MapEntry<String, String>> _workingFolderRows(dynamic value) {
    if (value is! Map) return const <MapEntry<String, String>>[];
    return <MapEntry<String, String>>[
      MapEntry<String, String>('type', value['type']?.toString() ?? ''),
      MapEntry<String, String>('root', value['root']?.toString() ?? ''),
      const MapEntry<String, String>(
        'layout',
        'header.json, manifest.enc, items.enc, notes.enc, settings.enc, tags.enc',
      ),
    ];
  }

  List<MapEntry<String, String>> _workingFileRows(dynamic value) {
    if (value is! Map) return const <MapEntry<String, String>>[];
    final files = value['files'];
    if (files is! Map) return const <MapEntry<String, String>>[];
    final rows =
        files.entries
            .map(
              (entry) => MapEntry<String, String>(
                entry.key.toString(),
                '${entry.value} bytes',
              ),
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return rows;
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
            final nextPassword = nextController.text.trim();
            final canSubmit =
                currentController.text.trim().isNotEmpty &&
                nextPassword.isNotEmpty &&
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
                  _PasswordStrengthMeter(password: nextPassword),
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

  Future<void> _showThemePicker(BuildContext context) async {
    final onThemeModeChanged = widget.onThemeModeChanged;
    if (onThemeModeChanged == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.settingComingSoon)));
      return;
    }

    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Theme')),
              _themeOptionTile(context, ThemeMode.system, 'System'),
              _themeOptionTile(context, ThemeMode.light, 'Light'),
              _themeOptionTile(context, ThemeMode.dark, 'Dark'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null || selected == widget.themeMode) return;
    onThemeModeChanged(selected);
  }

  Widget _themeOptionTile(BuildContext context, ThemeMode mode, String label) {
    final selected = widget.themeMode == mode;
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(mode),
    );
  }

  Future<void> _showAutoLockPicker(BuildContext context) async {
    final onChanged = widget.onAutoLockSecondsChanged;
    if (onChanged == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.settingComingSoon)));
      return;
    }

    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) =>
          _AutoLockSecondsSheet(initialSeconds: widget.autoLockSeconds),
    );
    if (selected == null || selected == widget.autoLockSeconds) return;
    onChanged(selected);
  }

  Future<void> _showRenameVaultDialog(BuildContext context) async {
    final renamed = await showDialog<String>(
      context: context,
      builder: (_) => _RenameVaultDialog(initialName: _activeVaultName),
    );
    if (renamed == null || renamed == _activeVaultName) return;

    try {
      await widget.onRenameVault?.call(renamed);
      if (!context.mounted) return;
      setState(() => _activeVaultName = renamed);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vault renamed')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to rename vault. Please retry.')),
      );
    }
  }

  Future<void> _openItemDetail(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final accessedItem = _markItemLastAccessed(item);
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _ItemDetailScreen(
          item: accessedItem,
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
    if (result == null) {
      if (mounted) setState(() {});
      return;
    }
    final idx = _items.indexWhere(
      (entry) => entry['id']?.toString() == accessedItem['id']?.toString(),
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
    setState(() => _items[idx] = _preserveLastAccessedAt(result, _items[idx]));
    await _persistVaultData();
  }

  Future<void> _shareEncryptedDocument(
    Map<String, dynamic> item,
    List<int> bytes,
  ) async {
    await _shareEncryptedSecret(
      plainText: _documentEncryptedPayload(item, bytes),
      suggestedBaseName: _documentSuggestedBaseName(item),
      contentType: 'document',
    );
  }

  Future<void> _exportEncryptedDocument(
    Map<String, dynamic> item,
    List<int> bytes,
  ) async {
    await _exportEncryptedSecret(
      plainText: _documentEncryptedPayload(item, bytes),
      suggestedBaseName: _documentSuggestedBaseName(item),
      contentType: 'document',
    );
  }

  Future<void> _openNoteDetail(
    BuildContext context,
    Map<String, dynamic> note,
  ) async {
    final accessedNote = _markNoteLastAccessed(note);
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => NoteViewScreen(
          note: accessedNote,
          showDeleteAction: true,
          onAutoSave: _upsertNoteAndPersist,
        ),
      ),
    );
    if (updated == null) {
      if (mounted) setState(() {});
      return;
    }

    final idx = _notes.indexWhere(
      (entry) => entry['id']?.toString() == accessedNote['id']?.toString(),
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

    setState(() => _notes[idx] = _preserveLastAccessedAt(updated, _notes[idx]));
    await _persistVaultData();
  }

  Map<String, dynamic> _markItemLastAccessed(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return item;
    final idx = _items.indexWhere((entry) => entry['id']?.toString() == id);
    if (idx == -1) return item;
    final updated = Map<String, dynamic>.from(_items[idx]);
    updated['lastAccessedAt'] = DateTime.now().toUtc().toIso8601String();
    setState(() => _items[idx] = updated);
    unawaited(_persistVaultData());
    return updated;
  }

  Map<String, dynamic> _markNoteLastAccessed(Map<String, dynamic> note) {
    final id = note['id']?.toString();
    if (id == null || id.isEmpty) return note;
    final idx = _notes.indexWhere((entry) => entry['id']?.toString() == id);
    if (idx == -1) return note;
    final updated = Map<String, dynamic>.from(_notes[idx]);
    updated['lastAccessedAt'] = DateTime.now().toUtc().toIso8601String();
    setState(() => _notes[idx] = updated);
    unawaited(_persistVaultData());
    return updated;
  }

  Map<String, dynamic> _preserveLastAccessedAt(
    Map<String, dynamic> next,
    Map<String, dynamic> current,
  ) {
    if (next['lastAccessedAt'] != null) return next;
    return {
      ...next,
      if (current['lastAccessedAt'] != null)
        'lastAccessedAt': current['lastAccessedAt'],
    };
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
          onCreateDocument: () async {
            return Navigator.of(context).push<Map<String, dynamic>>(
              MaterialPageRoute(
                builder: (_) => DocumentUploadScreen(
                  onLifecycleLockSuppressed: widget.onLifecycleLockSuppressed,
                ),
              ),
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
    final item = Map<String, dynamic>.from(entry);
    try {
      if (!await _isPendingDocumentStored(item)) return;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to store document. Please retry.'),
        ),
      );
      return;
    }
    setState(() => _items.insert(0, item));
    await _persistVaultData();
  }

  Future<bool> _isPendingDocumentStored(Map<String, dynamic> item) async {
    final rawBytes = item.remove('__documentBytes__');
    if (rawBytes == null) return true;
    if (widget.onPersistVaultDocument == null) {
      item['documentStorage'] = 'inline-unavailable';
      return true;
    }
    final bytes = rawBytes is Uint8List
        ? rawBytes
        : Uint8List.fromList(List<int>.from(rawBytes as List));
    final documentId = item['id']?.toString() ?? '';
    final sectionName = await widget.onPersistVaultDocument!(
      documentId: documentId,
      bytes: bytes,
    );
    item['documentStorage'] = 'private-section';
    item['documentSection'] = sectionName;
    return true;
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
    final updated = await Navigator.of(context)
        .push<List<Map<String, dynamic>>>(
          MaterialPageRoute(
            builder: (_) => _CustomTemplateManagerScreen(
              initialDefinitions: _customTypeDefinitions,
              onCommit: (definitions) async {
                if (!mounted) return;
                setState(() {
                  _syncItemsWithRenamedCustomTypes(
                    previousDefinitions: _customTypeDefinitions,
                    nextDefinitions: definitions,
                  );
                  _customTypeDefinitions
                    ..clear()
                    ..addAll(definitions);
                });
                await _persistVaultData();
              },
            ),
          ),
        );

    if (updated == null) return;
    setState(() {
      _syncItemsWithRenamedCustomTypes(
        previousDefinitions: _customTypeDefinitions,
        nextDefinitions: updated,
      );
      _customTypeDefinitions
        ..clear()
        ..addAll(updated);
    });
    await _persistVaultData();
  }

  void _syncItemsWithRenamedCustomTypes({
    required List<Map<String, dynamic>> previousDefinitions,
    required List<Map<String, dynamic>> nextDefinitions,
  }) {
    final limit = previousDefinitions.length < nextDefinitions.length
        ? previousDefinitions.length
        : nextDefinitions.length;
    final renamedTypes = <String, String>{};
    for (var index = 0; index < limit; index++) {
      final previousName = previousDefinitions[index]['name']
          ?.toString()
          .trim();
      final nextName = nextDefinitions[index]['name']?.toString().trim();
      if (previousName == null ||
          previousName.isEmpty ||
          nextName == null ||
          nextName.isEmpty ||
          previousName == nextName) {
        continue;
      }
      renamedTypes[previousName] = nextName;
    }
    if (renamedTypes.isEmpty) return;
    for (final item in _items) {
      final type = item['type']?.toString();
      final renamed = renamedTypes[type];
      if (renamed != null) {
        item['type'] = renamed;
      }
    }
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
    setState(
      () => _cloudBackupAccountLabel = (label == null || label.isEmpty)
          ? 'Not connected'
          : label,
    );
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
    if (mounted) setState(() {});
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
    final decimals = value >= 100
        ? 0
        : value >= 10
        ? 1
        : 2;
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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '${_selectedAllItemsKeys.length} items will be moved to trash.\nThis action can be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
      _items.removeWhere(
        (item) => selectedItemIds.contains(item['id']?.toString() ?? ''),
      );
      _notes.removeWhere(
        (note) => selectedNoteIds.contains(note['id']?.toString() ?? ''),
      );
      _allItemsSelectionMode = false;
      _selectedAllItemsKeys.clear();
    });
    await _persistVaultData();
    if (!mounted) return;
    final deletedCount = _lastDeletedAllItems.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$deletedCount items moved to trash'),
        action: SnackBarAction(label: 'Undo', onPressed: _undoAllItemsDelete),
      ),
    );
  }

  Future<void> _showAllItemsMoreActions() async {
    if (_selectedAllItemsKeys.isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.enhanced_encryption_outlined),
              title: Text(AppStrings.shareEncryptedFile),
              onTap: () => Navigator.of(context).pop('share_encrypted'),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: Text(AppStrings.exportEncryptedFile),
              onTap: () => Navigator.of(context).pop('export_encrypted'),
            ),
          ],
        ),
      ),
    );
    if (selected == 'share_encrypted') {
      await _shareSelectedAllItemsEncrypted();
    } else if (selected == 'export_encrypted') {
      await _exportSelectedAllItemsEncrypted();
    }
  }

  Future<void> _shareSelectedAllItemsEncrypted() async {
    final payload = await _selectedAllItemsEncryptedBundle();
    if (payload == null || !mounted) return;
    await _shareEncryptedSecret(
      plainText: payload,
      suggestedBaseName: _selectedAllItemsBundleBaseName(),
      contentType: 'vault_bundle',
    );
  }

  Future<void> _exportSelectedAllItemsEncrypted() async {
    final payload = await _selectedAllItemsEncryptedBundle();
    if (payload == null || !mounted) return;
    await _exportEncryptedSecret(
      plainText: payload,
      suggestedBaseName: _selectedAllItemsBundleBaseName(),
      contentType: 'vault_bundle',
    );
  }

  Future<String?> _selectedAllItemsEncryptedBundle() async {
    final entries = <Map<String, dynamic>>[];
    try {
      for (final item in _selectedItemsForAllItemsSelection()) {
        if (_isDocumentItem(item)) {
          final bytes = await _readDocumentBytesForAction(item);
          entries.add(_documentBundleEntry(item, bytes));
        } else {
          entries.add(<String, dynamic>{
            'kind': 'vault_item',
            'entry': _portableEntryCopy(item),
            'plainText': _itemPlainText(item),
          });
        }
      }
      for (final note in _selectedNotesForAllItemsSelection()) {
        entries.add(<String, dynamic>{
          'kind': 'note',
          'entry': _portableEntryCopy(note),
          'plainText': _notePlainText(note),
        });
      }
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read selected document.')),
      );
      return null;
    }
    if (entries.isEmpty) return null;
    return jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'kind': 'vault_bundle',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'count': entries.length,
      'entries': entries,
    });
  }

  List<Map<String, dynamic>> _selectedItemsForAllItemsSelection() {
    final selectedIds = _selectedAllItemsKeys
        .where((key) => key.startsWith('item:'))
        .map((key) => key.substring(5))
        .toSet();
    return _items
        .where((item) => selectedIds.contains(item['id']?.toString() ?? ''))
        .toList();
  }

  List<Map<String, dynamic>> _selectedNotesForAllItemsSelection() {
    final selectedIds = _selectedAllItemsKeys
        .where((key) => key.startsWith('note:'))
        .map((key) => key.substring(5))
        .toSet();
    return _notes
        .where((note) => selectedIds.contains(note['id']?.toString() ?? ''))
        .toList();
  }

  Map<String, dynamic> _documentBundleEntry(
    Map<String, dynamic> item,
    List<int> bytes,
  ) {
    return <String, dynamic>{
      'kind': 'document',
      'entry': _portableEntryCopy(item, removeDocumentStoragePointer: true),
      'fileName': _documentFileName(item),
      'extension': _documentExtension(item),
      'mimeType': _mimeTypeForExtension(_documentExtension(item)),
      'sizeBytes': bytes.length,
      'bytesBase64': base64Encode(bytes),
    };
  }

  Map<String, dynamic> _portableEntryCopy(
    Map<String, dynamic> entry, {
    bool removeDocumentStoragePointer = false,
  }) {
    final copy = _deepCopyEntry(entry)..remove('__documentBytes__');
    if (removeDocumentStoragePointer) {
      copy
        ..remove('documentSection')
        ..remove('documentStorage');
    }
    return copy;
  }

  String _selectedAllItemsBundleBaseName() {
    final count = _selectedAllItemsKeys.length;
    final timestamp = DateTime.now().toUtc().toIso8601String().split('.').first;
    return 'vault-$count-items-${timestamp.replaceAll(':', '')}';
  }

  Future<void> _undoAllItemsDelete() async {
    if (_lastDeletedAllItems.isEmpty) return;
    setState(() {
      final itemSnapshots =
          _lastDeletedAllItems.where((entry) => entry.kind == 'item').toList()
            ..sort((a, b) => a.index.compareTo(b.index));
      for (final snapshot in itemSnapshots) {
        final insertAt = snapshot.index.clamp(0, _items.length) as int;
        _items.insert(insertAt, _deepCopyEntry(snapshot.entry));
      }
      final noteSnapshots =
          _lastDeletedAllItems.where((entry) => entry.kind == 'note').toList()
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
      final segmentAttrs = <Map<String, dynamic>>[];
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
            segmentAttrs.add(attrs);
          }
          if (!isLineBreak) continue;
          final lineText = currentLine.toString().trim();
          currentLine.clear();
          final baseAttrs = segmentAttrs.isNotEmpty
              ? Map<String, dynamic>.from(segmentAttrs.last)
              : <String, dynamic>{};
          final lineAttrs = <String, dynamic>{...baseAttrs, ...attrs};
          segmentAttrs.clear();
          if (lineText.isEmpty) {
            if (lineAttrs['list'] != 'ordered') orderedIndex = 0;
            continue;
          }
          final listType = lineAttrs['list']?.toString();
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

  Future<void> _showDocumentQuickActions(
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
              key: const ValueKey('document-action-open'),
              leading: const Icon(Icons.open_in_new_outlined),
              title: const Text('Open document'),
              onTap: () => Navigator.of(context).pop('open'),
            ),
            ListTile(
              key: const ValueKey('document-action-pin'),
              leading: Icon(pinned ? Icons.star_outline : Icons.star),
              title: Text(pinned ? AppStrings.unpin : AppStrings.pin),
              onTap: () => Navigator.of(context).pop('pin'),
            ),
            ListTile(
              key: const ValueKey('document-action-share-encrypted'),
              leading: const Icon(Icons.enhanced_encryption_outlined),
              title: const Text('Share encrypted file'),
              onTap: () => Navigator.of(context).pop('share_encrypted'),
            ),
            ListTile(
              key: const ValueKey('document-action-export-encrypted'),
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Export encrypted file'),
              onTap: () => Navigator.of(context).pop('export_encrypted'),
            ),
            ListTile(
              key: const ValueKey('document-action-delete'),
              leading: const Icon(Icons.delete_outline),
              title: Text(AppStrings.delete),
              onTap: () => Navigator.of(context).pop('delete'),
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
    if (selected == 'open') {
      if (!context.mounted) return;
      await _openDocumentDetail(context, item);
      return;
    }
    if (selected == 'pin') {
      setState(() => _items[idx]['pinned'] = !pinned);
      await _persistVaultData();
      return;
    }
    if (selected == 'share_encrypted' || selected == 'export_encrypted') {
      try {
        final bytes = await _readDocumentBytesForAction(item);
        if (selected == 'share_encrypted') {
          await _shareEncryptedDocument(item, bytes);
        } else {
          await _exportEncryptedDocument(item, bytes);
        }
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read document.')),
        );
      }
      return;
    }
    setState(() => _items.removeAt(idx));
    await _persistVaultData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.itemDeleted)));
  }

  Future<List<int>> _readDocumentBytesForAction(
    Map<String, dynamic> item,
  ) async {
    final sectionName = item['documentSection']?.toString().trim() ?? '';
    final reader = widget.onReadVaultDocument;
    if (sectionName.isEmpty || reader == null) {
      throw StateError('Document reader unavailable.');
    }
    return reader(sectionName: sectionName);
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
    return showDialog<_EncryptedShareChoice>(
      context: context,
      builder: (context) => _EncryptedShareInputDialog(
        initialFileName:
            '${_sanitizeFileName(suggestedBaseName)}$_encryptedShareExtension',
        title: title,
        actionLabel: actionLabel,
        ensureExtension: _ensureEncryptedShareExtension,
      ),
    );
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
    if (_importingEncryptedSecret) return;
    setState(() => _importingEncryptedSecret = true);
    try {
      final imported = await _secretSharePortability.importEncryptedFile();
      if (imported == null || !mounted) return;
      final password = await _promptSecretImportPassword(context);
      if (password == null || password.trim().isEmpty || !mounted) return;
      await _waitForOverlayTeardown();
      final decoded = await _encryptedShareCodec.decode(
        encoded: imported.content,
        password: password.trim(),
      );
      if (decoded.contentType.trim().toLowerCase() == 'vault_bundle') {
        final entries = _encryptedImportEntriesFromBundle(decoded.plainText);
        if (entries.isNotEmpty) {
          if (!mounted) return;
          if (entries.length > 1) {
            final importedAny = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => _EncryptedImportBundleScreen(
                  entries: entries,
                  customTypeDefinitions: _customTypeDefinitions,
                  onImportEntry: _importEncryptedBundleEntry,
                  onImportAll: _importEncryptedBundleEntries,
                ),
              ),
            );
            if (!mounted || importedAny != true) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppStrings.encryptedSecretImported)),
            );
            return;
          }
          final importedSingle = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => _EncryptedImportEntryPreviewScreen(
                entry: entries.first,
                customTypeDefinitions: _customTypeDefinitions,
                alreadyImported: false,
                onImport: () => _importEncryptedBundleEntry(entries.first),
              ),
            ),
          );
          if (!mounted || importedSingle != true) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.encryptedSecretImported)),
          );
          return;
        }
      }
      final applied = await _applyImportedSecret(decoded);
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
    } finally {
      if (mounted) {
        setState(() => _importingEncryptedSecret = false);
      } else {
        _importingEncryptedSecret = false;
      }
    }
  }

  Future<void> _waitForOverlayTeardown() async {
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
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

  Future<bool> _applyImportedSecret(DecryptedSharePayload payload) async {
    final normalized = payload.contentType.trim().toLowerCase();
    if (normalized == 'note') {
      final note = _noteFromImported(payload.plainText);
      if (note == null) return false;
      _markImportedEntryVisible(note);
      setState(() => _notes.insert(0, note));
      return true;
    }
    if (normalized == 'vault_item') {
      final item = _itemFromImported(payload.plainText);
      if (item == null) return false;
      _markImportedEntryVisible(item);
      setState(() => _items.insert(0, item));
      return true;
    }
    if (normalized == 'document') {
      final item = await _documentFromImported(payload.plainText);
      if (item == null) return false;
      if (!mounted) return false;
      setState(() => _items.insert(0, item));
      return true;
    }
    if (normalized == 'vault_bundle') {
      return _applyImportedBundle(payload.plainText);
    }
    return false;
  }

  List<_EncryptedImportEntry> _encryptedImportEntriesFromBundle(
    String plainText,
  ) {
    final decoded = jsonDecode(plainText);
    if (decoded is! Map) return const <_EncryptedImportEntry>[];
    final root = Map<String, dynamic>.from(decoded);
    final entries = root['entries'];
    if (entries is! List) return const <_EncryptedImportEntry>[];
    final result = <_EncryptedImportEntry>[];
    for (var i = 0; i < entries.length; i++) {
      final raw = entries[i];
      if (raw is! Map) continue;
      final entry = Map<String, dynamic>.from(raw);
      final kind = entry['kind']?.toString().trim().toLowerCase() ?? '';
      if (!_isSupportedBundleImportKind(kind)) continue;
      result.add(
        _EncryptedImportEntry(
          index: i,
          kind: kind == 'item' || kind == 'secret' ? 'vault_item' : kind,
          bundleEntry: entry,
          title: _bundleImportTitle(entry, kind),
          subtitle: _bundleImportSubtitle(entry, kind),
        ),
      );
    }
    return result;
  }

  bool _isSupportedBundleImportKind(String kind) {
    return kind == 'note' ||
        kind == 'vault_item' ||
        kind == 'item' ||
        kind == 'secret' ||
        kind == 'document';
  }

  String _bundleImportTitle(Map<String, dynamic> entry, String kind) {
    final rawEntry = entry['entry'];
    if (rawEntry is Map) {
      final title = rawEntry['title']?.toString().trim() ?? '';
      if (title.isNotEmpty) return title;
    }
    if (kind == 'document') {
      final fileName = entry['fileName']?.toString().trim() ?? '';
      if (fileName.isNotEmpty) return fileName;
      return 'Document';
    }
    final plainText = entry['plainText']?.toString() ?? '';
    final firstLine = _safePlainTextPreviewLine(plainText);
    if (firstLine != null) return firstLine;
    return kind == 'note' ? 'Note' : 'Secret';
  }

  String? _safePlainTextPreviewLine(String plainText) {
    final firstLine = plainText
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty || _looksLikeEncodedVaultData(firstLine)) {
      return null;
    }
    return firstLine;
  }

  bool _looksLikeEncodedVaultData(String value) {
    return _looksLikeEncodedPreviewData(value);
  }

  String _bundleImportSubtitle(Map<String, dynamic> entry, String kind) {
    if (kind == 'note') return 'Secure Note';
    if (kind == 'document') {
      final extension = entry['extension']?.toString().trim().toUpperCase();
      final size = entry['sizeBytes'];
      final formattedSize = size == null
          ? ''
          : _formatBytes(int.tryParse(size.toString()) ?? 0);
      return [
        if (extension != null && extension.isNotEmpty) extension,
        if (formattedSize.isNotEmpty) formattedSize,
      ].join(' · ');
    }
    final rawEntry = entry['entry'];
    if (rawEntry is Map) {
      final type = rawEntry['type']?.toString().trim() ?? '';
      if (type.isNotEmpty) return type;
    }
    return 'Vault Item';
  }

  Future<bool> _importEncryptedBundleEntry(_EncryptedImportEntry entry) async {
    final importedAt = DateTime.now().toUtc().toIso8601String();
    final imported = await _preparedImportFromBundleEntry(
      entry.bundleEntry,
      entry.index,
      importedAt,
    );
    if (imported == null || !mounted) return false;
    _insertPreparedImport(imported);
    await _persistVaultData();
    return true;
  }

  Future<bool> _importEncryptedBundleEntries(
    List<_EncryptedImportEntry> entries,
  ) async {
    if (entries.isEmpty) return false;
    final importedAt = DateTime.now().toUtc().toIso8601String();
    final prepared = _PreparedVaultImport();
    for (final entry in entries) {
      final imported = await _preparedImportFromBundleEntry(
        entry.bundleEntry,
        entry.index,
        importedAt,
      );
      if (imported == null) continue;
      prepared.items.addAll(imported.items);
      prepared.notes.addAll(imported.notes);
    }
    if (prepared.isEmpty || !mounted) return false;
    _insertPreparedImport(prepared);
    await _persistVaultData();
    return true;
  }

  Future<_PreparedVaultImport?> _preparedImportFromBundleEntry(
    Map<String, dynamic> entry,
    int index,
    String importedAt,
  ) async {
    final kind = entry['kind']?.toString().trim().toLowerCase() ?? '';
    if (kind == 'note') {
      final note = _noteFromBundleEntry(entry, index, importedAt);
      if (note == null) return null;
      return _PreparedVaultImport(notes: [note]);
    }
    if (kind == 'vault_item' || kind == 'item' || kind == 'secret') {
      final item = _itemFromBundleEntry(entry, index, importedAt);
      if (item == null) return null;
      return _PreparedVaultImport(items: [item]);
    }
    if (kind == 'document') {
      final item = await _documentFromBundleEntry(entry, index, importedAt);
      if (item == null) return null;
      return _PreparedVaultImport(items: [item]);
    }
    return null;
  }

  void _insertPreparedImport(_PreparedVaultImport imported) {
    setState(() {
      _items.insertAll(0, imported.items);
      _notes.insertAll(0, imported.notes);
    });
  }

  Future<bool> _applyImportedBundle(String plainText) async {
    return _importEncryptedBundleEntries(
      _encryptedImportEntriesFromBundle(plainText),
    );
  }

  Map<String, dynamic>? _noteFromBundleEntry(
    Map<String, dynamic> bundleEntry,
    int index,
    String importedAt,
  ) {
    final rawEntry = bundleEntry['entry'];
    if (rawEntry is Map) {
      final note = Map<String, dynamic>.from(rawEntry);
      note['id'] = _importedVaultId('note', index);
      note['pinned'] = false;
      _markImportedEntryVisible(note, importedAt: importedAt);
      return note;
    }
    final plainText = bundleEntry['plainText']?.toString();
    if (plainText == null || plainText.trim().isEmpty) return null;
    final note = _noteFromImported(plainText);
    if (note == null) return null;
    note['id'] = _importedVaultId('note', index);
    _markImportedEntryVisible(note, importedAt: importedAt);
    return note;
  }

  Map<String, dynamic>? _itemFromBundleEntry(
    Map<String, dynamic> bundleEntry,
    int index,
    String importedAt,
  ) {
    final rawEntry = bundleEntry['entry'];
    if (rawEntry is Map) {
      final item = Map<String, dynamic>.from(rawEntry);
      item['id'] = _importedVaultId('item', index);
      item['pinned'] = false;
      final type = item['type']?.toString().trim() ?? '';
      if (type.isEmpty) item['type'] = 'Item';
      _markImportedEntryVisible(item, importedAt: importedAt);
      return item;
    }
    final plainText = bundleEntry['plainText']?.toString();
    if (plainText == null || plainText.trim().isEmpty) return null;
    final item = _itemFromImported(plainText);
    if (item == null) return null;
    item['id'] = _importedVaultId('item', index);
    _markImportedEntryVisible(item, importedAt: importedAt);
    return item;
  }

  Future<Map<String, dynamic>?> _documentFromImported(String plainText) async {
    final decoded = jsonDecode(plainText);
    if (decoded is! Map) return null;
    return _documentFromBundleEntry(
      Map<String, dynamic>.from(decoded),
      0,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<Map<String, dynamic>?> _documentFromBundleEntry(
    Map<String, dynamic> bundleEntry,
    int index,
    String importedAt,
  ) async {
    final rawBytes = bundleEntry['bytesBase64']?.toString();
    if (rawBytes == null || rawBytes.isEmpty) return null;
    final bytes = base64Decode(rawBytes);
    final rawEntry = bundleEntry['entry'];
    final item = rawEntry is Map
        ? Map<String, dynamic>.from(rawEntry)
        : <String, dynamic>{};
    final fileName = bundleEntry['fileName']?.toString().trim();
    final extension = bundleEntry['extension']?.toString().trim();
    item
      ..remove('documentSection')
      ..remove('documentStorage')
      ..['id'] = _importedVaultId('document', index)
      ..['type'] = 'Documents'
      ..['title'] = item['title']?.toString().trim().isNotEmpty == true
          ? item['title']
          : fileName ?? 'Imported document'
      ..['pinned'] = false
      ..['updated'] = 'Now'
      ..['updatedAt'] = importedAt
      ..['createdAt'] = item['createdAt'] ?? importedAt
      ..['documentUploadedAt'] = item['documentUploadedAt'] ?? importedAt
      ..['documentFileName'] =
          fileName ?? item['documentFileName'] ?? 'document'
      ..['documentExtension'] =
          extension ?? item['documentExtension'] ?? _documentExtension(item)
      ..['documentSizeBytes'] = bytes.length
      ..['__documentBytes__'] = Uint8List.fromList(bytes);
    final stored = await _isPendingDocumentStored(item);
    return stored ? item : null;
  }

  void _markImportedEntryVisible(
    Map<String, dynamic> entry, {
    String? importedAt,
  }) {
    final timestamp = importedAt ?? DateTime.now().toUtc().toIso8601String();
    entry['updated'] = 'Now';
    entry['updatedAt'] = timestamp;
    entry['createdAt'] = entry['createdAt'] ?? timestamp;
  }

  String _importedVaultId(String prefix, int index) {
    return '$prefix-imported-${DateTime.now().microsecondsSinceEpoch}-$index';
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

class _EncryptedImportEntry {
  const _EncryptedImportEntry({
    required this.index,
    required this.kind,
    required this.bundleEntry,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final String kind;
  final Map<String, dynamic> bundleEntry;
  final String title;
  final String subtitle;
}

class _PreparedVaultImport {
  _PreparedVaultImport({
    List<Map<String, dynamic>>? items,
    List<Map<String, dynamic>>? notes,
  }) : items = items ?? <Map<String, dynamic>>[],
       notes = notes ?? <Map<String, dynamic>>[];

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> notes;

  bool get isEmpty => items.isEmpty && notes.isEmpty;
}

class _EncryptedShareInputDialog extends StatefulWidget {
  const _EncryptedShareInputDialog({
    required this.initialFileName,
    required this.title,
    required this.actionLabel,
    required this.ensureExtension,
  });

  final String initialFileName;
  final String title;
  final String actionLabel;
  final String Function(String fileName) ensureExtension;

  @override
  State<_EncryptedShareInputDialog> createState() =>
      _EncryptedShareInputDialogState();
}

class _EncryptedShareInputDialogState
    extends State<_EncryptedShareInputDialog> {
  late final TextEditingController _fileNameController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _fileNameController = TextEditingController(text: widget.initialFileName);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawName = _fileNameController.text.trim();
    final hasName = rawName.isNotEmpty;
    final hasPassword = _passwordController.text.trim().isNotEmpty;
    final canShare = hasName && hasPassword;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _fileNameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'File name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onChanged: (_) => setState(() {}),
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
                  final normalizedName = widget.ensureExtension(rawName);
                  Navigator.of(context).pop(
                    _EncryptedShareChoice(
                      fileName: normalizedName,
                      password: _passwordController.text,
                    ),
                  );
                }
              : null,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

class _EncryptedImportBundleScreen extends StatefulWidget {
  const _EncryptedImportBundleScreen({
    required this.entries,
    required this.customTypeDefinitions,
    required this.onImportEntry,
    required this.onImportAll,
  });

  final List<_EncryptedImportEntry> entries;
  final List<Map<String, dynamic>> customTypeDefinitions;
  final Future<bool> Function(_EncryptedImportEntry entry) onImportEntry;
  final Future<bool> Function(List<_EncryptedImportEntry> entries) onImportAll;

  @override
  State<_EncryptedImportBundleScreen> createState() =>
      _EncryptedImportBundleScreenState();
}

class _EncryptedImportBundleScreenState
    extends State<_EncryptedImportBundleScreen> {
  final Set<int> _importedIndexes = <int>{};
  bool _importingAll = false;

  List<_EncryptedImportEntry> get _remainingEntries => widget.entries
      .where((entry) => !_importedIndexes.contains(entry.index))
      .toList();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encrypted file'),
        actions: [
          TextButton(
            onPressed: _remainingEntries.isEmpty || _importingAll
                ? null
                : _importAll,
            child: _importingAll
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Import all'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          itemCount: widget.entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = widget.entries[index];
            final imported = _importedIndexes.contains(entry.index);
            return Material(
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _colorForImportEntry(
                    entry,
                  ).withValues(alpha: 0.16),
                  child: Icon(
                    _iconForImportEntry(entry),
                    color: _colorForImportEntry(entry),
                  ),
                ),
                title: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  imported ? 'Imported' : entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: imported
                    ? const Icon(Icons.check_circle, color: Color(0xFF22C55E))
                    : const Icon(Icons.chevron_right),
                onTap: () => _openEntry(entry, imported: imported),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openEntry(
    _EncryptedImportEntry entry, {
    required bool imported,
  }) async {
    final didImport = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EncryptedImportEntryPreviewScreen(
          entry: entry,
          customTypeDefinitions: widget.customTypeDefinitions,
          alreadyImported: imported,
          onImport: () => widget.onImportEntry(entry),
        ),
      ),
    );
    if (didImport == true && mounted) {
      setState(() => _importedIndexes.add(entry.index));
    }
  }

  Future<void> _importAll() async {
    setState(() => _importingAll = true);
    final remaining = _remainingEntries;
    final ok = await widget.onImportAll(remaining);
    if (!mounted) return;
    setState(() {
      _importingAll = false;
      if (ok) {
        _importedIndexes.addAll(remaining.map((entry) => entry.index));
      }
    });
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImportFailed)),
      );
    }
  }
}

class _EncryptedImportEntryPreviewScreen extends StatefulWidget {
  const _EncryptedImportEntryPreviewScreen({
    required this.entry,
    required this.customTypeDefinitions,
    required this.alreadyImported,
    required this.onImport,
  });

  final _EncryptedImportEntry entry;
  final List<Map<String, dynamic>> customTypeDefinitions;
  final bool alreadyImported;
  final Future<bool> Function() onImport;

  @override
  State<_EncryptedImportEntryPreviewScreen> createState() =>
      _EncryptedImportEntryPreviewScreenState();
}

class _EncryptedImportEntryPreviewScreenState
    extends State<_EncryptedImportEntryPreviewScreen> {
  late bool _imported;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _imported = widget.alreadyImported;
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Scaffold(
      appBar: AppBar(title: Text(_previewTitle(entry))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildPreview(context, entry)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _imported || _importing ? null : _importEntry,
                  icon: _importing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _imported
                              ? Icons.check_circle_outline
                              : Icons.file_download_outlined,
                        ),
                  label: Text(_imported ? 'Imported' : 'Import item'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, _EncryptedImportEntry entry) {
    if (entry.kind == 'note') return _buildNotePreview(context, entry);
    if (entry.kind == 'document') return _buildDocumentPreview(context, entry);
    return _buildVaultItemPreview(context, entry);
  }

  Widget _buildVaultItemPreview(
    BuildContext context,
    _EncryptedImportEntry entry,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final rawEntry = entry.bundleEntry['entry'];
    final item = rawEntry is Map
        ? Map<String, dynamic>.from(rawEntry)
        : const <String, dynamic>{};
    final fields = (item['fields'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((field) => Map<String, dynamic>.from(field))
        .toList();
    if (fields.isEmpty) {
      fields.addAll(_plainTextPreviewFields(entry.bundleEntry['plainText']));
    }
    final type = item['type']?.toString().trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        _ImportPreviewHeader(
          icon: _iconForImportEntry(entry),
          color: _colorForImportEntry(entry),
          title: entry.title,
          subtitle: entry.subtitle,
        ),
        const SizedBox(height: 16),
        if (type != null && type.isNotEmpty)
          _ImportPreviewRow(label: 'Type', value: type),
        if (fields.isEmpty)
          Text(
            'No fields to preview.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          )
        else
          ...fields.map((field) {
            final label = field['label']?.toString() ?? 'Field';
            final value = field['value']?.toString() ?? '';
            return _ImportPreviewRow(label: label, value: value);
          }),
      ],
    );
  }

  Widget _buildNotePreview(BuildContext context, _EncryptedImportEntry entry) {
    final body = _notePreviewBody(entry);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        _ImportPreviewHeader(
          icon: Icons.sticky_note_2_outlined,
          color: const Color(0xFF6366F1),
          title: entry.title,
          subtitle: 'Secure Note',
        ),
        const SizedBox(height: 16),
        _ImportPreviewRow(label: 'Content', value: body.isEmpty ? '-' : body),
      ],
    );
  }

  Widget _buildDocumentPreview(
    BuildContext context,
    _EncryptedImportEntry entry,
  ) {
    final fileName = entry.bundleEntry['fileName']?.toString() ?? entry.title;
    final extension =
        entry.bundleEntry['extension']?.toString().toUpperCase() ?? '';
    final size = int.tryParse(entry.bundleEntry['sizeBytes']?.toString() ?? '');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        _ImportPreviewHeader(
          icon: Icons.folder_outlined,
          color: const Color(0xFFFB923C),
          title: entry.title,
          subtitle: 'Document',
        ),
        const SizedBox(height: 16),
        _ImportPreviewRow(label: 'File name', value: fileName),
        _ImportPreviewRow(label: 'Extension', value: extension),
        _ImportPreviewRow(
          label: 'Size',
          value: size == null ? '-' : _formatDocumentByteCount(size),
        ),
      ],
    );
  }

  String _previewTitle(_EncryptedImportEntry entry) {
    if (entry.kind == 'note') return 'Note';
    if (entry.kind == 'document') return 'Document';
    return entry.subtitle.isEmpty ? 'Vault Item' : entry.subtitle;
  }

  String _notePreviewBody(_EncryptedImportEntry entry) {
    final rawEntry = entry.bundleEntry['entry'];
    if (rawEntry is Map) {
      final delta = rawEntry['delta'];
      if (delta is List) {
        return delta
            .whereType<Map>()
            .map((op) => op['insert']?.toString() ?? '')
            .join()
            .trim();
      }
      final preview = rawEntry['preview']?.toString().trim() ?? '';
      if (preview.isNotEmpty) return preview;
    }
    final plainText = entry.bundleEntry['plainText']?.toString() ?? '';
    if (_looksLikeEncodedPreviewData(plainText)) return '';
    return plainText.split('\n').skip(1).join('\n').trim();
  }

  Future<void> _importEntry() async {
    setState(() => _importing = true);
    final ok = await widget.onImport();
    if (!mounted) return;
    setState(() {
      _importing = false;
      _imported = ok;
    });
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImportFailed)),
      );
    }
  }
}

class _ImportPreviewHeader extends StatelessWidget {
  const _ImportPreviewHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: vaultPageHeadingStyle(context),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ImportPreviewRow extends StatelessWidget {
  const _ImportPreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: colorScheme.onSurface)),
        ],
      ),
    );
  }
}

IconData _iconForImportEntry(_EncryptedImportEntry entry) {
  if (entry.kind == 'note') return Icons.sticky_note_2_outlined;
  if (entry.kind == 'document') return Icons.folder_outlined;
  final rawEntry = entry.bundleEntry['entry'];
  if (rawEntry is Map) {
    return _iconForHomeType(rawEntry['type']?.toString() ?? 'Item');
  }
  return Icons.lock_outline;
}

Color _colorForImportEntry(_EncryptedImportEntry entry) {
  if (entry.kind == 'note') return const Color(0xFF6366F1);
  if (entry.kind == 'document') return const Color(0xFFFB923C);
  final rawEntry = entry.bundleEntry['entry'];
  if (rawEntry is Map) {
    return _colorForHomeType(rawEntry['type']?.toString() ?? 'Item');
  }
  return const Color(0xFF22C55E);
}

List<Map<String, dynamic>> _plainTextPreviewFields(Object? rawPlainText) {
  final plainText = rawPlainText?.toString() ?? '';
  if (_looksLikeEncodedPreviewData(plainText)) {
    return const <Map<String, dynamic>>[];
  }
  final fields = <Map<String, dynamic>>[];
  final lines = plainText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  for (final line in lines.skip(1)) {
    if (line.startsWith('Type: ')) continue;
    final separator = line.indexOf(':');
    if (separator <= 0 || separator >= line.length - 1) continue;
    final label = line.substring(0, separator).trim();
    final value = line.substring(separator + 1).trim();
    if (label.isEmpty || value.isEmpty) continue;
    fields.add(<String, dynamic>{'label': label, 'value': value});
  }
  return fields;
}

bool _looksLikeEncodedPreviewData(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) return true;
  final lower = trimmed.toLowerCase();
  return lower.contains('ciphertext') ||
      lower.contains('schemaversion') ||
      lower.contains('vault_bundle') ||
      lower.contains('bytesbase64');
}

String _formatDocumentByteCount(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}

String _formatAutoLockSeconds(int seconds) {
  if (seconds <= 0) return 'Off';
  if (seconds == 1) return '1 sec';
  if (seconds < 60) return '$seconds sec';
  if (seconds % 60 == 0) {
    final minutes = seconds ~/ 60;
    return minutes == 1 ? '60 sec' : '$seconds sec';
  }
  return '$seconds sec';
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
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
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
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item['type']?.toString() ?? 'Item',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _PasswordStrengthMeter extends StatelessWidget {
  const _PasswordStrengthMeter({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = _passwordStrengthScore(password);
    final label = _passwordStrengthLabel(score);
    final color = _passwordStrengthColor(theme, score);
    final guidance = VaultValidators.isStrongEnoughMasterPassword(password)
        ? 'Meets recommended minimum'
        : 'Use 10+ characters with letters and numbers';

    return Semantics(
      label: 'Password strength $label',
      child: Column(
        key: const ValueKey('master-password-strength-meter'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: score / 4,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                key: const ValueKey('master-password-strength-label'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            guidance,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

int _passwordStrengthScore(String password) {
  if (password.isEmpty) return 0;
  var score = 0;
  if (password.length >= 10) score++;
  if (password.contains(RegExp(r'[A-Za-z]'))) score++;
  if (password.contains(RegExp(r'\d'))) score++;
  if (password.contains(RegExp(r'[^A-Za-z0-9]')) || password.length >= 16) {
    score++;
  }
  return score.clamp(1, 4);
}

String _passwordStrengthLabel(int score) {
  return switch (score) {
    0 => 'Not started',
    1 => 'Weak',
    2 => 'Fair',
    3 => 'Good',
    _ => 'Strong',
  };
}

Color _passwordStrengthColor(ThemeData theme, int score) {
  return switch (score) {
    0 => theme.colorScheme.outline,
    1 => theme.colorScheme.error,
    2 => const Color(0xFFB45309),
    3 => const Color(0xFF2563EB),
    _ => const Color(0xFF15803D),
  };
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;
    final effectiveTitleColor = danger
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 0.6,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: effectiveIconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: effectiveTitleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (trailing != null)
                trailing!
              else ...[
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoLockSecondsSheet extends StatefulWidget {
  const _AutoLockSecondsSheet({required this.initialSeconds});

  final int initialSeconds;

  @override
  State<_AutoLockSecondsSheet> createState() => _AutoLockSecondsSheetState();
}

class _AutoLockSecondsSheetState extends State<_AutoLockSecondsSheet> {
  late double _seconds;

  @override
  void initState() {
    super.initState();
    _seconds = widget.initialSeconds.clamp(0, 3600).toDouble();
  }

  int get _roundedSeconds => _seconds.round();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Auto Lock',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_roundedSeconds),
                  child: const Text('Done'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _formatAutoLockSeconds(_roundedSeconds),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Slider(
              key: const ValueKey('auto-lock-seconds-slider'),
              value: _seconds,
              min: 0,
              max: 3600,
              divisions: 360,
              label: _formatAutoLockSeconds(_roundedSeconds),
              onChanged: (value) => setState(() => _seconds = value),
            ),
            Row(
              children: [
                Text(
                  'Off',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  '3600 sec',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Row(
        children: [
          for (final child in children) ...[
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  outlinedButtonTheme: OutlinedButtonThemeData(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
                child: child,
              ),
            ),
            if (child != children.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _DocumentDetailScreen extends StatefulWidget {
  const _DocumentDetailScreen({
    required this.item,
    required this.onReadDocument,
    required this.onShareEncryptedDocument,
    required this.onExportEncryptedDocument,
    this.showDeleteAction = false,
  });

  final Map<String, dynamic> item;
  final ReadVaultDocument? onReadDocument;
  final Future<void> Function(Map<String, dynamic> item, List<int> bytes)
  onShareEncryptedDocument;
  final Future<void> Function(Map<String, dynamic> item, List<int> bytes)
  onExportEncryptedDocument;
  final bool showDeleteAction;

  @override
  State<_DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<_DocumentDetailScreen> {
  late Future<List<int>> _documentFuture;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.item['pinned'] == true;
    _documentFuture = _loadDocument();
  }

  Future<List<int>> _loadDocument() async {
    final sectionName = widget.item['documentSection']?.toString().trim() ?? '';
    if (sectionName.isEmpty) {
      throw StateError('Document section is missing.');
    }
    final reader = widget.onReadDocument;
    if (reader == null) {
      throw StateError(
        'Document preview is unavailable in this vault session.',
      );
    }
    return reader(sectionName: sectionName);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = widget.item['title']?.toString() ?? 'Document';
    final extension = _documentExtension(widget.item);
    final fileName = _documentFileName(widget.item);
    final size = _formatDocumentSize(widget.item);

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
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              onPressed: () => setState(() => _isFavorite = !_isFavorite),
              icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
              tooltip: 'Favorite',
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
          child: FutureBuilder<List<int>>(
            future: _documentFuture,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Column(
                      children: [
                        _DocumentHeader(
                          title: title,
                          fileName: fileName,
                          extension: extension,
                          size: size,
                        ),
                        const SizedBox(height: 10),
                        _EntryMetadataPanel(entry: widget.item),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildPreview(context, snapshot, extension),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: bytes == null
                                ? null
                                : () => _openDocument(bytes),
                            icon: const Icon(Icons.open_in_new_outlined),
                            label: const Text('Open with app'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: bytes == null
                                ? null
                                : () => _shareDecryptedDocument(bytes),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share decrypted file'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: bytes == null
                                    ? null
                                    : () => widget.onShareEncryptedDocument(
                                        widget.item,
                                        bytes,
                                      ),
                                icon: const Icon(
                                  Icons.enhanced_encryption_outlined,
                                ),
                                label: const Text('Share encrypted'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: bytes == null
                                    ? null
                                    : () => widget.onExportEncryptedDocument(
                                        widget.item,
                                        bytes,
                                      ),
                                icon: const Icon(Icons.file_download_outlined),
                                label: const Text('Export encrypted'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(
    BuildContext context,
    AsyncSnapshot<List<int>> snapshot,
    String extension,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return _DocumentPreviewMessage(
        icon: Icons.error_outline,
        title: 'Unable to preview document',
        subtitle: snapshot.error.toString(),
      );
    }
    final bytes = snapshot.data ?? const <int>[];
    if (bytes.isEmpty) {
      return const _DocumentPreviewMessage(
        icon: Icons.insert_drive_file_outlined,
        title: 'Empty document',
        subtitle: 'There is no content to preview.',
      );
    }
    if (_isImageExtension(extension)) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const _DocumentPreviewMessage(
                  icon: Icons.broken_image_outlined,
                  title: 'Image preview failed',
                  subtitle: 'Use Open with... to view this document.',
                ),
          ),
        ),
      );
    }
    if (_isTextExtension(extension)) {
      final text = utf8.decode(bytes, allowMalformed: true);
      return Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      );
    }
    return _DocumentPreviewMessage(
      icon: extension == 'PDF'
          ? Icons.picture_as_pdf_outlined
          : Icons.insert_drive_file_outlined,
      title: '$extension preview unavailable',
      subtitle: 'Use Open with... to view this document in another app.',
    );
  }

  Future<void> _openDocument(List<int> bytes) async {
    final fileName = _documentFileName(widget.item);
    final mimeType = _mimeTypeForExtension(_documentExtension(widget.item));
    try {
      await _VaultAppShellState._documentOpenChannel.invokeMethod<bool>(
        'openDocument',
        <String, Object>{
          'fileName': fileName,
          'mimeType': mimeType,
          'bytes': Uint8List.fromList(bytes),
        },
      );
    } on MissingPluginException {
      await _shareDocumentFallback(bytes, fileName, mimeType);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'No app can open this file.')),
      );
      await _shareDocumentFallback(bytes, fileName, mimeType);
    }
  }

  Future<void> _shareDecryptedDocument(List<int> bytes) async {
    final fileName = _documentFileName(widget.item);
    await _shareDocumentFallback(
      bytes,
      fileName,
      _mimeTypeForExtension(_documentExtension(widget.item)),
    );
  }

  Future<void> _shareDocumentFallback(
    List<int> bytes,
    String fileName,
    String mimeType,
  ) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(bytes),
            name: fileName,
            mimeType: mimeType,
          ),
        ],
      ),
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

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({
    required this.title,
    required this.fileName,
    required this.extension,
    required this.size,
  });

  final String title;
  final String fileName;
  final String extension;
  final String size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFB7185).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.insert_drive_file_outlined,
            color: Color(0xFFFB7185),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$extension · $size · $fileName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentPreviewMessage extends StatelessWidget {
  const _DocumentPreviewMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.onSurfaceVariant, size: 42),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

String _documentExtension(Map<String, dynamic> item) {
  final extension = item['documentExtension']?.toString().trim();
  if (extension != null && extension.isNotEmpty) {
    return extension.toUpperCase();
  }
  final fileName = _documentFileName(item);
  final dot = fileName.lastIndexOf('.');
  if (dot == -1 || dot == fileName.length - 1) return 'FILE';
  return fileName.substring(dot + 1).toUpperCase();
}

String _documentFileName(Map<String, dynamic> item) {
  final fileName = item['documentFileName']?.toString().trim();
  if (fileName != null && fileName.isNotEmpty) return fileName;
  final title = item['title']?.toString().trim();
  if (title != null && title.isNotEmpty) return title;
  return 'document';
}

String _documentSuggestedBaseName(Map<String, dynamic> item) {
  final fileName = _documentFileName(item);
  final dot = fileName.lastIndexOf('.');
  final base = dot <= 0 ? fileName : fileName.substring(0, dot);
  return base.trim().isEmpty ? 'document' : base.trim();
}

String _documentEncryptedPayload(Map<String, dynamic> item, List<int> bytes) {
  return jsonEncode(<String, dynamic>{
    'kind': 'document',
    'title': item['title']?.toString() ?? 'Document',
    'fileName': _documentFileName(item),
    'extension': _documentExtension(item),
    'mimeType': _mimeTypeForExtension(_documentExtension(item)),
    'sizeBytes': bytes.length,
    'createdAt': item['createdAt']?.toString(),
    'updatedAt': item['updatedAt']?.toString(),
    'deviceId': item['deviceId']?.toString(),
    'updatedByDevice': item['updatedByDevice']?.toString(),
    'bytesBase64': base64Encode(bytes),
  });
}

String _formatDocumentSize(Map<String, dynamic> item) {
  final raw = item['documentSizeBytes'];
  final bytes = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}

bool _isImageExtension(String extension) {
  return const <String>{
    'PNG',
    'JPG',
    'JPEG',
    'GIF',
    'WEBP',
    'BMP',
  }.contains(extension.toUpperCase());
}

bool _isTextExtension(String extension) {
  return const <String>{
    'TXT',
    'MD',
    'JSON',
    'CSV',
    'LOG',
    'XML',
    'YAML',
    'YML',
  }.contains(extension.toUpperCase());
}

String _mimeTypeForExtension(String extension) {
  switch (extension.toUpperCase()) {
    case 'PNG':
      return 'image/png';
    case 'JPG':
    case 'JPEG':
      return 'image/jpeg';
    case 'GIF':
      return 'image/gif';
    case 'WEBP':
      return 'image/webp';
    case 'PDF':
      return 'application/pdf';
    case 'JSON':
      return 'application/json';
    case 'CSV':
      return 'text/csv';
    case 'TXT':
    case 'MD':
    case 'LOG':
    case 'YAML':
    case 'YML':
      return 'text/plain';
    case 'XML':
      return 'application/xml';
    default:
      return 'application/octet-stream';
  }
}

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
  final value = entry['updatedAt'] ?? entry['updated'] ?? entry['createdAt'];
  return _formatEntryTimestamp(value, fallback: 'Now');
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

  Map<String, dynamic>? _customTypeDefinitionForType(String type) {
    final normalized = type.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final definition in widget.customTypeDefinitions) {
      final name = definition['name']?.toString().trim().toLowerCase();
      if (name == normalized) return definition;
    }
    return null;
  }

  IconData _iconForItemType(String type) {
    final iconKey = _customTypeDefinitionForType(type)?['iconKey']?.toString();
    if (iconKey != null) return _iconForCustomTemplateKey(iconKey);
    return _iconForHomeType(type);
  }

  Color _colorForItemType(String type) {
    final colorKey = _customTypeDefinitionForType(
      type,
    )?['colorKey']?.toString();
    if (colorKey != null) return _colorForCustomTemplateColorKey(colorKey);
    return _colorForHomeType(type);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fields = (widget.item['fields'] as List<dynamic>? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    final itemType = widget.item['type']?.toString() ?? 'Item';
    final title = widget.item['title']?.toString() ?? 'Untitled';
    final created = _entryCreatedLabel(widget.item);
    final modified = _entryModifiedLabel(widget.item);
    final device = _entryDeviceLabel(widget.item);
    final lastAccessed = _formatLastAccessedAt(
      widget.item['lastAccessedAt']?.toString(),
    );
    final primarySecret = _extractPrimarySecret(fields);
    final typeIcon = _iconForItemType(itemType);
    final typeColor = _colorForItemType(itemType);
    final idPhotos = _identityPhotos(widget.item);

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
          title: Text(itemType, maxLines: 1, overflow: TextOverflow.ellipsis),
          titleSpacing: 0,
          actions: [
            IconButton(
              onPressed: () => setState(() => _isFavorite = !_isFavorite),
              icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
              tooltip: 'Favorite',
            ),
            IconButton(
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
              icon: const Icon(Icons.edit_outlined),
              tooltip: AppStrings.edit,
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
                          color: typeColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 30),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        itemType,
                        textAlign: TextAlign.center,
                        style: vaultPageHeadingStyle(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colorScheme.outlineVariant),
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
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          displayValue,
                                          style: TextStyle(
                                            color: colorScheme.onSurface,
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
                    if (idPhotos.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _IdentityPhotosSection(photos: idPhotos),
                    ],
                    const SizedBox(height: 14),
                    _metadataRow('Category', itemType),
                    const SizedBox(height: 8),
                    _metadataRow('Created', created),
                    const SizedBox(height: 8),
                    _metadataRow('Modified', modified),
                    const SizedBox(height: 8),
                    _metadataRow('Device', device),
                    const SizedBox(height: 8),
                    _metadataRow('Last accessed', lastAccessed),
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

  List<Map<String, dynamic>> _identityPhotos(Map<String, dynamic> item) {
    final type = item['type']?.toString().trim().toLowerCase() ?? '';
    if (type != 'identity') return const <Map<String, dynamic>>[];
    return (item['idPhotos'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where(
          (entry) => (entry['bytesBase64']?.toString() ?? '').trim().isNotEmpty,
        )
        .toList();
  }

  Widget _metadataRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
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
    );
  }

  String _formatLastAccessedAt(String? value) {
    if (value == null || value.trim().isEmpty) return 'Never';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
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

class _IdentityPhotosSection extends StatelessWidget {
  const _IdentityPhotosSection({required this.photos});

  final List<Map<String, dynamic>> photos;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ID photos',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...photos.asMap().entries.map((entry) {
            final index = entry.key;
            final photo = entry.value;
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
              child: InkWell(
                key: ValueKey('identity-photo-row-$index'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showPhotoPicker(context, initialIndex: index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _IdentityPhotoPreview(photo: photo),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              photo['name']?.toString() ??
                                  'ID photo ${index + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatIdentityPhotoSize(photo['sizeBytes']),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.open_in_full,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showPhotoPicker(
    BuildContext context, {
    required int initialIndex,
  }) async {
    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Choose photo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ...photos.asMap().entries.map((entry) {
              final index = entry.key;
              final photo = entry.value;
              return ListTile(
                key: ValueKey('identity-photo-picker-$index'),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _IdentityPhotoPreview(photo: photo, size: 44),
                ),
                title: Text(
                  photo['name']?.toString() ?? 'ID photo ${index + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_formatIdentityPhotoSize(photo['sizeBytes'])),
                selected: index == initialIndex,
                onTap: () => Navigator.of(context).pop(index),
              );
            }),
          ],
        ),
      ),
    );
    if (selectedIndex == null || !context.mounted) return;
    await _showFullPhotoViewer(context, photos[selectedIndex], selectedIndex);
  }

  Future<void> _showFullPhotoViewer(
    BuildContext context,
    Map<String, dynamic> photo,
    int index,
  ) async {
    final name = photo['name']?.toString() ?? 'ID photo ${index + 1}';
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return Scaffold(
            appBar: AppBar(title: Text(name)),
            backgroundColor: colorScheme.surface,
            body: SafeArea(
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.75,
                  maxScale: 5,
                  child: _IdentityFullPhoto(photo: photo),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IdentityFullPhoto extends StatelessWidget {
  const _IdentityFullPhoto({required this.photo});

  final Map<String, dynamic> photo;

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(photo['bytesBase64']?.toString() ?? '');
      return Image.memory(bytes, fit: BoxFit.contain);
    } catch (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to display photo.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
  }
}

class _IdentityPhotoPreview extends StatelessWidget {
  const _IdentityPhotoPreview({required this.photo, this.size = 64});

  final Map<String, dynamic> photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(photo['bytesBase64']?.toString() ?? '');
      return Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
    } catch (_) {
      return Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.surface,
        child: const Icon(Icons.broken_image_outlined),
      );
    }
  }
}

String _formatIdentityPhotoSize(Object? raw) {
  final bytes = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
  if (bytes <= 0) return 'Image';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
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

class _RenameVaultDialog extends StatefulWidget {
  const _RenameVaultDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameVaultDialog> createState() => _RenameVaultDialogState();
}

class _RenameVaultDialogState extends State<_RenameVaultDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename vault'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: AppStrings.vaultName),
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) return 'Enter a vault name';
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Rename')),
      ],
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

class _DebugInfoCard extends StatelessWidget {
  const _DebugInfoCard({required this.title, required this.rows});

  final String title;
  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text(
                'No data',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              )
            else
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 132,
                        child: Text(
                          row.key,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          row.value,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
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
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
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
