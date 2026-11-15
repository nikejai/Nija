import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/dashboard_typography.dart';
import '../../../app/theme/entry_typography.dart';
import '../../../app/widgets/nija_brand_lockup.dart';
import '../../../core/config/app_features.dart';
import '../../../core/config/vault_limits.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/platform/pwa_install_service.dart';
import '../../../core/security/encrypted_share_codec.dart';
import '../../../core/security/secure_clipboard.dart';
import '../../../domain/validators/vault_validators.dart';
import '../../../domain/models/vault_folder.dart';
import '../../../application/services/vault_folder_manager.dart';
import '../application/vault_entry_activity.dart';
import '../application/vault_home_demo_data.dart';
import '../../../infrastructure/adapters/vault_portability_model.dart';
import '../../../infrastructure/adapters/secret_share_portability.dart';
import '../../../infrastructure/adapters/secret_share_portability_base.dart';
import 'add_vault_item_screen.dart';
import 'create_custom_type_screen.dart';
import 'document_upload_screen.dart';
import 'note_editor_screen.dart';
import 'widgets/vault_entry_list.dart';
import 'widgets/vault_document_preview_widgets.dart';
import 'widgets/pwa_install_dialog.dart';
import 'widgets/vault_page_heading.dart';
import 'widgets/vault_surface_menu.dart';
import 'widgets/vault_folders_view.dart';
import '../../../application/services/automated_backup_service.dart';
import '../../../domain/models/local_vault_snapshot.dart';

part 'widgets/encrypted_import_widgets.dart';
part 'custom_template_manager_screen.dart';
part 'document_detail_screen.dart';
part 'item_detail_screen.dart';
part 'widgets/vault_settings_widgets.dart';
part 'widgets/vault_common_widgets.dart';
part 'widgets/vault_debug_view.dart';
part 'widgets/vault_home_view.dart';
part 'widgets/vault_types_view.dart';
part 'widgets/vault_favorites_view.dart';
part 'widgets/vault_settings_view.dart';

String _vaultDashboardTypeCode(String type) {
  return switch (type) {
    'Login' => 'LG',
    'Secure Note' => 'NT',
    'Notes' => 'NT',
    'Identity' => 'ID',
    'Passport' => 'ID',
    'Driver License' => 'ID',
    'Card' => 'CC',
    'Document' => 'DC',
    'Documents' => 'DC',
    _ =>
      type.trim().isEmpty
          ? 'IT'
          : type
                .split(RegExp(r'\s+'))
                .where((part) => part.isNotEmpty)
                .map((part) => part[0])
                .take(2)
                .join()
                .toUpperCase(),
  };
}

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
typedef PersistVaultFolders =
    Future<void> Function(List<Map<String, dynamic>> folders);
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
typedef VaultDocumentLoadProgress =
    void Function(String message, double progress);
typedef ReadVaultDocument =
    Future<List<int>> Function({
      required String sectionName,
      VaultDocumentLoadProgress? onProgress,
    });
typedef LifecycleLockSuppressed = void Function(bool suppressed);
typedef VaultFileAction = Future<void> Function();
typedef CloudBackupAction = Future<void> Function();
typedef CloudBackupAccountRead = Future<String?> Function();
typedef CloudBackupAccountChange = Future<bool> Function();
typedef CloudBackupSummaryRead = Future<CloudVaultBackupFile?> Function();
typedef RenameVault = Future<void> Function(String name);
typedef ReadVaultInternals = Future<Map<String, dynamic>> Function();

class VaultAppShell extends StatefulWidget {
  const VaultAppShell({
    super.key,
    this.activeVaultName = 'vault.nija',
    this.vaultSizeBytes = 0,
    this.activeVaultRevision = 0,
    this.activeVaultVersionId = '',
    this.activeVaultUpdatedAt = '',
    required this.recoveryWords,
    required this.initialItems,
    required this.initialNotes,
    required this.initialCustomTypeDefinitions,
    this.initialFolders = const <Map<String, dynamic>>[],
    required this.languageMode,
    required this.onLanguageModeChanged,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
    this.autoLockSeconds = 300,
    this.onAutoLockSecondsChanged,
    required this.biometricEnabled,
    this.biometricAvailable = true,
    this.pinEnabled = false,
    this.onPinChanged,
    required this.onBiometricChanged,
    required this.onPersistVaultData,
    this.onPersistFolders,
    this.onPersistVaultDocument,
    this.onPersistVaultDocumentStream,
    this.onReadVaultDocument,
    this.onLifecycleLockSuppressed,
    required this.onRotateMasterPassword,
    required this.onRotateRecoveryPhrase,
    required this.onLockNow,
    this.onSwitchVault,
    required this.onExportVault,
    required this.onImportVault,
    required this.onBackupToCloud,
    required this.onRestoreFromCloud,
    required this.onReadCloudBackupAccount,
    required this.onChangeCloudBackupAccount,
    this.onReadCloudBackupSummary,
    this.onRenameVault,
    this.onReadVaultInternals,
    this.cloudBackupFeatureAvailableOverride,
    this.debugInternalsFeatureAvailableOverride,
    this.expandedVaultStorageEntitled = true,
    this.isExploreDemoSession = false,
    this.onExitExploreDemo,
    this.secretSharePortability,
    this.onReadRawVaultContent,
    this.onRestoreRawVaultContent,
  });

  final List<String> recoveryWords;
  final String activeVaultName;
  final int vaultSizeBytes;
  final int activeVaultRevision;
  final String activeVaultVersionId;
  final String activeVaultUpdatedAt;
  final List<Map<String, dynamic>> initialItems;
  final List<Map<String, dynamic>> initialNotes;
  final List<Map<String, dynamic>> initialCustomTypeDefinitions;
  final List<Map<String, dynamic>> initialFolders;
  final String languageMode;
  final LanguageModeChanged onLanguageModeChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final int autoLockSeconds;
  final ValueChanged<int>? onAutoLockSecondsChanged;
  final bool biometricEnabled;
  final bool biometricAvailable;
  final bool pinEnabled;
  final BiometricChanged? onPinChanged;
  final BiometricChanged onBiometricChanged;
  final PersistVaultData onPersistVaultData;
  final PersistVaultFolders? onPersistFolders;
  final PersistVaultDocument? onPersistVaultDocument;
  final PersistVaultDocumentStream? onPersistVaultDocumentStream;
  final ReadVaultDocument? onReadVaultDocument;
  final LifecycleLockSuppressed? onLifecycleLockSuppressed;
  final RotateMasterPassword onRotateMasterPassword;
  final RotateRecoveryPhrase onRotateRecoveryPhrase;
  final VoidCallback onLockNow;
  final VoidCallback? onSwitchVault;
  final VaultFileAction onExportVault;
  final VaultFileAction onImportVault;
  final CloudBackupAction onBackupToCloud;
  final CloudBackupAction onRestoreFromCloud;
  final CloudBackupAccountRead onReadCloudBackupAccount;
  final CloudBackupAccountChange onChangeCloudBackupAccount;
  final CloudBackupSummaryRead? onReadCloudBackupSummary;
  final RenameVault? onRenameVault;
  final ReadVaultInternals? onReadVaultInternals;
  final bool? cloudBackupFeatureAvailableOverride;
  final bool? debugInternalsFeatureAvailableOverride;
  final bool expandedVaultStorageEntitled;
  final bool isExploreDemoSession;
  final VoidCallback? onExitExploreDemo;
  final SecretSharePortabilityAdapter? secretSharePortability;
  final Future<String> Function()? onReadRawVaultContent;
  final Future<bool> Function(String content)? onRestoreRawVaultContent;

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
  static const String _prefsKeyAutomatedBackupEnabled =
      'nija_pref_automated_backup_enabled_v1';
  static const String _prefsKeyCloudBackupWifiOnly =
      'nija_pref_cloud_backup_wifi_only_v1';
  static const String _prefsKeyLocalBackupLastAt =
      'nija_pref_local_backup_last_at_v1';
  static const String _prefsKeyCloudBackupLastAt =
      'nija_pref_cloud_backup_last_at_v1';
  static const String _prefsKeyCloudBackupRevision =
      'nija_pref_cloud_backup_revision_v1';
  static const String _prefsKeyCloudBackupVersionId =
      'nija_pref_cloud_backup_version_id_v1';
  static const String _prefsKeyCloudBackupUpdatedAt =
      'nija_pref_cloud_backup_updated_at_v1';
  static const String _prefsKeyDebugInternalsUnlocked =
      'nija_pref_debug_internals_unlocked_v1';
  static const String _prefsKeyDebugInternalsEnabled =
      'nija_pref_debug_internals_enabled_v1';
  static const int _debugInternalsUnlockTapCount = 7;
  static const int _debugInternalsFeedbackStartTapCount = 3;
  final _clipboard = SecureClipboard();
  final _allItemsSearchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _encryptedShareCodec = EncryptedShareCodec();
  late final SecretSharePortabilityAdapter _secretSharePortability;
  int _tabIndex = 0;
  String _allItemsQuery = '';
  String _allItemsFilterSearch = '';
  String _allItemsTypeFilter = 'all';
  Set<String> _allItemsFilterTypes = <String>{};
  bool _allItemsFilterFavoritesOnly = false;
  String _allItemsFilterDateRange = 'any';
  bool _automatedBackupEnabled = true;
  bool _cloudBackupWifiOnly = true;
  int _localBackupLastAtEpochMs = 0;
  List<LocalVaultSnapshot> _localSnapshots = <LocalVaultSnapshot>[];
  final AutomatedBackupService _automatedBackupService =
      AutomatedBackupService();
  Timer? _midnightBackupTimer;
  bool _cloudBackupEnabled = false;
  bool _importingEncryptedSecret = false;
  String _importBusyMessage = 'Importing data...';
  int _backgroundBusyCount = 0;
  String _backgroundBusyMessage = 'Working...';
  int _storedDocumentBytesThisSession = 0;
  int _cloudBackupLastAtEpochMs = 0;
  int _cloudBackupRevision = 0;
  String _cloudBackupVersionId = '';
  String _cloudBackupUpdatedAt = '';
  String _cloudBackupAccountLabel = 'Not connected';
  bool _cloudBackupSummaryRefreshInProgress = false;
  bool _debugInternalsUnlocked = false;
  bool _debugInternalsEnabled = false;
  int _aboutNijaTapCount = 0;
  PwaInstallStatus? _pwaInstallStatus;
  bool _allItemsSelectionMode = false;
  final Set<String> _selectedAllItemsKeys = <String>{};
  Timer? _persistDebounceTimer;
  Future<Map<String, dynamic>>? _debugInternalsFuture;
  _DashboardData? _dashboardDataCache;
  int? _dashboardDataSignature;
  bool _allowHomeDemoData = false;
  bool _showHomeDemoPreview = false;
  late final List<Map<String, dynamic>> _customTypeDefinitions;
  late final List<Map<String, dynamic>> _items;
  late final List<Map<String, dynamic>> _notes;
  late List<VaultFolder> _folders;
  final VaultFolderManager _folderManager = const VaultFolderManager();
  late final List<VaultListEntryAdapter> _vaultListEntryAdapters;
  late String _activeVaultName;

  List<_IndexedEntry> _lastDeletedAllItems = <_IndexedEntry>[];
  Map<String, bool> _lastPinnedStateItemById = <String, bool>{};
  Map<String, bool> _lastPinnedStateNoteById = <String, bool>{};
  DateTime? _lastBackOnDashboardAt;

