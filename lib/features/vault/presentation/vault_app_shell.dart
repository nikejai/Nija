import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_features.dart';
import '../../../core/config/vault_limits.dart';
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

part 'widgets/encrypted_import_widgets.dart';
part 'custom_template_manager_screen.dart';
part 'document_detail_screen.dart';
part 'item_detail_screen.dart';
part 'widgets/vault_settings_widgets.dart';

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
typedef PersistVaultDocumentStream =
    Future<String> Function({
      required String documentId,
      required Stream<List<int>> chunks,
      required int sizeBytes,
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
    this.onPersistVaultDocumentStream,
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
  final PersistVaultDocumentStream? onPersistVaultDocumentStream;
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
  static const String _prefsKeyCloudBackupEnabled =
      'nija_pref_cloud_backup_enabled_v1';
  static const String _prefsKeyCloudBackupLastAt =
      'nija_pref_cloud_backup_last_at_v1';
  final _clipboard = SecureClipboard();
  final _allItemsSearchController = TextEditingController();
  final _encryptedShareCodec = EncryptedShareCodec();
  final SecretSharePortabilityAdapter _secretSharePortability =
      SecretSharePortabilityAdapterImpl();
  int _tabIndex = 0;
  String _allItemsQuery = '';
  String _allItemsFilterSearch = '';
  String _allItemsTypeFilter = 'all';
  Set<String> _allItemsFilterTypes = <String>{};
  bool _allItemsFilterFavoritesOnly = false;
  String _allItemsFilterDateRange = 'any';
  bool _cloudBackupEnabled = false;
  bool _importingEncryptedSecret = false;
  String _importBusyMessage = 'Importing data...';
  int _storedDocumentBytesThisSession = 0;
  int _cloudBackupLastAtEpochMs = 0;
  String _cloudBackupAccountLabel = 'Not connected';
  bool _allItemsSelectionMode = false;
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
    unawaited(_restoreCloudBackupPreference());
    unawaited(_refreshCloudBackupAccountLabel());
  }

  @override
  void didUpdateWidget(covariant VaultAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultSizeBytes != widget.vaultSizeBytes) {
      _storedDocumentBytesThisSession = 0;
    }
    if (oldWidget.activeVaultName != widget.activeVaultName) {
      _activeVaultName = widget.activeVaultName;
    }
    if (!listEquals(oldWidget.initialItems, widget.initialItems)) {
      _items
        ..clear()
        ..addAll(
          widget.initialItems.map((entry) => Map<String, dynamic>.from(entry)),
        );
      _selectedAllItemsKeys.removeWhere((key) => key.startsWith('item:'));
    }
    if (!listEquals(oldWidget.initialNotes, widget.initialNotes)) {
      _notes
        ..clear()
        ..addAll(
          widget.initialNotes.map((entry) => Map<String, dynamic>.from(entry)),
        );
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleBackNavigation());
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: KeyedSubtree(
                key: ValueKey<int>(_tabIndex),
                child: _buildActiveTab(context),
              ),
            ),
            if (_importingEncryptedSecret) _buildBusyOverlay(context),
          ],
        ),
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
            onDestinationSelected: (value) {
              if (value == _tabIndex) return;
              setState(() => _tabIndex = value);
            },
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

  Widget _buildActiveTab(BuildContext context) {
    return switch (_tabIndex) {
      0 => _buildVaultTab(context),
      1 => _buildTypesTab(context),
      2 => _buildFavoritesTab(context),
      3 => _buildSettingsTab(context),
      4 when kDebugMode => _buildDebugInternalsTab(context),
      _ => _buildVaultTab(context),
    };
  }

  Widget _buildBusyOverlay(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _importBusyMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Large encrypted files may take a moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleBackNavigation() async {
    if (_allItemsSelectionMode) {
      _clearAllItemsSelection();
      return;
    }
    if (_tabIndex != 0) {
      setState(() => _tabIndex = 0);
      _lastBackOnDashboardAt = null;
      return;
    }

    final now = DateTime.now();
    final shouldExit =
        _lastBackOnDashboardAt != null &&
        now.difference(_lastBackOnDashboardAt!) < const Duration(seconds: 2);
    if (shouldExit) {
      _lastBackOnDashboardAt = null;
      widget.onLockNow();
      return;
    }

    _lastBackOnDashboardAt = now;
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Press back again to lock.')));
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
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
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
        pageBuilder: (context, animation, secondaryAnimation) =>
            _AllItemsFiltersOverlay(
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

    final themeLabel = switch (widget.themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };
    final autoLockLabel = _formatAutoLockSeconds(widget.autoLockSeconds);
    final effectiveVaultSizeBytes = _effectiveVaultSizeBytes;
    final vaultLimitBytes = VaultLimits.maxVaultBytes;
    final vaultUsageLabel =
        '${VaultLimits.formatBytes(effectiveVaultSizeBytes)} of ${VaultLimits.formatBytes(vaultLimitBytes)}';
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
                subtitle: vaultUsageLabel,
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
                icon: Icons.folder_outlined,
                title: 'Categories',
                subtitle: '${_customTypeDefinitions.length} custom templates',
                onTap: () => _showCustomTemplateManager(context),
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
                onTap: () => _showInfoSheet(
                  context,
                  title: 'About Nija',
                  icon: Icons.info_outline,
                  sections: _aboutNijaSections(),
                ),
              ),
              _SettingsRow(
                icon: Icons.verified_user_outlined,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                onTap: () => _showInfoSheet(
                  context,
                  title: 'Privacy Policy',
                  icon: Icons.verified_user_outlined,
                  sections: _privacyPolicySections(),
                ),
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                title: 'Terms of Use',
                subtitle: 'Read our terms and conditions',
                onTap: () => _showInfoSheet(
                  context,
                  title: 'Terms of Use',
                  icon: Icons.description_outlined,
                  sections: _termsOfUseSections(),
                ),
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
                _DebugFileTreeCard(store: data['workingStore']),
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
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (context) => const _RotateMasterPasswordDialog(),
    );
    if (values == null) return;
    await widget.onRotateMasterPassword(
      currentPassword: values.$1,
      newPassword: values.$2,
    );
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

  Future<void> _showInfoSheet(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_InfoSectionData> sections,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _InfoDetailSheet(title: title, icon: icon, sections: sections),
    );
  }

  List<_InfoSectionData> _aboutNijaSections() {
    return const <_InfoSectionData>[
      _InfoSectionData(
        title: 'Nija',
        body:
            'Version 1.0.0\nNija is a private vault for passwords, notes, documents, identities, and custom secure records.',
      ),
      _InfoSectionData(
        title: 'Security model',
        body:
            'Vault data is encrypted before it is stored. Your master password is used to unlock the vault, and recovery data should be kept offline and private.',
      ),
      _InfoSectionData(
        title: 'Your responsibility',
        body:
            'Nija cannot recover a forgotten master password or recovery phrase. Export or back up important vaults before replacing devices or clearing app data.',
      ),
    ];
  }

  List<_InfoSectionData> _privacyPolicySections() {
    return const <_InfoSectionData>[
      _InfoSectionData(
        title: 'Local-first storage',
        body:
            'Nija is designed to keep vault contents on your device unless you explicitly export, share, import, or back up a vault.',
      ),
      _InfoSectionData(
        title: 'Cloud backup',
        body:
            'If you choose cloud backup, encrypted vault backup files are stored in the cloud account you select. Nija does not upload decrypted vault contents.',
      ),
      _InfoSectionData(
        title: 'Sensitive data',
        body:
            'Passwords, notes, documents, identity photos, and custom fields are treated as vault data. Do not share exported encrypted files or their passwords with untrusted people.',
      ),
      _InfoSectionData(
        title: 'Device permissions',
        body:
            'File picker, sharing, biometrics, and document open actions are used only when you choose those workflows.',
      ),
    ];
  }

  List<_InfoSectionData> _termsOfUseSections() {
    return const <_InfoSectionData>[
      _InfoSectionData(
        title: 'Use at your discretion',
        body:
            'You are responsible for the data you store, export, share, import, and back up with Nija.',
      ),
      _InfoSectionData(
        title: 'No password recovery guarantee',
        body:
            'If you lose your master password, recovery phrase, vault file, or backup access, your vault data may be unrecoverable.',
      ),
      _InfoSectionData(
        title: 'Backups',
        body:
            'Keep independent backups of important vaults. Verify that backups can be restored before relying on them.',
      ),
      _InfoSectionData(
        title: 'No warranty',
        body:
            'Nija is provided as-is. You should confirm that it meets your security, legal, and operational requirements before relying on it for critical data.',
      ),
    ];
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
                  currentVaultSizeBytes: _effectiveVaultSizeBytes,
                  maxVaultBytes: VaultLimits.maxVaultBytes,
                  maxDocumentBytes: VaultLimits.maxDocumentBytes,
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
    final rawStream = item.remove('__documentReadStream__');
    final rawBytes = item.remove('__documentBytes__');
    if (rawStream == null && rawBytes == null) return true;
    if (widget.onPersistVaultDocument == null &&
        widget.onPersistVaultDocumentStream == null) {
      item['documentStorage'] = 'inline-unavailable';
      return true;
    }
    final sizeBytes = _documentMetadataSizeBytes(item);
    if (rawStream != null) {
      if (widget.onPersistVaultDocumentStream == null) {
        item['documentStorage'] = 'inline-unavailable';
        return true;
      }
      if (!_canStoreDocumentBytes(sizeBytes)) return false;
      final stream = rawStream as Stream<List<int>>;
      final sectionName = await widget.onPersistVaultDocumentStream!(
        documentId: item['id']?.toString() ?? '',
        chunks: stream,
        sizeBytes: sizeBytes,
      );
      _storedDocumentBytesThisSession += sizeBytes;
      item['documentStorage'] = 'private-section';
      item['documentSection'] = sectionName;
      return true;
    }
    final bytes = rawBytes is Uint8List
        ? rawBytes
        : Uint8List.fromList(List<int>.from(rawBytes as List));
    final storedSizeBytes = _documentMetadataSizeBytes(
      item,
      fallbackBytes: bytes.length,
    );
    if (!_canStoreDocumentBytes(storedSizeBytes)) return false;
    final documentId = item['id']?.toString() ?? '';
    final sectionName = widget.onPersistVaultDocumentStream != null
        ? await widget.onPersistVaultDocumentStream!(
            documentId: documentId,
            chunks: Stream<List<int>>.value(bytes),
            sizeBytes: storedSizeBytes,
          )
        : await widget.onPersistVaultDocument!(
            documentId: documentId,
            bytes: bytes,
          );
    _storedDocumentBytesThisSession += storedSizeBytes;
    item['documentStorage'] = 'private-section';
    item['documentSection'] = sectionName;
    return true;
  }

  int _documentMetadataSizeBytes(
    Map<String, dynamic> item, {
    int fallbackBytes = 0,
  }) {
    final raw = item['documentSizeBytes'];
    if (raw is int && raw >= 0) return raw;
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed != null && parsed >= 0) return parsed;
    return fallbackBytes;
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

  int _updatedRank(Map<String, dynamic> entry) {
    final updated = entry['updated']?.toString().trim() ?? '';
    if (updated.toLowerCase() == 'now') return 999999999;
    return 0;
  }

  Future<void> _restoreCloudBackupPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefsKeyCloudBackupEnabled) ?? false;
      final lastAt = prefs.getInt(_prefsKeyCloudBackupLastAt) ?? 0;
      if (!mounted) return;
      setState(() {
        _cloudBackupEnabled = enabled && AppFeatures.isPaidBuild;
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
    if (!mounted) return;
    if (ok) {
      await _refreshCloudBackupAccountLabel();
      if (!mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Backup account updated.' : 'Backup account unchanged.',
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
    return VaultLimits.formatBytes(bytes);
  }

  int get _effectiveVaultSizeBytes =>
      widget.vaultSizeBytes + _storedDocumentBytesThisSession;

  bool _canStoreDocumentBytes(int bytes) {
    if (bytes > VaultLimits.maxDocumentBytes) {
      _showVaultLimitMessage(
        'Document must be ${_formatBytes(VaultLimits.maxDocumentBytes)} or smaller.',
      );
      return false;
    }
    final projected = _effectiveVaultSizeBytes + bytes;
    if (projected > VaultLimits.maxVaultBytes) {
      _showVaultLimitMessage(
        'Not enough vault space. Limit is ${_formatBytes(VaultLimits.maxVaultBytes)}.',
      );
      return false;
    }
    return true;
  }

  void _showVaultLimitMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        final insertAt = snapshot.index.clamp(0, _items.length);
        _items.insert(insertAt, _deepCopyEntry(snapshot.entry));
      }
      final noteSnapshots =
          _lastDeletedAllItems.where((entry) => entry.kind == 'note').toList()
            ..sort((a, b) => a.index.compareTo(b.index));
      for (final snapshot in noteSnapshots) {
        final insertAt = snapshot.index.clamp(0, _notes.length);
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
    setState(() {
      _importingEncryptedSecret = true;
      _importBusyMessage = 'Selecting import file...';
    });
    try {
      final imported = await _secretSharePortability.importEncryptedFile();
      if (imported == null || !mounted) return;
      setState(() => _importBusyMessage = 'Waiting for import password...');
      final password = await _promptSecretImportPassword(context);
      if (password == null || password.trim().isEmpty || !mounted) return;
      setState(() => _importBusyMessage = 'Decrypting imported file...');
      await _waitForOverlayTeardown();
      final decoded = await _encryptedShareCodec.decode(
        encoded: imported.content,
        password: password.trim(),
      );
      if (!mounted) return;
      setState(() => _importBusyMessage = 'Preparing import preview...');
      if (decoded.contentType.trim().toLowerCase() == 'vault_bundle') {
        final entries = _encryptedImportEntriesFromBundle(decoded.plainText);
        if (entries.isNotEmpty) {
          if (!mounted) return;
          if (entries.length > 1) {
            setState(() => _importingEncryptedSecret = false);
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
          setState(() => _importingEncryptedSecret = false);
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
      setState(() => _importBusyMessage = 'Importing into vault...');
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
        setState(() {
          _importingEncryptedSecret = false;
          _importBusyMessage = 'Importing data...';
        });
      } else {
        _importingEncryptedSecret = false;
        _importBusyMessage = 'Importing data...';
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
    final Uint8List bytes;
    try {
      bytes = Uint8List.fromList(base64Decode(rawBytes));
    } on FormatException {
      return null;
    }
    final rawEntry = bundleEntry['entry'];
    final item = rawEntry is Map
        ? Map<String, dynamic>.from(rawEntry)
        : <String, dynamic>{};
    final fileName = bundleEntry['fileName']?.toString().trim();
    final extension = bundleEntry['extension']?.toString().trim();
    final sizeBytes = _bundleDocumentMetadataSizeBytes(
      bundleEntry,
      item,
      fallbackBytes: bytes.length,
    );
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
      ..['documentSizeBytes'] = sizeBytes
      ..['__documentBytes__'] = bytes;
    final stored = await _isPendingDocumentStored(item);
    return stored ? item : null;
  }

  int _bundleDocumentMetadataSizeBytes(
    Map<String, dynamic> bundleEntry,
    Map<String, dynamic> item, {
    required int fallbackBytes,
  }) {
    for (final raw in <dynamic>[
      bundleEntry['sizeBytes'],
      item['documentSizeBytes'],
    ]) {
      if (raw is int && raw >= 0) return raw;
      final parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null && parsed >= 0) return parsed;
    }
    return fallbackBytes;
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

class _DebugFileTreeCard extends StatelessWidget {
  const _DebugFileTreeCard({required this.store});

  final dynamic store;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tree = _buildTree();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vault file tree',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (tree.isEmpty)
              Text(
                'No files',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              )
            else
              ...tree.map((line) => _DebugTreeLine(line: line)),
          ],
        ),
      ),
    );
  }

  List<_DebugTreeLineData> _buildTree() {
    if (store is! Map) return const <_DebugTreeLineData>[];
    final root = (store as Map)['root']?.toString() ?? 'vault';
    final files = (store as Map)['files'];
    if (files is! Map) return const <_DebugTreeLineData>[];
    final entries =
        files.entries
            .map(
              (entry) => MapEntry<String, int>(
                entry.key.toString(),
                int.tryParse(entry.value.toString()) ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    final core = <MapEntry<String, int>>[];
    final documents = <String, List<MapEntry<String, int>>>{};
    final other = <MapEntry<String, int>>[];
    for (final entry in entries) {
      final docId = _documentTreeId(entry.key);
      if (_isCoreDebugFile(entry.key)) {
        core.add(entry);
      } else if (docId != null) {
        documents
            .putIfAbsent(docId, () => <MapEntry<String, int>>[])
            .add(entry);
      } else {
        other.add(entry);
      }
    }

    final lines = <_DebugTreeLineData>[
      _DebugTreeLineData(depth: 0, label: _rootLabel(root), folder: true),
    ];
    if (core.isNotEmpty) {
      lines.add(
        const _DebugTreeLineData(depth: 1, label: 'core', folder: true),
      );
      lines.addAll(core.map((entry) => _fileLine(entry, depth: 2)));
    }
    if (documents.isNotEmpty) {
      lines.add(
        const _DebugTreeLineData(depth: 1, label: 'documents', folder: true),
      );
      for (final docId in documents.keys.toList()..sort()) {
        final docFiles = documents[docId]!
          ..sort((a, b) => a.key.compareTo(b.key));
        lines.add(_DebugTreeLineData(depth: 2, label: docId, folder: true));
        lines.addAll(docFiles.map((entry) => _fileLine(entry, depth: 3)));
      }
    }
    if (other.isNotEmpty) {
      lines.add(
        const _DebugTreeLineData(depth: 1, label: 'other', folder: true),
      );
      lines.addAll(other.map((entry) => _fileLine(entry, depth: 2)));
    }
    return lines;
  }

  static _DebugTreeLineData _fileLine(
    MapEntry<String, int> entry, {
    required int depth,
  }) {
    return _DebugTreeLineData(
      depth: depth,
      label: entry.key,
      detail: '${entry.value} bytes',
    );
  }

  static String _rootLabel(String root) {
    final normalized = root.replaceAll('\\', '/');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? root : parts.last;
  }

  static bool _isCoreDebugFile(String name) {
    return const <String>{
      'header.json',
      'manifest.enc',
      'items.enc',
      'notes.enc',
      'settings.enc',
      'tags.enc',
    }.contains(name);
  }

  static String? _documentTreeId(String name) {
    final manifest = RegExp(r'^document_(.+)\.manifest\.enc$').firstMatch(name);
    if (manifest != null) return manifest.group(1);
    final chunk = RegExp(r'^document_(.+)_chunk_\d+\.enc$').firstMatch(name);
    return chunk?.group(1);
  }
}

class _DebugTreeLineData {
  const _DebugTreeLineData({
    required this.depth,
    required this.label,
    this.detail,
    this.folder = false,
  });

  final int depth;
  final String label;
  final String? detail;
  final bool folder;
}

class _DebugTreeLine extends StatelessWidget {
  const _DebugTreeLine({required this.line});

  final _DebugTreeLineData line;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: line.depth * 14.0, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(
            line.folder
                ? Icons.folder_outlined
                : Icons.insert_drive_file_outlined,
            size: 15,
            color: line.folder
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SelectableText(
              line.label,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: line.folder ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (line.detail != null) ...[
            const SizedBox(width: 8),
            Text(
              line.detail!,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
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