  void _updateState(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _secretSharePortability =
        widget.secretSharePortability ?? SecretSharePortabilityAdapterImpl();
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
    _folders = widget.initialFolders
        .map((entry) => VaultFolder.fromJson(entry))
        .toList();
    _allowHomeDemoData =
        widget.isExploreDemoSession ||
        (widget.initialItems.isEmpty && widget.initialNotes.isEmpty);
    if (widget.isExploreDemoSession) {
      _showHomeDemoPreview = true;
      if (_items.isEmpty && _notes.isEmpty) {
        _items.addAll(
          VaultHomeDemoData.items.map(
            (entry) => Map<String, dynamic>.from(entry),
          ),
        );
        _notes.addAll(
          VaultHomeDemoData.notes.map(
            (entry) => Map<String, dynamic>.from(entry),
          ),
        );
        _folders.addAll(VaultHomeDemoData.cloneFolders());
      }
      _dashboardDataCache = null;
      _dashboardDataSignature = null;
    }
    _vaultListEntryAdapters = [
      const VaultDocumentListEntryAdapter(),
      VaultItemListEntryAdapter(
        iconForType: _iconForDashboardType,
        colorForType: _colorForDashboardType,
      ),
      const VaultNoteListEntryAdapter(),
    ];
    if (_notes.isEmpty &&
        !widget.isExploreDemoSession &&
        !widget.initialNotes.any(
          (note) => note['id']?.toString() == 'note-recovery-phrase',
        )) {
      _notes.add(_buildRecoveryPhraseNote());
    }
    if (widget.isExploreDemoSession) {
      _startExploreDemoPreferences();
    } else {
      unawaited(_restoreCloudBackupPreference());
      unawaited(_restoreDebugInternalsPreferences());
      unawaited(_refreshCloudBackupAccountLabel());
    }
    if (kIsWeb && !widget.isExploreDemoSession) {
      unawaited(_refreshPwaInstallStatus());
    }
  }

  Future<bool> _verifyWebTransferReady() async => true;

  Future<void> _refreshPwaInstallStatus() async {
    if (!kIsWeb || widget.isExploreDemoSession) return;
    final next = await pwaInstallService.getStatus();
    if (!mounted) return;
    final previous = _pwaInstallStatus;
    if (previous != null &&
        previous.isInstalled == next.isInstalled &&
        previous.canPrompt == next.canPrompt &&
        previous.requiresManualSteps == next.requiresManualSteps &&
        previous.platform == next.platform) {
      return;
    }
    setState(() => _pwaInstallStatus = next);
  }

  Future<void> _handlePwaInstallTap(BuildContext context) async {
    final next = await handlePwaInstallOfferTap(context);
    if (!mounted || next == null) return;
    setState(() => _pwaInstallStatus = next);
  }

  String _pwaInstallSettingsTitle(PwaInstallStatus status) =>
      pwaInstallOfferTitle(status);

  String _pwaInstallSettingsSubtitle(PwaInstallStatus status) {
    return status.useHomeScreenLabel
        ? AppStrings.pwaInstallHomeScreenHint
        : AppStrings.pwaInstallComputerHint;
  }

  IconData _pwaInstallSettingsIcon(PwaInstallStatus status) =>
      pwaInstallOfferIcon(status);

  void _startExploreDemoPreferences() {
    _automatedBackupEnabled = true;
    _cloudBackupWifiOnly = true;
    _cloudBackupEnabled = false;
    _debugInternalsUnlocked = false;
    _debugInternalsEnabled = false;
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
    if (oldWidget.activeVaultName != widget.activeVaultName ||
        !listEquals(oldWidget.initialItems, widget.initialItems) ||
        !listEquals(oldWidget.initialNotes, widget.initialNotes)) {
      _allowHomeDemoData =
          widget.isExploreDemoSession ||
          (widget.initialItems.isEmpty && widget.initialNotes.isEmpty);
      if (widget.isExploreDemoSession) {
        _showHomeDemoPreview = true;
      }
    }
    if (oldWidget.isExploreDemoSession != widget.isExploreDemoSession &&
        widget.isExploreDemoSession) {
      _showHomeDemoPreview = true;
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
    if (oldWidget.onReadVaultInternals != widget.onReadVaultInternals) {
      _debugInternalsFuture = null;
    }
  }

  @override
  void dispose() {
    _persistDebounceTimer?.cancel();
    _midnightBackupTimer?.cancel();
    _allItemsSearchController.dispose();
    _searchFocusNode.dispose();
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
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
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

  void _handleSearchShortcut() {
    setState(() {
      _allItemsTypeFilter = 'all';
      _tabIndex = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _handleNewItemShortcut() {
    _openAddItemScreen(context);
  }

  void _handleLockShortcut() {
    widget.onLockNow();
  }

  void _handleEscapeShortcut() {
    if (_allItemsSelectionMode) {
      setState(() {
        _allItemsSelectionMode = false;
        _selectedAllItemsKeys.clear();
      });
      return;
    }
    if (_allItemsSearchController.text.isNotEmpty) {
      setState(() {
        _allItemsSearchController.clear();
        _allItemsQuery = '';
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final debugTabVisible = _debugTabVisible;
    final selectedTabIndex = debugTabVisible
        ? _tabIndex
        : (_tabIndex > 4 ? 4 : _tabIndex);
    // Mobile is the source experience. Tablet/web gain the rail and bounded
    // workspace frame without changing the routes or mobile interactions.
    final useSideNavigation = _isWideLayout(context);
    void selectDestination(int value) {
      if (value == _tabIndex) return;
      if (value == 5 && _debugTabVisible) {
        _ensureDebugInternalsFuture();
      }
      setState(() {
        if (value == 1) {
          _allItemsTypeFilter = 'all';
        }
        _tabIndex = value;
      });
      if (value == 4) {
        unawaited(_refreshCloudBackupSummary());
      }
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _handleSearchShortcut,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _handleSearchShortcut,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _handleNewItemShortcut,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            _handleNewItemShortcut,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _handleLockShortcut,
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
            _handleLockShortcut,
        const SingleActivator(LogicalKeyboardKey.escape): _handleEscapeShortcut,
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            unawaited(_handleBackNavigation());
          },
          child: Scaffold(
            body: Row(
              children: [
                if (useSideNavigation)
                  _VaultSideNavigation(
                    selectedIndex: selectedTabIndex,
                    debugTabVisible: debugTabVisible,
                    activeVaultName: _activeVaultName,
                    itemCount: _items.length + _notes.length,
                    vaultMetaLabel: widget.isExploreDemoSession
                        ? 'Demo · sample data'
                        : '${_items.length + _notes.length} items · local',
                    onLockNow: widget.onLockNow,
                    onSwitchVault: widget.onSwitchVault,
                    onThemeToggle: widget.onThemeModeChanged == null
                        ? null
                        : _toggleThemeMode,
                    themeMode: widget.themeMode,
                    onDestinationSelected: selectDestination,
                  ),
                Expanded(
                  child: useSideNavigation
                      ? Column(
                          children: [
                            _VaultDesktopHeader(
                              title: _desktopTabTitle(selectedTabIndex),
                              themeMode: widget.themeMode,
                              onThemeModeChanged:
                                  widget.onThemeModeChanged == null
                                  ? null
                                  : _toggleThemeMode,
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  KeyedSubtree(
                                    key: ValueKey<int>(_tabIndex),
                                    child: _VaultWideContentFrame(
                                      child: _buildActiveTab(context),
                                    ),
                                  ),
                                  if (_isBusyOverlayVisible)
                                    _buildBusyOverlay(context),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          children: [
                            SafeArea(
                              child: KeyedSubtree(
                                key: ValueKey<int>(_tabIndex),
                                child: _buildActiveTab(context),
                              ),
                            ),
                            if (_isBusyOverlayVisible)
                              _buildBusyOverlay(context),
                          ],
                        ),
                ),
              ],
            ),
            bottomNavigationBar: useSideNavigation
                ? null
                : NavigationBarTheme(
                    data: NavigationBarThemeData(
                      backgroundColor: colorScheme.surface,
                      indicatorColor: colorScheme.primaryContainer,
                      labelTextStyle:
                          WidgetStateProperty.resolveWith<TextStyle>((states) {
                            if (states.contains(WidgetState.selected)) {
                              return TextStyle(
                                color: colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              );
                            }
                            return TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            );
                          }),
                      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
                        (states) {
                          if (states.contains(WidgetState.selected)) {
                            return IconThemeData(
                              color: colorScheme.primary,
                              size: 24,
                            );
                          }
                          return IconThemeData(
                            color: colorScheme.onSurfaceVariant,
                            size: 22,
                          );
                        },
                      ),
                    ),
                    child: NavigationBar(
                      selectedIndex: selectedTabIndex,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.shield_outlined),
                          selectedIcon: const Icon(Icons.shield),
                          label: AppStrings.tabVault,
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.grid_view_outlined),
                          selectedIcon: const Icon(Icons.grid_view),
                          label: AppStrings.tabTypes,
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.folder_outlined),
                          selectedIcon: const Icon(Icons.folder),
                          label: AppStrings.tabFolders,
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.star_outline),
                          selectedIcon: const Icon(Icons.star),
                          label: AppStrings.tabNotes,
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.settings_outlined),
                          selectedIcon: const Icon(Icons.settings),
                          label: AppStrings.tabSettings,
                        ),
                        if (debugTabVisible)
                          const NavigationDestination(
                            icon: Icon(Icons.bug_report_outlined),
                            selectedIcon: Icon(Icons.bug_report),
                            label: 'Debug',
                          ),
                      ],
                      onDestinationSelected: selectDestination,
                    ),
                  ),
            floatingActionButton: _tabIndex == 0 || _tabIndex == 1 || _tabIndex == 2
                ? FloatingActionButton.small(
                    key: const ValueKey('vault-fab'),
                    onPressed: () {
                      if (_tabIndex == 2) {
                        _showFolderSpeedDial(context);
                      } else {
                        _openAddItemScreen(context);
                      }
                    },
                    child: const Icon(Icons.add),
                  )
                : null,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTab(BuildContext context) {
    return switch (_tabIndex) {
      0 => _buildVaultTab(context),
      1 => _buildTypesTab(context),
      2 => _buildFoldersTab(context),
      3 => _buildFavoritesTab(context),
      4 => _buildSettingsTab(context),
      5 when _debugTabVisible => _buildDebugInternalsTab(context),
      _ => _buildVaultTab(context),
    };
  }

  bool _showFolderDemoPreview = false;
  String? _currentExplorerFolderId;

  Widget _buildFoldersTab(BuildContext context) {
    final demoMode = _showFolderDemoPreview || _shouldShowHomeDemoData || widget.isExploreDemoSession;
    final folders = demoMode ? VaultHomeDemoData.demoFolders : _folders;
    final items = demoMode ? VaultHomeDemoData.items : _items;
    final notes = demoMode ? VaultHomeDemoData.notes : _notes;

    return VaultFoldersView(
      isWide: _isWideLayout(context),
      folders: folders,
      items: items,
      notes: notes,
      isDemoPreview: demoMode,
      onOpenDemoPreview: () => setState(() => _showFolderDemoPreview = true),
      onExitDemoPreview: () => setState(() => _showFolderDemoPreview = false),
      colorForType: _colorForDashboardType,
      iconForType: _iconForDashboardType,
      onFolderChanged: (folderId) => _currentExplorerFolderId = folderId,
      onOpenItem: (item) => _openVaultListRow(context, item),
      onAddItemToFolder: (folderId) =>
          _openAddItemScreen(context, initialFolderId: folderId),
      onUploadDocumentToFolder: (folderId) =>
          _openUploadDocumentToFolder(folderId),
      onCreateFolder: _createFolder,
      onRenameFolder: _renameFolder,
      onMoveFolder: _moveFolder,
      onDeleteFolder: _deleteFolder,
      onMoveItem: _moveItemToFolder,
      onCopyItem: _copyItemToFolder,
      onDeleteItem: _deleteItemFromExplorer,
    );
  }

  void _showFolderSpeedDial(BuildContext context) {
    if (_blockExploreDemoWrite()) return;
    final effectiveFolderId = _currentExplorerFolderId == VaultFoldersView.defaultFolderId
        ? null
        : _currentExplorerFolderId;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('explorer-fab-new-folder'),
                leading: const Icon(Icons.create_new_folder_outlined, color: Color(0xFFEAB308)),
                title: const Text('New Folder'),
                subtitle: const Text('Create a folder to organize items'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateFolderModal(context, parentFolderId: effectiveFolderId);
                },
              ),
              ListTile(
                key: const ValueKey('explorer-fab-add-item'),
                leading: const Icon(Icons.add_circle_outline, color: Color(0xFF3B82F6)),
                title: const Text('Add Item'),
                subtitle: const Text('Add password, note, card, or credential'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddItemScreen(context, initialFolderId: effectiveFolderId);
                },
              ),
              ListTile(
                key: const ValueKey('explorer-fab-upload-file'),
                leading: const Icon(Icons.upload_file_outlined, color: Color(0xFF10B981)),
                title: const Text('Upload File'),
                subtitle: const Text('Upload an encrypted document or attachment'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openUploadDocumentToFolder(effectiveFolderId);
                },
              ),
              ListTile(
                key: const ValueKey('explorer-fab-demo-preview'),
                leading: const Icon(Icons.visibility_outlined, color: Color(0xFF8B5CF6)),
                title: Text(
                  (_showFolderDemoPreview || _shouldShowHomeDemoData || widget.isExploreDemoSession)
                      ? 'Exit Demo Preview'
                      : 'Demo Folders Preview',
                ),
                subtitle: const Text('Explore nested folders, files, and tree view'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (_showFolderDemoPreview || _shouldShowHomeDemoData || widget.isExploreDemoSession) {
                      _showFolderDemoPreview = false;
                      _showHomeDemoPreview = false;
                    } else {
                      _showFolderDemoPreview = true;
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateFolderModal(BuildContext context, {String? parentFolderId}) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          key: const ValueKey('create-folder-name-input'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'e.g. Work, Taxes, Identity',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('create-folder-submit-button'),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 38)),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _createFolder(name, parentFolderId, null);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _createFolder(String name, String? parentId, String? color) {
    _updateState(() {
      _folders = _folderManager.createFolder(
        folders: _folders,
        name: name,
        parentId: parentId,
        color: color,
      );
    });
    _persistVaultDataUnchecked();
  }

  void _renameFolder(String folderId, String newName) {
    _updateState(() {
      _folders = _folderManager.renameFolder(
        folders: _folders,
        folderId: folderId,
        newName: newName,
      );
    });
    _persistVaultDataUnchecked();
  }

  void _moveFolder(String folderId, String? newParentId) {
    _updateState(() {
      _folders = _folderManager.moveFolder(
        folders: _folders,
        folderId: folderId,
        newParentId: newParentId,
      );
    });
    _persistVaultDataUnchecked();
  }

  void _deleteFolder(String folderId, bool cascade) {
    _updateState(() {
      final res = _folderManager.deleteFolder(
        folders: _folders,
        items: _items,
        folderId: folderId,
        cascade: cascade,
      );
      _folders = res.folders;
      _items.clear();
      _items.addAll(res.items);
    });
    _persistVaultDataUnchecked();
  }

  void _moveItemToFolder(Map<String, dynamic> item, String? targetFolderId) {
    final updated = _folderManager.moveItemToFolder(
      item: item,
      targetFolderId: targetFolderId,
    );
    _updateState(() {
      final idx = _items.indexWhere((i) => i['id'] == item['id']);
      if (idx >= 0) {
        _items[idx] = updated;
      } else {
        final noteIdx = _notes.indexWhere((n) => n['id'] == item['id']);
        if (noteIdx >= 0) {
          _notes[noteIdx] = updated;
        }
      }
    });
    _persistVaultDataUnchecked();
  }

  void _copyItemToFolder(Map<String, dynamic> item, String? targetFolderId) {
    final copy = _folderManager.copyItemToFolder(
      item: item,
      targetFolderId: targetFolderId,
    );
    _updateState(() {
      if (item['type'] == 'Secure Note' || item.containsKey('delta')) {
        _notes.add(copy);
      } else {
        _items.add(copy);
      }
    });
    _persistVaultDataUnchecked();
  }

  void _deleteItemFromExplorer(Map<String, dynamic> item) {
    final itemId = item['id'];
    _updateState(() {
      _items.removeWhere((i) => i['id'] == itemId);
      _notes.removeWhere((n) => n['id'] == itemId);
    });
    _persistVaultDataUnchecked();
  }

  Future<void> _openUploadDocumentToFolder(String? folderId) async {
    if (_blockExploreDemoWrite()) return;
    if (widget.onPersistVaultDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document storage unavailable in this session.'),
        ),
      );
      return;
    }

    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => DocumentUploadScreen(
          currentVaultSizeBytes: _effectiveVaultSizeBytes,
          maxVaultBytes: _effectiveMaxVaultBytes,
          maxDocumentBytes: VaultLimits.maxDocumentBytes,
          onLifecycleLockSuppressed: widget.onLifecycleLockSuppressed,
        ),
      ),
    );

    if (created == null) return;
    final item = Map<String, dynamic>.from(created);
    if (folderId != null) {
      item['folderId'] = folderId;
    }
    try {
      if (!await _isPendingDocumentStored(item)) return;
      if (!await _arePendingAttachmentsStored(item)) return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save document.')),
      );
      return;
    }
    _updateState(() {
      _items.insert(0, item);
    });
    await _persistVaultData();
  }

  bool get _debugInternalsFeatureAvailable =>
      // Debug internals are never available in profile/release builds.
      kDebugMode &&
      (widget.debugInternalsFeatureAvailableOverride ??
          AppFeatures.supportsDebugInternals);

  bool get _cloudBackupFeatureAvailable =>
      widget.cloudBackupFeatureAvailableOverride ??
      (widget.expandedVaultStorageEntitled || AppFeatures.supportsCloudBackup);

  bool get _cloudRestoreFeatureAvailable =>
      widget.cloudBackupFeatureAvailableOverride ?? true;

  bool get _debugTabVisible =>
      _debugInternalsFeatureAvailable &&
      _debugInternalsUnlocked &&
      _debugInternalsEnabled;

  bool get _isExploreDemoReadOnly => widget.isExploreDemoSession;

  bool _blockExploreDemoWrite([String? message]) {
    if (!widget.isExploreDemoSession) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? AppStrings.exploreDemoWriteBlocked)),
    );
    return true;
  }

  String _dashboardGreeting() {
    final hour = DateTime.now().hour;
    final period = hour < 12
        ? 'morning'
        : hour < 18
        ? 'afternoon'
        : 'evening';
    return 'Good $period, Nija User 👋';
  }

  bool _isWideLayout(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final shortestSide = viewport.shortestSide;
    final landscapeWorkspace = viewport.width >= 760 && viewport.height >= 700;
    final tabletPortraitWorkspace =
        shortestSide >= 600 && viewport.height >= 700;
    return landscapeWorkspace || tabletPortraitWorkspace;
  }

  String _desktopTabTitle(int tabIndex) {
    return switch (tabIndex) {
      0 => AppStrings.tabVault,
      1 => AppStrings.tabTypes,
      2 => AppStrings.tabFolders,
      3 => AppStrings.tabNotes,
      4 => AppStrings.tabSettings,
      5 => 'Debug',
      _ => AppStrings.tabVault,
    };
  }

  void _toggleThemeMode() {
    final onChanged = widget.onThemeModeChanged;
    if (onChanged == null) return;
    final next = widget.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    onChanged(next);
  }

  Widget _buildBusyOverlay(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(
            key: const ValueKey('vault-busy-overlay-barrier'),
            dismissible: false,
            color: Colors.black.withValues(alpha: 0.25),
          ),
          Center(
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
                        _activeBusyMessage,
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
        ],
      ),
    );
  }

  bool get _isBusyOverlayVisible =>
      !widget.isExploreDemoSession &&
      (_importingEncryptedSecret || _backgroundBusyCount > 0);

  String get _activeBusyMessage =>
      _importingEncryptedSecret ? _importBusyMessage : _backgroundBusyMessage;

  Future<T> _runWithBusy<T>(String message, Future<T> Function() action) async {
    if (widget.isExploreDemoSession) {
      return action();
    }
    if (mounted) {
      setState(() {
        _backgroundBusyCount++;
        _backgroundBusyMessage = message;
      });
    }
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() {
          _backgroundBusyCount = (_backgroundBusyCount - 1).clamp(0, 1 << 20);
          if (_backgroundBusyCount == 0) {
            _backgroundBusyMessage = 'Working...';
          }
        });
      }
    }
  }

  Future<void> _handleBackNavigation() async {
    if (_isBusyOverlayVisible) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please wait for the operation to finish.'),
        ),
      );
      return;
    }
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
    return _VaultHomeView(
      isWide: _isWideLayout(context),
      dashboardData: _dashboardData(),
      activeVaultName: _activeVaultName,
      greeting: _dashboardGreeting(),
      onAddItem: () => _openAddItemScreen(context),
      onLockNow: widget.onLockNow,
      onApplySearch: _applyDashboardSearchToAllItems,
      onOpenFilters: () => _openAllItemsFiltersOverlay(
        _allTypeFilterOptions(),
        showAllItemsOnApply: true,
      ),
      adapters: _vaultListEntryAdapters,
      keyForRow: _vaultListKeyForRow,
      iconForType: _iconForDashboardType,
      colorForType: _colorForDashboardType,
      onTypeTap: (type) => _selectDashboardType(type),
      onViewAll: () => setState(() {
        _allItemsTypeFilter = 'all';
        _tabIndex = 1;
      }),
      onImportData: () {
        if (_blockExploreDemoWrite(
          'Create or unlock a vault to import data.',
        )) {
          return;
        }
        widget.onImportVault();
      },
      onSwitchVault: widget.onSwitchVault ?? widget.onLockNow,
      onShowDemoPreview: _showHomeDemoPreviewOption,
      onHideDemoPreview: _hideHomeDemoPreview,
      onOpenRow: (row) => _openDashboardRow(context, row),
      onRowActions: (row) => _showVaultListRowQuickActions(context, row),
    );
  }

  String _vaultListKeyForRow(Map<String, dynamic> row) {
    final kind = row['kind']?.toString() ?? 'item';
    final entry = row['entry'] as Map<String, dynamic>;
    final id = entry['id']?.toString() ?? '';
    return '$kind:$id';
  }

  void _openVaultListRow(BuildContext context, Map<String, dynamic> row) {
    final entry = (row['entry'] is Map<String, dynamic>)
        ? row['entry'] as Map<String, dynamic>
        : row;
    final kind = row['kind']?.toString() ??
        (entry['type'] == 'Secure Note' || entry.containsKey('delta') ? 'note' : 'item');
    if (kind == 'note') {
      _openNoteDetail(context, entry);
    } else if (_isDocumentItem(entry)) {
      _openDocumentDetail(context, entry);
    } else {
      _openItemDetail(context, entry);
    }
  }

  void _openDashboardRow(BuildContext context, Map<String, dynamic> row) {
    if (row['demo'] == true && !widget.isExploreDemoSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is a demo preview. Add an item to start.'),
        ),
      );
      return;
    }
    _openVaultListRow(context, row);
  }

  void _selectDashboardType(String type) {
    if (_shouldShowHomeDemoData && !widget.isExploreDemoSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is a demo preview. Add an item to start.'),
        ),
      );
      return;
    }
    setState(() {
      _allItemsTypeFilter = type;
      _tabIndex = 1;
    });
  }

  void _showHomeDemoPreviewOption() {
    setState(() {
      _showHomeDemoPreview = true;
      _dashboardDataCache = null;
      _dashboardDataSignature = null;
    });
  }

  void _hideHomeDemoPreview() {
    if (widget.isExploreDemoSession) {
      widget.onExitExploreDemo?.call();
      return;
    }
    setState(() {
      _showHomeDemoPreview = false;
      _dashboardDataCache = null;
      _dashboardDataSignature = null;
    });
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
    final isDemoItem = accessedItem['demo'] == true ||
        _showFolderDemoPreview ||
        widget.isExploreDemoSession;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _DocumentDetailScreen(
          item: accessedItem,
          onReadDocument: isDemoItem
              ? ({required sectionName, onProgress}) async =>
                  VaultHomeDemoData.demoPdfBytes
              : (_isExploreDemoReadOnly ? null : widget.onReadVaultDocument),
          readOnly: _isExploreDemoReadOnly || isDemoItem,
          onShareEncryptedDocument: _shareEncryptedDocument,
          onExportEncryptedDocument: _exportEncryptedDocument,
          onSaveDocumentCopy: _saveDocumentCopy,
          customTypeDefinitions: _customTypeDefinitions,
          currentVaultSizeBytes: _effectiveVaultSizeBytes,
          maxVaultBytes: _effectiveMaxVaultBytes,
          maxDocumentBytes: VaultLimits.maxDocumentBytes,
          onLifecycleLockSuppressed: widget.onLifecycleLockSuppressed,
          onAddAttachment: (detailContext, detailItem) =>
              _addAttachmentToItem(detailContext, detailItem),
          onOpenAttachment: (attachment) => _openAttachment(attachment),
          onShareAttachment: (attachment) => _shareAttachment(attachment),
          onShareEncryptedAttachment: (attachment) =>
              _shareEncryptedAttachment(attachment),
          onExportEncryptedAttachment: (attachment) =>
              _exportEncryptedAttachment(attachment),
          onSaveAttachmentCopy: (attachment) => _saveAttachmentCopy(attachment),
          onDeleteAttachment: (detailItem, attachment) =>
              _deleteAttachmentFromItem(detailItem, attachment),
          showDeleteAction: !(_isExploreDemoReadOnly || isDemoItem),
          onShareMenu: (_isExploreDemoReadOnly || isDemoItem)
              ? null
              : () => _showDocumentQuickActions(context, accessedItem),
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
    try {
      if (!await _arePendingAttachmentsStored(result)) return;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to store attachment. Please retry.'),
        ),
      );
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

  DateTime? _activityAt(Map<String, dynamic> entry) {
    return vaultEntryActivityAt(entry);
  }

  _DashboardData _dashboardData() {
    final signature = _dashboardInputSignature();
    final cached = _dashboardDataCache;
    if (cached != null && _dashboardDataSignature == signature) {
      return cached;
    }

    final demoMode = _shouldShowHomeDemoData;
    final dashboardItems = demoMode ? VaultHomeDemoData.items : _items;
    final dashboardNotes = demoMode ? VaultHomeDemoData.notes : _notes;
    final recent = <_DashboardRecentCandidate>[];
    void addRecentCandidate(String kind, Map<String, dynamic> entry) {
      final activityAt = _activityAt(entry);
      if (activityAt == null) return;
      final candidate = _DashboardRecentCandidate(
        kind: kind,
        entry: entry,
        activityAt: activityAt,
      );
      var insertAt = recent.indexWhere(
        (existing) => activityAt.isAfter(existing.activityAt),
      );
      if (insertAt == -1) insertAt = recent.length;
      recent.insert(insertAt, candidate);
      if (recent.length > 4) {
        recent.removeLast();
      }
    }

    final typeCounts = <String, int>{};
    final folderNames = <String>{};
    for (final item in dashboardItems) {
      addRecentCandidate('item', item);
      final type = item['type']?.toString().trim();
      if (type == null || type.isEmpty) continue;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      final folder = item['folder']?.toString().trim();
      if (folder != null && folder.isNotEmpty) {
        folderNames.add(folder);
      }
    }
    for (final note in dashboardNotes) {
      addRecentCandidate('note', note);
      final folder = note['folder']?.toString().trim();
      if (folder != null && folder.isNotEmpty) {
        folderNames.add(folder);
      }
    }

    final dashboardTypes =
        <MapEntry<String, int>>[
          if (dashboardNotes.isNotEmpty)
            MapEntry<String, int>('Notes', dashboardNotes.length),
          ...typeCounts.entries,
        ]..sort((a, b) {
          final countCompare = b.value.compareTo(a.value);
          if (countCompare != 0) return countCompare;
          return a.key.toLowerCase().compareTo(b.key.toLowerCase());
        });

    final data = _DashboardData(
      recentItems: recent
          .map(
            (candidate) => <String, dynamic>{
              'kind': candidate.kind,
              'entry': candidate.entry,
              'updatedLabel': _relativeTimeLabel(candidate.activityAt),
              if (demoMode) 'demo': true,
            },
          )
          .toList(growable: false),
      dashboardTypes: dashboardTypes,
      typeCounts: Map<String, int>.unmodifiable(typeCounts),
      totalCount: dashboardItems.length + dashboardNotes.length,
      folderCount: demoMode
          ? VaultHomeDemoData.folders.length
          : folderNames.length,
      isDemo: demoMode,
      canShowDemoPreview: _canOfferHomeDemoPreview && !demoMode,
      isExploreSession: widget.isExploreDemoSession,
    );
    _dashboardDataSignature = signature;
    _dashboardDataCache = data;
    return data;
  }

  bool get _shouldShowHomeDemoData {
    if (widget.isExploreDemoSession) return false;
    if (!_showHomeDemoPreview) return false;
    if (!_canOfferHomeDemoPreview) return false;
    return true;
  }

  bool get _canOfferHomeDemoPreview {
    if (widget.isExploreDemoSession) return false;
    if (!_allowHomeDemoData) return false;
    if (_items.isNotEmpty) return false;
    if (_notes.isEmpty) return true;
    if (_notes.length != 1) return false;
    return _notes.single['id']?.toString() == 'note-recovery-phrase';
  }

  int _dashboardInputSignature() {
    final values = <Object?>[
      DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute,
      widget.isExploreDemoSession,
      _showHomeDemoPreview,
      _items.length,
      _notes.length,
    ];
    for (final item in _items) {
      values.addAll([
        item['id'],
        item['type'],
        item['title'],
        item['subtitle'],
        item['updated'],
        item['updatedAt'],
        item['documentUploadedAt'],
        item['createdAt'],
        item['lastAccessedAt'],
        item['pinned'],
      ]);
    }
    for (final note in _notes) {
      values.addAll([
        note['id'],
        note['title'],
        note['preview'],
        note['updated'],
        note['updatedAt'],
        note['createdAt'],
        note['lastAccessedAt'],
        note['pinned'],
      ]);
    }
    return Object.hashAll(values);
  }

  DateTime? _parseEntryTimestamp(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String _relativeTimeLabel(DateTime timestamp) =>
      formatRelativeTimeSince(timestamp);

  bool _matchesAllItemsDateFilter(Map<String, dynamic> entry) {
    if (_allItemsFilterDateRange == 'any') return true;
    final ageDays = vaultEntryAgeDays(entry);
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
      _allItemsTypeFilter = 'all';
      _allItemsFilterSearch = '';
      _allItemsFilterTypes = <String>{};
      _allItemsFilterFavoritesOnly = false;
      _allItemsFilterDateRange = 'any';
      _allItemsSearchController.text = query;
      _allItemsSearchController.selection = TextSelection.collapsed(
        offset: query.length,
      );
      _tabIndex = 1;
    });
  }

  String _entrySearchText(String kind, Map<String, dynamic> entry) {
    final values = <String>[
      entry['title']?.toString() ?? '',
      entry['subtitle']?.toString() ?? '',
      entry['preview']?.toString() ?? '',
      entry['type']?.toString() ?? '',
      entry['folder']?.toString() ?? '',
      entry['updated']?.toString() ?? '',
    ];
    final tags = entry['tags'];
    if (tags is List) {
      values.addAll(tags.map((tag) => tag.toString()));
    }
    final fields = entry['fields'];
    if (fields is List) {
      for (final rawField in fields) {
        if (rawField is! Map) continue;
        values.add(rawField['label']?.toString() ?? '');
        values.add(rawField['value']?.toString() ?? '');
      }
    }
    if (kind == 'note') {
      final delta = entry['delta'];
      if (delta is List) {
        for (final rawOp in delta) {
          if (rawOp is! Map) continue;
          values.add(rawOp['insert']?.toString() ?? '');
        }
      }
    }
    return values.join(' ').toLowerCase();
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
    final initialState = _AllItemsFilterState(
      search: _allItemsFilterSearch,
      selectedTypes: _allItemsFilterTypes,
      favoritesOnly: _allItemsFilterFavoritesOnly,
      dateRange: _allItemsFilterDateRange,
    );
    final isWide = _isWideLayout(context);
    final applied = isWide
        ? await showDialog<_AllItemsFilterState>(
            context: context,
            builder: (context) => Dialog(
              insetPadding: const EdgeInsets.all(28),
              child: SizedBox(
                width: 580,
                height: 680,
                child: _AllItemsFiltersOverlay(
                  initialState: initialState,
                  typeOptions: typeOptions,
                ),
              ),
            ),
          )
        : await Navigator.of(context).push<_AllItemsFilterState>(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, animation, secondaryAnimation) =>
                  _AllItemsFiltersOverlay(
                    initialState: initialState,
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

  Widget _buildDebugInternalsTab(BuildContext context) {
    return _VaultDebugView(
      internalsFuture: _ensureDebugInternalsFuture(),
      onRefresh: widget.onReadVaultInternals == null
          ? null
          : _refreshDebugInternals,
      hasReader: widget.onReadVaultInternals != null,
      activeVaultName: _activeVaultName,
      vaultSizeBytes: widget.vaultSizeBytes,
      itemCount: _items.length,
      noteCount: _notes.length,
      customTypeCount: _customTypeDefinitions.length,
    );
  }

  Future<Map<String, dynamic>>? _ensureDebugInternalsFuture() {
    final read = widget.onReadVaultInternals;
    if (read == null) return null;
    return _debugInternalsFuture ??= read();
  }

  void _refreshDebugInternals() {
    final read = widget.onReadVaultInternals;
    if (read == null) return;
    final next = read();
    setState(() {
      _debugInternalsFuture = next;
    });
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
    final selected = await showVaultChoiceMenu<String>(
      context: context,
      title: AppStrings.language,
      options: [
        VaultMenuOption(
          value: 'system',
          title: AppStrings.systemDefault,
          trailing: widget.languageMode == 'system'
              ? const Icon(Icons.check)
              : null,
        ),
        VaultMenuOption(
          value: 'en',
          title: 'English',
          trailing: widget.languageMode == 'en'
              ? const Icon(Icons.check)
              : null,
        ),
        VaultMenuOption(
          value: 'es',
          title: 'Español',
          trailing: widget.languageMode == 'es'
              ? const Icon(Icons.check)
              : null,
        ),
      ],
    );
    if (selected == null || selected == widget.languageMode) return;
    widget.onLanguageModeChanged(selected);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.languageUpdated)));
  }

  Future<void> _showThemePicker(BuildContext context) async {
    final onThemeModeChanged = widget.onThemeModeChanged;
    if (onThemeModeChanged == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.settingComingSoon)));
      return;
    }

    final selected = await showVaultChoiceMenu<ThemeMode>(
      context: context,
      title: 'Theme',
      options: [
        VaultMenuOption(
          value: ThemeMode.system,
          title: 'System',
          trailing: widget.themeMode == ThemeMode.system
              ? const Icon(Icons.check)
              : null,
        ),
        VaultMenuOption(
          value: ThemeMode.light,
          title: 'Light',
          trailing: widget.themeMode == ThemeMode.light
              ? const Icon(Icons.check)
              : null,
        ),
        VaultMenuOption(
          value: ThemeMode.dark,
          title: 'Dark',
          trailing: widget.themeMode == ThemeMode.dark
              ? const Icon(Icons.check)
              : null,
        ),
      ],
    );
    if (selected == null || selected == widget.themeMode) return;
    onThemeModeChanged(selected);
  }

  Future<void> _showInfoSheet(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_InfoSectionData> sections,
    Widget? brandHeader,
  }) async {
    await showVaultSurfaceSheet<void>(
      context: context,
      scrollControlled: true,
      builder: (context) => _InfoDetailSheet(
        title: title,
        icon: icon,
        sections: sections,
        brandHeader: brandHeader,
      ),
    );
  }

  Future<void> _showSecurityEncryptionSheet(BuildContext context) async {
    final metadataFuture = widget.onReadVaultInternals?.call();
    if (!context.mounted) return;
    await showVaultSurfaceSheet<void>(
      context: context,
      scrollControlled: true,
      builder: (sheetContext) => _SecurityEncryptionSheet(
        metadataFuture: metadataFuture,
        biometricEnabled: widget.biometricEnabled,
        autoLockLabel: _formatAutoLockSeconds(widget.autoLockSeconds),
        cloudBackupEnabled: _cloudBackupEnabled,
        cloudBackupLastLabel: _cloudBackupLastAtEpochMs <= 0
            ? 'Never'
            : DateTime.fromMillisecondsSinceEpoch(
                _cloudBackupLastAtEpochMs,
              ).toString(),
      ),
    );
  }

  Future<void> _handleCloudBackupLockedTap() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cloud backup is currently unavailable.')),
    );
  }

  List<_InfoSectionData> _aboutNijaSections() {
    return const <_InfoSectionData>[
      _InfoSectionData(
        title: 'Nija · निज',
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

    final selected = await showVaultSurfaceSheet<int>(
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
          readOnly: _isExploreDemoReadOnly,
          customTypeDefinitions: _customTypeDefinitions,
          currentVaultSizeBytes: _effectiveVaultSizeBytes,
          maxVaultBytes: _effectiveMaxVaultBytes,
          maxDocumentBytes: VaultLimits.maxDocumentBytes,
          onLifecycleLockSuppressed: widget.onLifecycleLockSuppressed,
          showDeleteAction: !_isExploreDemoReadOnly,
          onAddAttachment: (detailContext, detailItem) =>
              _addAttachmentToItem(detailContext, detailItem),
          onReadAttachment: (attachment) => _readAttachmentBytes(attachment),
          onOpenAttachment: (attachment) => _openAttachment(attachment),
          onShareAttachment: (attachment) => _shareAttachment(attachment),
          onShareEncryptedAttachment: (attachment) =>
              _shareEncryptedAttachment(attachment),
          onExportEncryptedAttachment: (attachment) =>
              _exportEncryptedAttachment(attachment),
          onSaveAttachmentCopy: (attachment) => _saveAttachmentCopy(attachment),
          onDeleteAttachment: (detailItem, attachment) =>
              _deleteAttachmentFromItem(detailItem, attachment),
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
          onShareMenu: _isExploreDemoReadOnly
              ? null
              : () => _showItemQuickActions(context, accessedItem),
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
    await _runWithBusy('Preparing encrypted document...', () async {
      await _shareEncryptedSecret(
        plainText: _documentEncryptedPayload(item, bytes),
        suggestedBaseName: _documentSuggestedBaseName(item),
        contentType: 'document',
      );
    });
  }

  Future<void> _exportEncryptedDocument(
    Map<String, dynamic> item,
    List<int> bytes,
  ) async {
    await _runWithBusy('Exporting encrypted document...', () async {
      await _exportEncryptedSecret(
        plainText: _documentEncryptedPayload(item, bytes),
        suggestedBaseName: _documentSuggestedBaseName(item),
        contentType: 'document',
      );
    });
  }

  Future<bool> _saveDocumentCopy(
    Map<String, dynamic> item,
    List<int> bytes,
  ) async {
    return _runWithBusy('Saving document copy...', () {
      return _secretSharePortability.exportPlainFile(
        suggestedName: _documentFileName(item),
        bytes: Uint8List.fromList(bytes),
        mimeType: _mimeTypeForExtension(_documentExtension(item)),
      );
    });
  }

  Future<Map<String, dynamic>?> _addAttachmentToItem(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final uploaded = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => DocumentUploadScreen(
          currentVaultSizeBytes: _effectiveVaultSizeBytes,
          maxVaultBytes: _effectiveMaxVaultBytes,
          maxDocumentBytes: VaultLimits.maxDocumentBytes,
          onLifecycleLockSuppressed: widget.onLifecycleLockSuppressed,
        ),
      ),
    );
    if (uploaded == null) return null;
    return _runWithBusy('Saving attached document...', () async {
      final attachments = _attachmentsFromUploadedDocument(uploaded);
      if (attachments.isEmpty) return null;
      for (final attachment in attachments) {
        if (!await _isPendingAttachmentStored(item, attachment)) return null;
      }
      final updatedItem = _itemWithAttachments(item, attachments);
      if (!await _replaceItemAndPersist(updatedItem)) return null;
      item['attachments'] = _itemAttachments(updatedItem);
      return attachments.first;
    });
  }

  List<Map<String, dynamic>> _attachmentsFromUploadedDocument(
    Map<String, dynamic> document,
  ) {
    return [
      _attachmentFromUploadedDocument(document),
      ...(document['attachments'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map((entry) => Map<String, dynamic>.from(entry)),
    ];
  }

  Map<String, dynamic> _attachmentFromUploadedDocument(
    Map<String, dynamic> document,
  ) {
    final uploadedAt =
        document['documentUploadedAt']?.toString() ??
        DateTime.now().toUtc().toIso8601String();
    final id =
        'attachment-${DateTime.now().microsecondsSinceEpoch}-${_items.length}';
    return {
      'id': id,
      'title': document['title']?.toString().trim().isNotEmpty == true
          ? document['title'].toString().trim()
          : document['documentFileName']?.toString() ?? 'Document',
      'subtitle': document['subtitle']?.toString() ?? '',
      'documentFileName':
          document['documentFileName']?.toString() ?? 'document',
      'documentExtension': document['documentExtension']?.toString() ?? 'FILE',
      'documentSizeBytes': document['documentSizeBytes'] ?? 0,
      'documentUploadedAt': uploadedAt,
      'documentStorage': 'pending',
      if (document['tags'] is List)
        'tags': List<String>.from(
          (document['tags'] as List).map((entry) => entry.toString()),
        ),
      if (document['__documentReadStream__'] != null)
        '__documentReadStream__': document['__documentReadStream__'],
      if (document['__documentBytes__'] != null)
        '__documentBytes__': document['__documentBytes__'],
    };
  }

  Future<bool> _isPendingAttachmentStored(
    Map<String, dynamic> item,
    Map<String, dynamic> attachment,
  ) async {
    final rawStream = attachment.remove('__documentReadStream__');
    final rawBytes = attachment.remove('__documentBytes__');
    if (rawStream == null && rawBytes == null) return true;
    if (widget.onPersistVaultDocument == null &&
        widget.onPersistVaultDocumentStream == null) {
      attachment['documentStorage'] = 'inline-unavailable';
      return true;
    }
    final sizeBytes = _documentMetadataSizeBytes(attachment);
    final itemId = item['id']?.toString() ?? 'item';
    final attachmentId = attachment['id']?.toString() ?? 'attachment';
    final documentId = '${itemId}_$attachmentId';
    if (rawStream != null) {
      if (widget.onPersistVaultDocumentStream == null) {
        attachment['documentStorage'] = 'inline-unavailable';
        return true;
      }
      if (!_canStoreDocumentBytes(sizeBytes)) return false;
      final stream = rawStream as Stream<List<int>>;
      final sectionName = await widget.onPersistVaultDocumentStream!(
        documentId: documentId,
        chunks: stream,
        sizeBytes: sizeBytes,
      );
      _storedDocumentBytesThisSession += sizeBytes;
      attachment['documentStorage'] = 'private-section';
      attachment['documentSection'] = sectionName;
      return true;
    }
    final bytes = rawBytes is Uint8List
        ? rawBytes
        : Uint8List.fromList(List<int>.from(rawBytes as List));
    final storedSizeBytes = _documentMetadataSizeBytes(
      attachment,
      fallbackBytes: bytes.length,
    );
    if (!_canStoreDocumentBytes(storedSizeBytes)) return false;
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
    attachment['documentStorage'] = 'private-section';
    attachment['documentSection'] = sectionName;
    return true;
  }

  Future<bool> _arePendingAttachmentsStored(Map<String, dynamic> item) async {
    final attachments = _itemAttachments(item);
    if (attachments.isEmpty) {
      item.remove('attachments');
      return true;
    }
    for (final attachment in attachments) {
      if (!await _isPendingAttachmentStored(item, attachment)) return false;
    }
    item['attachments'] = attachments;
    return true;
  }

  Map<String, dynamic> _itemWithAttachments(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> newAttachments,
  ) {
    final attachments = _itemAttachments(item)
      ..addAll(newAttachments.map((entry) => Map<String, dynamic>.from(entry)));
    return {...Map<String, dynamic>.from(item), 'attachments': attachments};
  }

  Future<bool> _replaceItemAndPersist(Map<String, dynamic> updatedItem) async {
    final id = updatedItem['id']?.toString();
    final idx = _items.indexWhere((entry) => entry['id']?.toString() == id);
    if (idx == -1) return false;
    setState(
      () => _items[idx] = _preserveLastAccessedAt(updatedItem, _items[idx]),
    );
    await _persistVaultData();
    return true;
  }

  Future<void> _deleteAttachmentFromItem(
    Map<String, dynamic> item,
    Map<String, dynamic> attachment,
  ) async {
    await _runWithBusy('Removing attached document...', () async {
      final attachmentId = attachment['id']?.toString();
      final attachments = _itemAttachments(item)
        ..removeWhere((entry) => entry['id']?.toString() == attachmentId);
      final updatedItem = {
        ...Map<String, dynamic>.from(item),
        'attachments': attachments,
      };
      await _replaceItemAndPersist(updatedItem);
    });
  }

  Future<List<int>> _readAttachmentBytes(
    Map<String, dynamic> attachment,
  ) async {
    final directBytes = attachment['__documentBytes__'] ?? attachment['documentBytes'];
    if (directBytes is List<int> && directBytes.isNotEmpty) {
      return directBytes;
    }
    if (attachment['demo'] == true || _showFolderDemoPreview || widget.isExploreDemoSession) {
      return VaultHomeDemoData.demoPdfBytes;
    }
    final sectionName = attachment['documentSection']?.toString().trim() ?? '';
    final reader = widget.onReadVaultDocument;
    if (sectionName.isEmpty || reader == null) {
      throw StateError('Attachment reader unavailable.');
    }
    return reader(sectionName: sectionName);
  }

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    await _runWithBusy('Opening document...', () async {
      final bytes = await _readAttachmentBytes(attachment);
      final fileName = _documentFileName(attachment);
      final mimeType = _mimeTypeForExtension(_documentExtension(attachment));
      try {
        await _documentOpenChannel.invokeMethod<bool>('openDocument', {
          'fileName': fileName,
          'mimeType': mimeType,
          'bytes': Uint8List.fromList(bytes),
        });
      } on MissingPluginException {
        await _secretSharePortability.exportPlainFile(
          suggestedName: fileName,
          bytes: Uint8List.fromList(bytes),
          mimeType: mimeType,
        );
      }
    });
  }

  Future<void> _shareAttachment(Map<String, dynamic> attachment) async {
    await _runWithBusy('Preparing document share...', () async {
      final bytes = await _readAttachmentBytes(attachment);
      final fileName = _documentFileName(attachment);
      final mimeType = _mimeTypeForExtension(_documentExtension(attachment));
      if (kIsWeb) {
        final exported = await _secretSharePortability.exportPlainFile(
          suggestedName: fileName,
          bytes: Uint8List.fromList(bytes),
          mimeType: mimeType,
        );
        if (exported) return;
      }
      try {
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
      } catch (_) {
        await _secretSharePortability.exportPlainFile(
          suggestedName: fileName,
          bytes: Uint8List.fromList(bytes),
          mimeType: mimeType,
        );
      }
    });
  }

  Future<void> _shareEncryptedAttachment(
    Map<String, dynamic> attachment,
  ) async {
    await _runWithBusy('Preparing encrypted document...', () async {
      final bytes = await _readAttachmentBytes(attachment);
      await _shareEncryptedDocument(attachment, bytes);
    });
  }

  Future<void> _exportEncryptedAttachment(
    Map<String, dynamic> attachment,
  ) async {
    await _runWithBusy('Exporting encrypted document...', () async {
      final bytes = await _readAttachmentBytes(attachment);
      await _exportEncryptedDocument(attachment, bytes);
    });
  }

  Future<bool> _saveAttachmentCopy(Map<String, dynamic> attachment) async {
    return _runWithBusy('Saving document copy...', () async {
      final bytes = await _readAttachmentBytes(attachment);
      return _saveDocumentCopy(attachment, bytes);
    });
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
          readOnly: _isExploreDemoReadOnly,
          showDeleteAction: !_isExploreDemoReadOnly,
          onAutoSave: _isExploreDemoReadOnly ? null : _upsertNoteAndPersist,
          onShareMenu: _isExploreDemoReadOnly
              ? null
              : () => _showNoteQuickActions(context, accessedNote),
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
    _schedulePersistVaultData();
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
    _schedulePersistVaultData();
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

  Future<void> _openAddItemScreen(
    BuildContext context, {
    String? initialFolderId,
  }) async {
    if (_blockExploreDemoWrite()) return;
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => NewItemCategoryScreen(
          customTypeDefinitions: _customTypeDefinitions,
          currentVaultSizeBytes: _effectiveVaultSizeBytes,
          maxVaultBytes: _effectiveMaxVaultBytes,
          maxDocumentBytes: VaultLimits.maxDocumentBytes,
          onLifecycleLockSuppressed: widget.onLifecycleLockSuppressed,
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
                  maxVaultBytes: _effectiveMaxVaultBytes,
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
    if (initialFolderId != null) {
      entry['folderId'] = initialFolderId;
    }
    if (kind == 'note') {
      setState(() => _notes.insert(0, Map<String, dynamic>.from(entry)));
      await _persistVaultData();
      return;
    }
    final item = Map<String, dynamic>.from(entry);
    try {
      if (!await _isPendingDocumentStored(item)) return;
      if (!await _arePendingAttachmentsStored(item)) return;
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
    _schedulePersistVaultData();
  }

  void _schedulePersistVaultData() {
    if (widget.isExploreDemoSession) return;
    _persistDebounceTimer?.cancel();
    _persistDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persistVaultData());
    });
  }

  Future<void> _persistVaultData() async {
    if (widget.isExploreDemoSession) return;
    if (_backgroundBusyCount == 0 && !_importingEncryptedSecret) {
      await _runWithBusy('Saving vault updates...', _persistVaultDataUnchecked);
      return;
    }
    await _persistVaultDataUnchecked();
  }

  Future<void> _persistVaultDataUnchecked() async {
    if (_blockExploreDemoWrite()) return;
    try {
      await widget.onPersistVaultData(
        items: _serializableVaultEntries(_items),
        notes: _serializableVaultEntries(_notes),
        customTypeDefinitions: _serializableVaultEntries(
          _customTypeDefinitions,
        ),
      );
      if (widget.onPersistFolders != null) {
        await widget.onPersistFolders!(
          _folders.map((f) => f.toJson()).toList(),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to persist vault updates. Please retry.'),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _serializableVaultEntries(
    List<Map<String, dynamic>> entries,
  ) {
    return entries
        .map((entry) => _serializableVaultValue(entry) as Map<String, dynamic>)
        .toList();
  }

  Object? _serializableVaultValue(Object? value) {
    if (value is Map) {
      final copy = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (key.startsWith('__')) continue;
        copy[key] = _serializableVaultValue(entry.value);
      }
      return copy;
    }
    if (value is List) {
      return value.map(_serializableVaultValue).toList();
    }
    return value;
  }

  int _updatedRank(Map<String, dynamic> entry) {
    final updated = entry['updated']?.toString().trim() ?? '';
    if (updated.toLowerCase() == 'now') return 999999999;
    return 0;
  }

  Future<void> _restoreCloudBackupPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final automatedEnabled =
          prefs.getBool(_prefsKeyAutomatedBackupEnabled) ?? true;
      final wifiOnly =
          prefs.getBool(_prefsKeyCloudBackupWifiOnly) ?? true;
      final localLastAt = prefs.getInt(_prefsKeyLocalBackupLastAt) ?? 0;
      final enabled = prefs.getBool(_prefsKeyCloudBackupEnabled) ?? false;
      final lastAt = prefs.getInt(_prefsKeyCloudBackupLastAt) ?? 0;
      final revision = prefs.getInt(_prefsKeyCloudBackupRevision) ?? 0;
      final versionId = prefs.getString(_prefsKeyCloudBackupVersionId) ?? '';
      final updatedAt = prefs.getString(_prefsKeyCloudBackupUpdatedAt) ?? '';
      if (!mounted) return;
      setState(() {
        _automatedBackupEnabled = automatedEnabled;
        _cloudBackupWifiOnly = wifiOnly;
        _localBackupLastAtEpochMs = localLastAt;
        _cloudBackupEnabled = enabled && _cloudBackupFeatureAvailable;
        _cloudBackupLastAtEpochMs = lastAt;
        _cloudBackupRevision = revision;
        _cloudBackupVersionId = versionId;
        _cloudBackupUpdatedAt = updatedAt;
      });
      if (enabled && _cloudBackupFeatureAvailable) {
        unawaited(_refreshCloudBackupSummary());
      }
      unawaited(_refreshLocalSnapshots());
      if (_automatedBackupEnabled) {
        _startMidnightBackupSchedule();
        unawaited(_checkAndRunDueAutomatedBackup());
      }
    } catch (_) {
      // Ignore preference read failures.
    }
  }

  bool get _isTestEnvironment =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  void _startMidnightBackupSchedule() {
    _midnightBackupTimer?.cancel();
    if (_isTestEnvironment) {
      return;
    }
    _midnightBackupTimer = _automatedBackupService.scheduleMidnightBackup(
      onMidnightBackup: () async {
        await _runAutomatedBackup();
      },
    );
  }

  Future<void> _checkAndRunDueAutomatedBackup() async {
    if (_isTestEnvironment) {
      return;
    }
    if (!_automatedBackupEnabled) return;
    if (_localBackupLastAtEpochMs <= 0) return;
    final lastBackup =
        DateTime.fromMillisecondsSinceEpoch(_localBackupLastAtEpochMs);
    if (AutomatedBackupService.isBackupDue(lastBackup)) {
      await _runAutomatedBackup();
    }
  }

  Future<void> _refreshLocalSnapshots() async {
    final vaultId = widget.activeVaultVersionId.isNotEmpty
        ? widget.activeVaultVersionId
        : 'default_vault';
    final snapshots = await _automatedBackupService.listLocalSnapshots(vaultId);
    if (!mounted) return;
    setState(() => _localSnapshots = snapshots);
  }

  Future<void> _setAutomatedBackupEnabled(bool enabled) async {
    setState(() => _automatedBackupEnabled = enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyAutomatedBackupEnabled, enabled);
    } catch (_) {}
    if (enabled) {
      _startMidnightBackupSchedule();
      unawaited(_checkAndRunDueAutomatedBackup());
    } else {
      _midnightBackupTimer?.cancel();
      _midnightBackupTimer = null;
    }
  }

  Future<void> _setCloudBackupWifiOnly(bool wifiOnly) async {
    setState(() => _cloudBackupWifiOnly = wifiOnly);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyCloudBackupWifiOnly, wifiOnly);
    } catch (_) {}
  }

  Future<void> _runAutomatedBackup({bool force = false}) async {
    if (!force && !_automatedBackupEnabled) return;
    final vaultId = widget.activeVaultVersionId.isNotEmpty
        ? widget.activeVaultVersionId
        : 'default_vault';

    // 1. Local backup: keep 2 rolling snapshots daily at midnight
    try {
      String rawContent;
      if (widget.onReadRawVaultContent != null) {
        rawContent = await widget.onReadRawVaultContent!();
      } else {
        rawContent = jsonEncode({
          'vaultId': vaultId,
          'vaultName': _activeVaultName,
          'revision': widget.activeVaultRevision,
          'items': _items,
          'notes': _notes,
          'folders': _folders.map((VaultFolder f) => f.toJson()).toList(),
        });
      }

      if (rawContent.isNotEmpty) {
        final snapshot = await _automatedBackupService.createLocalSnapshot(
          vaultId: vaultId,
          rawVaultContent: rawContent,
          timestamp: DateTime.now(),
        );
        if (snapshot != null) {
          final nowEpoch = DateTime.now().millisecondsSinceEpoch;
          _localBackupLastAtEpochMs = nowEpoch;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(_prefsKeyLocalBackupLastAt, nowEpoch);
          } catch (_) {}
          await _refreshLocalSnapshots();
        }
      }
    } catch (e) {
      debugPrint('Local automated snapshot error: $e');
    }

    // 2. Cloud / paid backup: single backup file daily at midnight
    if (_cloudBackupFeatureAvailable && _cloudBackupEnabled) {
      try {
        await widget.onBackupToCloud();
        final cloudBackup = await _readCloudBackupSummary();
        if (cloudBackup != null) {
          await _applyCloudBackupSummary(
            cloudBackup,
            fallbackLastAt: DateTime.now(),
          );
        }
      } catch (e) {
        debugPrint('Cloud automated backup error: $e');
      }
    }
  }

  Future<void> _handleBackupNow() async {
    if (!_cloudBackupFeatureAvailable) return;
    if (_isBusyOverlayVisible) return;
    if (!await _verifyWebTransferReady()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud backup unavailable.')),
      );
      return;
    }
    await _runWithBusy('Cloud backup in progress...', () async {
      await widget.onBackupToCloud();
      if (!mounted) return;
      final cloudBackup = await _readCloudBackupSummary();
      if (!mounted) return;
      if (cloudBackup != null) {
        await _applyCloudBackupSummary(
          cloudBackup,
          fallbackLastAt: DateTime.now(),
        );
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final revision = widget.activeVaultRevision;
      final versionId = widget.activeVaultVersionId.trim();
      final updatedAt = widget.activeVaultUpdatedAt.trim();
      await _persistCloudBackupDisplayState(
        lastAtEpochMs: now,
        revision: revision,
        versionId: versionId,
        updatedAt: updatedAt,
      );
    });
  }

  String _localSnapshotsSummary() {
    if (_localSnapshots.isEmpty) {
      return '2 rolling snapshots · Kept locally';
    }
    final latest = _localSnapshots.first;
    final stamp =
        '${latest.timestamp.year}-${latest.timestamp.month.toString().padLeft(2, '0')}-${latest.timestamp.day.toString().padLeft(2, '0')} ${latest.timestamp.hour.toString().padLeft(2, '0')}:${latest.timestamp.minute.toString().padLeft(2, '0')}';
    return '${_localSnapshots.length}/2 snapshots · Last: $stamp';
  }

  Future<void> _showLocalSnapshotsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.save_outlined, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Local Snapshots'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nija keeps the 2 latest daily rolling snapshots locally on this device.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (_localSnapshots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No local snapshots yet.\nNext snapshot scheduled at midnight.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _localSnapshots.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final snapshot = _localSnapshots[index];
                        final dateStr =
                            '${snapshot.timestamp.year}-${snapshot.timestamp.month.toString().padLeft(2, '0')}-${snapshot.timestamp.day.toString().padLeft(2, '0')} ${snapshot.timestamp.hour.toString().padLeft(2, '0')}:${snapshot.timestamp.minute.toString().padLeft(2, '0')}';
                        final sizeStr =
                            VaultLimits.formatBytes(snapshot.sizeBytes);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            index == 0
                                ? 'Latest Snapshot ($dateStr)'
                                : 'Previous Snapshot ($dateStr)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text('Size: $sizeStr · Local snapshot'),
                          trailing: TextButton(
                            child: const Text('Restore'),
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              await _confirmRestoreSnapshot(snapshot);
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRestoreSnapshot(LocalVaultSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Snapshot?'),
        content: Text(
          'Restoring this snapshot will replace current changes with data from '
          '${snapshot.timestamp.toLocal()}. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore Snapshot'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final content =
          await _automatedBackupService.readSnapshotContent(snapshot.filePath);
      if (content != null && widget.onRestoreRawVaultContent != null) {
        final success = await widget.onRestoreRawVaultContent!(content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Snapshot restored successfully.'
                    : 'Failed to restore snapshot.',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _showRestoreOptionsDialog(BuildContext context) async {
    if (_localSnapshots.isNotEmpty && _cloudRestoreFeatureAvailable) {
      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.save_outlined),
                title: const Text('Restore from local snapshot'),
                subtitle:
                    Text('${_localSnapshots.length} rolling snapshots available'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showLocalSnapshotsDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('Restore from Google Drive'),
                subtitle: const Text('Download latest cloud backup'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onRestoreFromCloud();
                },
              ),
            ],
          ),
        ),
      );
    } else if (_localSnapshots.isNotEmpty) {
      await _showLocalSnapshotsDialog(context);
    } else {
      await widget.onRestoreFromCloud();
    }
  }

  Future<void> _restoreDebugInternalsPreferences() async {
    if (!_debugInternalsFeatureAvailable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlocked = prefs.getBool(_prefsKeyDebugInternalsUnlocked) ?? false;
      final enabled = prefs.getBool(_prefsKeyDebugInternalsEnabled) ?? false;
      if (!mounted) return;
      setState(() {
        _debugInternalsUnlocked = unlocked;
        _debugInternalsEnabled = unlocked && enabled;
        if (!_debugInternalsEnabled && _tabIndex == 4) {
          _tabIndex = 3;
        }
      });
    } catch (_) {
      // Ignore preference read failures.
    }
  }

  Future<void> _setCloudBackupEnabled(bool enabled) async {
    if (!_cloudBackupFeatureAvailable) return;
    setState(() => _cloudBackupEnabled = enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyCloudBackupEnabled, enabled);
    } catch (_) {}
    if (enabled) {
      unawaited(_refreshCloudBackupSummary());
    }
  }

  Future<void> _setDebugInternalsEnabled(bool enabled) async {
    if (!_debugInternalsFeatureAvailable || !_debugInternalsUnlocked) return;
    setState(() {
      _debugInternalsEnabled = enabled;
      if (!enabled && _tabIndex == 4) {
        _tabIndex = 3;
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyDebugInternalsEnabled, enabled);
    } catch (_) {}
  }

  Future<void> _handleAboutNijaTap(BuildContext context) async {
    if (!_debugInternalsFeatureAvailable) {
      _showAboutNijaSheet(context);
      return;
    }
    if (_debugInternalsUnlocked) {
      _showAboutNijaSheet(context);
      return;
    }

    final nextCount = _aboutNijaTapCount + 1;
    if (nextCount < _debugInternalsUnlockTapCount) {
      setState(() => _aboutNijaTapCount = nextCount);
      if (nextCount < _debugInternalsFeedbackStartTapCount) {
        return;
      }
      final remaining = _debugInternalsUnlockTapCount - nextCount;
      final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('$remaining taps away from debug options.')),
      );
      return;
    }

    setState(() {
      _aboutNijaTapCount = 0;
      _debugInternalsUnlocked = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyDebugInternalsUnlocked, true);
    } catch (_) {}
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Debug options unlocked.')),
    );
  }

  void _showAboutNijaSheet(BuildContext context) {
    _showInfoSheet(
      context,
      title: 'About Nija',
      icon: Icons.info_outline,
      brandHeader: const Center(
        child: NijaBrandLockup(layout: NijaBrandLayout.vertical, markSize: 48),
      ),
      sections: _aboutNijaSections(),
    );
  }


  Future<void> _refreshCloudBackupAccountLabel() async {
    if (!_cloudRestoreFeatureAvailable) return;
    final label = await widget.onReadCloudBackupAccount();
    if (!mounted) return;
    final hasAccount = label != null && label.isNotEmpty;
    setState(
      () => _cloudBackupAccountLabel = hasAccount ? label : 'Not connected',
    );
    if (hasAccount && _cloudBackupEnabled) {
      unawaited(_refreshCloudBackupSummary());
    }
  }

  Future<void> _handleChangeCloudBackupAccount() async {
    if (!_cloudRestoreFeatureAvailable) return;
    final ok = await widget.onChangeCloudBackupAccount();
    if (!mounted) return;
    if (ok) {
      await _refreshCloudBackupAccountLabel();
      await _refreshCloudBackupSummary();
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

  Future<CloudVaultBackupFile?> _readCloudBackupSummary() async {
    final readSummary = widget.onReadCloudBackupSummary;
    if (readSummary == null) return null;
    try {
      return await readSummary();
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshCloudBackupSummary() async {
    if (!_cloudBackupFeatureAvailable || !_cloudBackupEnabled) return;
    if (_cloudBackupSummaryRefreshInProgress) return;
    if (mounted) {
      setState(() => _cloudBackupSummaryRefreshInProgress = true);
    }
    final backup = await _readCloudBackupSummary();
    if (!mounted) return;
    if (backup != null) {
      await _applyCloudBackupSummary(backup);
    }
    if (!mounted) return;
    setState(() => _cloudBackupSummaryRefreshInProgress = false);
  }

  Future<void> _applyCloudBackupSummary(
    CloudVaultBackupFile backup, {
    DateTime? fallbackLastAt,
  }) async {
    final lastAt =
        backup.modifiedAt ??
        DateTime.tryParse(backup.updatedAt.trim())?.toLocal() ??
        fallbackLastAt;
    await _persistCloudBackupDisplayState(
      lastAtEpochMs: lastAt?.millisecondsSinceEpoch ?? 0,
      revision: backup.revision,
      versionId: backup.versionId,
      updatedAt: backup.updatedAt,
    );
  }

  Future<void> _persistCloudBackupDisplayState({
    required int lastAtEpochMs,
    required int revision,
    required String versionId,
    required String updatedAt,
  }) async {
    if (!mounted) return;
    setState(() {
      _cloudBackupLastAtEpochMs = lastAtEpochMs;
      _cloudBackupRevision = revision;
      _cloudBackupVersionId = versionId.trim();
      _cloudBackupUpdatedAt = updatedAt.trim();
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyCloudBackupLastAt, lastAtEpochMs);
      await prefs.setInt(_prefsKeyCloudBackupRevision, revision);
      await prefs.setString(_prefsKeyCloudBackupVersionId, versionId.trim());
      await prefs.setString(_prefsKeyCloudBackupUpdatedAt, updatedAt.trim());
    } catch (_) {}
  }

  String _cloudBackupTitle() {
    if (kIsWeb) return 'Backup to Google Drive';
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

  Widget _cloudBackupExpansionTrailing(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedRotation(
      key: const ValueKey('settings-cloud-backup-expand-arrow'),
      turns: _cloudBackupEnabled ? 0.25 : 0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),
    );
  }

  String _formatBytes(int bytes) {
    return VaultLimits.formatBytes(bytes);
  }

  String _vaultVersionSummary({
    required int revision,
    required String versionId,
  }) {
    final shortVersionId = _shortVaultVersionId(versionId);
    if (revision <= 0 && shortVersionId == 'unknown') return 'Unknown';
    if (revision <= 0) return shortVersionId;
    if (shortVersionId == 'unknown') return 'r$revision';
    return 'r$revision - $shortVersionId';
  }

  String _shortVaultVersionId(String versionId) {
    final trimmed = versionId.trim();
    if (trimmed.isEmpty) return 'unknown';
    if (trimmed.length <= 8) return trimmed;
    return trimmed.substring(0, 8);
  }

  String _formatCloudBackupLastAt() {
    if (_cloudBackupSummaryRefreshInProgress &&
        _cloudBackupLastAtEpochMs <= 0) {
      return 'Checking cloud backup...';
    }
    if (_cloudBackupLastAtEpochMs <= 0) return 'Never';
    return _formatLocalDateTime(
      DateTime.fromMillisecondsSinceEpoch(_cloudBackupLastAtEpochMs),
    );
  }

  String _formatVaultIsoTimestamp(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Unknown';
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return trimmed;
    return _formatLocalDateTime(parsed.toLocal());
  }

  String _formatLocalDateTime(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  int get _effectiveVaultSizeBytes =>
      widget.vaultSizeBytes + _storedDocumentBytesThisSession;

  int get _effectiveMaxVaultBytes {
    return VaultLimits.maxVaultBytesFor(
      currentVaultSizeBytes: widget.vaultSizeBytes,
      expandedStorageEntitled: widget.expandedVaultStorageEntitled,
    );
  }

  bool _canStoreDocumentBytes(int bytes) {
    if (bytes > VaultLimits.maxDocumentBytes) {
      _showVaultLimitMessage(
        'Document must be ${_formatBytes(VaultLimits.maxDocumentBytes)} or smaller.',
      );
      return false;
    }
    final projected = _effectiveVaultSizeBytes + bytes;
    final maxVaultBytes = _effectiveMaxVaultBytes;
    if (projected > maxVaultBytes) {
      _showVaultLimitMessage(
        'Not enough vault space. Limit is ${_formatBytes(maxVaultBytes)}.',
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
    final shouldDelete = await showVaultConfirmSheet(
      context: context,
      title: 'Move to Trash?',
      message:
          '${_selectedAllItemsKeys.length} items will be moved to trash.\nThis action can be undone.',
      confirmLabel: 'Move to Trash',
      destructive: true,
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
    final selected = await showVaultChoiceMenu<String>(
      context: context,
      options: [
        VaultMenuOption(
          value: 'share_encrypted',
          leading: const Icon(Icons.enhanced_encryption_outlined),
          title: AppStrings.shareEncryptedFile,
        ),
        VaultMenuOption(
          value: 'export_encrypted',
          leading: const Icon(Icons.file_download_outlined),
          title: AppStrings.exportEncryptedFile,
        ),
      ],
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
    final selected = await showVaultChoiceMenu<String>(
      context: context,
      options: [
        VaultMenuOption(
          key: const ValueKey('note-action-pin'),
          value: 'pin',
          leading: Icon(pinned ? Icons.star_outline : Icons.star),
          title: pinned ? AppStrings.unpin : AppStrings.pin,
        ),
        VaultMenuOption(
          key: const ValueKey('note-action-delete'),
          value: 'delete',
          leading: const Icon(Icons.delete_outline),
          title: AppStrings.delete,
        ),
        VaultMenuOption(
          key: const ValueKey('note-action-share'),
          value: 'share_plain',
          leading: const Icon(Icons.share_outlined),
          title: AppStrings.sharePlainText,
        ),
        VaultMenuOption(
          key: const ValueKey('note-action-share-encrypted'),
          value: 'share_encrypted',
          leading: const Icon(Icons.enhanced_encryption_outlined),
          title: AppStrings.shareEncryptedFile,
        ),
        VaultMenuOption(
          key: const ValueKey('note-action-export-encrypted'),
          value: 'export_encrypted',
          leading: const Icon(Icons.file_download_outlined),
          title: AppStrings.exportEncryptedFile,
        ),
      ],
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
    final selected = await showVaultChoiceMenu<String>(
      context: context,
      options: [
        VaultMenuOption(
          key: const ValueKey('item-action-pin'),
          value: 'pin',
          leading: Icon(pinned ? Icons.star_outline : Icons.star),
          title: pinned ? AppStrings.unpin : AppStrings.pin,
        ),
        VaultMenuOption(
          key: const ValueKey('item-action-delete'),
          value: 'delete',
          leading: const Icon(Icons.delete_outline),
          title: AppStrings.delete,
        ),
        VaultMenuOption(
          key: const ValueKey('item-action-share'),
          value: 'share_plain',
          leading: const Icon(Icons.share_outlined),
          title: AppStrings.sharePlainText,
        ),
        VaultMenuOption(
          key: const ValueKey('item-action-share-encrypted'),
          value: 'share_encrypted',
          leading: const Icon(Icons.enhanced_encryption_outlined),
          title: AppStrings.shareEncryptedFile,
        ),
        VaultMenuOption(
          key: const ValueKey('item-action-export-encrypted'),
          value: 'export_encrypted',
          leading: const Icon(Icons.file_download_outlined),
          title: AppStrings.exportEncryptedFile,
        ),
      ],
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
    final selected = await showVaultChoiceMenu<String>(
      context: context,
      options: [
        VaultMenuOption(
          key: const ValueKey('document-action-open'),
          value: 'open',
          leading: const Icon(Icons.open_in_new_outlined),
          title: 'Open document',
        ),
        VaultMenuOption(
          key: const ValueKey('document-action-pin'),
          value: 'pin',
          leading: Icon(pinned ? Icons.star_outline : Icons.star),
          title: pinned ? AppStrings.unpin : AppStrings.pin,
        ),
        VaultMenuOption(
          key: const ValueKey('document-action-share-encrypted'),
          value: 'share_encrypted',
          leading: const Icon(Icons.enhanced_encryption_outlined),
          title: 'Share encrypted file',
        ),
        VaultMenuOption(
          key: const ValueKey('document-action-export-encrypted'),
          value: 'export_encrypted',
          leading: const Icon(Icons.file_download_outlined),
          title: 'Export encrypted file',
        ),
        VaultMenuOption(
          key: const ValueKey('document-action-save-copy'),
          value: 'save_copy',
          leading: const Icon(Icons.download_for_offline_outlined),
          title: 'Save copy',
        ),
        VaultMenuOption(
          key: const ValueKey('document-action-delete'),
          value: 'delete',
          leading: const Icon(Icons.delete_outline),
          title: AppStrings.delete,
        ),
      ],
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
    if (selected == 'share_encrypted' ||
        selected == 'export_encrypted' ||
        selected == 'save_copy') {
      try {
        final bytes = await _readDocumentBytesForAction(item);
        if (selected == 'share_encrypted') {
          await _shareEncryptedDocument(item, bytes);
        } else if (selected == 'export_encrypted') {
          await _exportEncryptedDocument(item, bytes);
        } else {
          final saved = await _saveDocumentCopy(item, bytes);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                saved ? 'Document copy saved.' : 'Document save cancelled.',
              ),
            ),
          );
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
    if (!await _verifyWebTransferReady()) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.encryptedExportFailed)));
      return;
    }
    if (!mounted) return;
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
    if (_blockExploreDemoWrite()) return;
    if (_importingEncryptedSecret) return;
    try {
      final imported = await _secretSharePortability.importEncryptedFile();
      if (imported == null || !mounted) return;
      setState(() {
        _importingEncryptedSecret = true;
        _importBusyMessage = 'Waiting for import password...';
      });
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

class _WideAllItemsIndex extends StatelessWidget {
  const _WideAllItemsIndex({
    required this.rows,
    required this.adapters,
    required this.selectionMode,
    required this.selectedKeys,
    required this.keyForRow,
    required this.onTap,
    this.onLongPress,
    required this.onMoreTap,
  });

  final List<Map<String, dynamic>> rows;
  final List<VaultListEntryAdapter> adapters;
  final bool selectionMode;
  final Set<String> selectedKeys;
  final String Function(Map<String, dynamic> row) keyForRow;
  final ValueChanged<Map<String, dynamic>> onTap;
  final ValueChanged<Map<String, dynamic>>? onLongPress;
  final ValueChanged<Map<String, dynamic>> onMoreTap;

  VaultListEntry _entryFor(Map<String, dynamic> row) {
    return adapters.firstWhere((adapter) => adapter.canAdapt(row)).adapt(row);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('wide-all-items-index'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const _WideAllItemsHeader(),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: colorScheme.outlineVariant),
              itemBuilder: (context, index) {
                final row = rows[index];
                final entry = _entryFor(row);
                final selected = selectedKeys.contains(keyForRow(row));
                final folder = entry.entry['folder']?.toString().trim() ?? '';
                return Material(
                  color: selected
                      ? colorScheme.primaryContainer.withValues(alpha: 0.42)
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(row),
                    onLongPress: onLongPress == null
                        ? null
                        : () => onLongPress!(row),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: selectionMode
                                ? Checkbox(
                                    value: selected,
                                    onChanged: (_) => onTap(row),
                                  )
                                : Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color:
                                          (entry.color ?? colorScheme.primary)
                                              .withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Icon(
                                      entry.icon ?? Icons.inventory_2_outlined,
                                      size: 18,
                                      color: entry.color ?? colorScheme.primary,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
                            child: _WideItemText(
                              title: entry.title,
                              subtitle: entry.subtitle,
                              pinned: entry.pinned,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _WideItemCell(value: entry.type),
                          ),
                          Expanded(
                            flex: 2,
                            child: _WideItemCell(
                              value: folder.isEmpty ? 'No folder' : folder,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _WideItemCell(value: entry.updated),
                          ),
                          SizedBox(
                            width: 36,
                            child: selectionMode
                                ? const Icon(Icons.chevron_right)
                                : IconButton(
                                    key: ValueKey<String>(
                                      'vault-entry-actions-${keyForRow(row)}',
                                    ),
                                    tooltip: 'Item actions',
                                    onPressed: () => onMoreTap(row),
                                    icon: const Icon(Icons.more_vert),
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
}

class _WideAllItemsHeader extends StatelessWidget {
  const _WideAllItemsHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Text label(String value) => Text(
      value,
      style: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
    return Container(
      height: 42,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const SizedBox(width: 46),
          Expanded(flex: 4, child: label('NAME')),
          Expanded(flex: 2, child: label('TYPE')),
          Expanded(flex: 2, child: label('FOLDER')),
          Expanded(flex: 2, child: label('UPDATED')),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _WideItemText extends StatelessWidget {
  const _WideItemText({
    required this.title,
    required this.subtitle,
    required this.pinned,
  });

  final String title;
  final String subtitle;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (pinned) ...[
              const SizedBox(width: 4),
              Icon(Icons.star, size: 14, color: colorScheme.primary),
            ],
          ],
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
      ],
    );
  }
}

class _WideItemCell extends StatelessWidget {
  const _WideItemCell({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12,
      ),
    );
  }
}

class _VaultDesktopHeader extends StatelessWidget {
  const _VaultDesktopHeader({
    required this.title,
    this.themeMode,
    this.onThemeModeChanged,
  });

  final String title;
  final ThemeMode? themeMode;
  final VoidCallback? onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/branding/nija_mark.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'NIJA VAULT',
                    style: DashboardTypography.workspaceBrand(
                      colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: DashboardTypography.workspaceTitle(
                      colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (onThemeModeChanged != null)
              IconButton(
                tooltip: themeMode == ThemeMode.dark
                    ? 'Switch to light theme'
                    : 'Switch to dark theme',
                onPressed: onThemeModeChanged,
                icon: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopPanel extends StatelessWidget {
  const _DesktopPanel({
    required this.title,
    this.trailing,
    required this.child,
  });

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: DashboardTypography.panelTitle(
                        colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _QuickActionTileData {
  const _QuickActionTileData({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.actions});

  final List<_QuickActionTileData> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 72,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return Material(
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: action.onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, size: 22, color: colorScheme.onSurface),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  style: DashboardTypography.quickActionLabel(
                    colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WideDashboardRecentList extends StatelessWidget {
  const _WideDashboardRecentList({
    required this.recentItems,
    required this.adapters,
    required this.keyForRow,
    required this.onOpenRow,
    required this.onRowActions,
  });

  final List<Map<String, dynamic>> recentItems;
  final List<VaultListEntryAdapter> adapters;
  final String Function(Map<String, dynamic> row) keyForRow;
  final ValueChanged<Map<String, dynamic>> onOpenRow;
  final ValueChanged<Map<String, dynamic>> onRowActions;

  VaultListEntry _entryFor(Map<String, dynamic> row) {
    return adapters.firstWhere((adapter) => adapter.canAdapt(row)).adapt(row);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (recentItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          'No recent items yet.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < recentItems.length; index++) ...[
          if (index > 0) Divider(height: 1, color: colorScheme.outlineVariant),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onOpenRow(recentItems[index]),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.55,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _vaultDashboardTypeCode(
                          _entryFor(recentItems[index]).type,
                        ),
                        style: DashboardTypography.typeCode(
                          colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _entryFor(recentItems[index]).title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DashboardTypography.recentTitle(
                              colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _entryFor(recentItems[index]).subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DashboardTypography.recentSubtitle(
                              colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: Text(
                        _entryFor(recentItems[index]).updated,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: DashboardTypography.recentTimestamp(
                          colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Item actions',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onRowActions(recentItems[index]),
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VaultWideContentFrame extends StatelessWidget {
  const _VaultWideContentFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: child,
      ),
    );
  }
}

class _VaultSideNavigation extends StatelessWidget {
  const _VaultSideNavigation({
    required this.selectedIndex,
    required this.debugTabVisible,
    required this.activeVaultName,
    required this.itemCount,
    required this.vaultMetaLabel,
    required this.onLockNow,
    this.onSwitchVault,
    this.onThemeToggle,
    this.themeMode,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final bool debugTabVisible;
  final String activeVaultName;
  final int itemCount;
  final String vaultMetaLabel;
  final VoidCallback onLockNow;
  final VoidCallback? onSwitchVault;
  final VoidCallback? onThemeToggle;
  final ThemeMode? themeMode;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final largeDesktop = viewportWidth >= 1100;
    final compactTablet = viewportWidth < 760;
    final navWidth = largeDesktop
        ? 320.0
        : compactTablet
        ? 240.0
        : 296.0;
    final railWidth = largeDesktop
        ? 82.0
        : compactTablet
        ? 64.0
        : 76.0;
    final destinations = <_VaultNavDestination>[
      _VaultNavDestination(
        code: 'HM',
        label: AppStrings.tabVault,
        icon: Icons.shield_outlined,
        selectedIcon: Icons.shield,
        index: 0,
      ),
      _VaultNavDestination(
        code: 'AI',
        label: AppStrings.tabTypes,
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view,
        index: 1,
      ),
      _VaultNavDestination(
        code: 'FD',
        label: AppStrings.tabFolders,
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder,
        index: 2,
      ),
      _VaultNavDestination(
        code: 'FV',
        label: AppStrings.tabNotes,
        icon: Icons.star_outline,
        selectedIcon: Icons.star,
        index: 3,
      ),
      _VaultNavDestination(
        code: 'ST',
        label: AppStrings.tabSettings,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        index: 4,
      ),
      if (debugTabVisible)
        const _VaultNavDestination(
          code: 'DG',
          label: 'Debug',
          icon: Icons.bug_report_outlined,
          selectedIcon: Icons.bug_report,
          index: 5,
        ),
    ];

    return Container(
      width: navWidth,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              width: railWidth,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 22),
                  Image.asset(
                    'assets/branding/nija_mark.png',
                    width: 34,
                    height: 34,
                  ),
                  const Spacer(),
                  RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      'private archive',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (onThemeToggle != null)
                    IconButton(
                      tooltip: themeMode == ThemeMode.dark
                          ? 'Switch to light theme'
                          : 'Switch to dark theme',
                      onPressed: onThemeToggle,
                      icon: Icon(
                        themeMode == ThemeMode.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        color: colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                    )
                  else
                    Icon(
                      Icons.verified_user_outlined,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  const SizedBox(height: 22),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active vault',
                      style: DashboardTypography.microLabel(
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activeVaultName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardTypography.sidebarVaultName(
                        colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vaultMetaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardTypography.sidebarVaultMeta(
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Divider(color: colorScheme.outlineVariant),
                    const SizedBox(height: 10),
                    ...destinations.map(
                      (destination) => _VaultSidebarButton(
                        key: ValueKey('sidebar-nav-${destination.code}'),
                        destination: destination,
                        selected: selectedIndex == destination.index,
                        onTap: () => onDestinationSelected(destination.index),
                      ),
                    ),
                    const Spacer(),
                    Divider(color: colorScheme.outlineVariant),
                    if (onSwitchVault != null)
                      _VaultSidebarButton(
                        destination: const _VaultNavDestination(
                          code: 'SV',
                          label: 'Switch vault',
                          icon: Icons.switch_access_shortcut_outlined,
                          selectedIcon: Icons.switch_access_shortcut,
                          index: -1,
                        ),
                        selected: false,
                        onTap: onSwitchVault!,
                      ),
                    _VaultSidebarButton(
                      destination: const _VaultNavDestination(
                        code: 'LK',
                        label: 'Lock vault',
                        icon: Icons.lock_outline,
                        selectedIcon: Icons.lock,
                        index: -1,
                      ),
                      selected: false,
                      onTap: onLockNow,
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

class _VaultNavDestination {
  const _VaultNavDestination({
    required this.code,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.index,
  });

  final String code;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int index;
}

class _VaultSidebarButton extends StatelessWidget {
  const _VaultSidebarButton({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _VaultNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected
            ? colorScheme.surfaceContainerHighest
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? colorScheme.outlineVariant : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    destination.code,
                    style: DashboardTypography.navCode(
                      selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      selected: selected,
                    ),
                  ),
                ),
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 18,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    destination.label,
                    style: DashboardTypography.navLabel(
                      selected
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                      selected: selected,
                    ),
                  ),
                ),
              ],
            ),
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

class _DashboardData {
  const _DashboardData({
    required this.recentItems,
    required this.dashboardTypes,
    required this.typeCounts,
    required this.totalCount,
    required this.folderCount,
    required this.isDemo,
    required this.canShowDemoPreview,
    required this.isExploreSession,
  });

  final List<Map<String, dynamic>> recentItems;
  final List<MapEntry<String, int>> dashboardTypes;
  final Map<String, int> typeCounts;
  final int totalCount;
  final int folderCount;
  final bool isDemo;
  final bool canShowDemoPreview;
  final bool isExploreSession;
}

class _DashboardRecentCandidate {
  const _DashboardRecentCandidate({
    required this.kind,
    required this.entry,
    required this.activityAt,
  });

  final String kind;
  final Map<String, dynamic> entry;
  final DateTime activityAt;
}
