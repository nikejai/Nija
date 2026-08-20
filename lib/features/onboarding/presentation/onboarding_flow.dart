import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../../application/services/default_vault_service.dart';
import '../../../application/services/vault_service.dart';
import '../../../application/services/vault_merge_helper.dart';
import '../../../app/theme/entry_typography.dart';
import '../../../core/config/guardian_profiles.dart';
import '../../../core/config/recovery_phrase_dictionary.dart';
import '../../../core/config/recovery_phrase_generator.dart';
import '../../../core/config/vault_limits.dart';
import '../../../core/entitlements/entitlement_state.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/security/encrypted_share_codec.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/security/biometric_credential_store.dart';
import '../../../core/security/biometric_enrollment_store.dart';
import '../../../core/security/pin_credential_store.dart';
import '../../../core/security/web_page_lifecycle.dart';
import '../../../domain/models/vault_reference.dart';
import '../../../domain/models/vault_payload.dart';
import '../../../domain/models/vault_transfer_result.dart';
import '../../../infrastructure/adapters/file_vault_storage_adapter.dart';
import '../../../infrastructure/adapters/private_vault_store.dart';
import '../../../infrastructure/adapters/secret_share_portability.dart';
import '../../../infrastructure/adapters/secret_share_portability_base.dart';
import '../../../infrastructure/adapters/secret_share_model.dart';
import '../../../infrastructure/adapters/secret_intent_bridge.dart';
import '../../../infrastructure/adapters/secure_crypto_adapter.dart';
import '../../../infrastructure/adapters/google_drive_vault_portability.dart';
import '../../../infrastructure/adapters/vault_portability.dart';
import '../../../infrastructure/adapters/vault_portability_base.dart';
import '../../../infrastructure/adapters/vault_portability_model.dart';
import '../../../infrastructure/adapters/vault_reference_cache.dart';
import '../../../infrastructure/adapters/web_vault_storage_adapter.dart';
import '../../vault/application/vault_home_demo_data.dart';
import '../../vault/presentation/vault_app_shell.dart';
import '../../vault/presentation/widgets/google_drive_web_sign_in_dialog.dart';
import '../../vault/presentation/widgets/web_biometric_dialog.dart';
import 'first_install_walkthrough_screen.dart';
import 'onboarding_scaffold.dart';
import 'welcome_screen.dart';

enum OnboardingStep {
  walkthrough,
  welcome,
  selectVault,
  setup,
  recovery,
  created,
  unlock,
  app,
}

enum _CloudMergeOutcome { noMergeNeeded, merged, cancelled }

enum _VaultPickerAction { importFromDevice }

enum _VaultSelectionMode { known, cloudBackup }

class _ImportVaultCredentialChoice {
  const _ImportVaultCredentialChoice.password(this.password)
    : recoverWithPhrase = false;

  const _ImportVaultCredentialChoice.recoverWithPhrase()
    : password = '',
      recoverWithPhrase = true;

  final String password;
  final bool recoverWithPhrase;
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.languageMode,
    required this.onLanguageModeChanged,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
    this.vaultService,
    this.vaultFilePath,
    this.autoLockDelay = const Duration(minutes: 5),
    this.autoLockSeconds = 300,
    this.onAutoLockSecondsChanged,
    this.biometricAuthService,
    this.biometricCredentialStore,
    this.biometricEnrollmentStore,
    this.firstInstallWalkthroughCompletedOverride,
    this.entitlementState = const EntitlementState.free(),
    this.canPurchaseExpandedVaultStorage = false,
    this.purchaseInProgress = false,
    this.entitlementErrorMessage,
    this.onRefreshEntitlements,
    this.onPurchaseExpandedVaultStorage,
  });

  final String languageMode;
  final ValueChanged<String> onLanguageModeChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final VaultService? vaultService;
  final String? vaultFilePath;
  final Duration autoLockDelay;
  final int autoLockSeconds;
  final ValueChanged<int>? onAutoLockSecondsChanged;
  final BiometricAuthService? biometricAuthService;
  final BiometricCredentialStore? biometricCredentialStore;
  final BiometricEnrollmentStore? biometricEnrollmentStore;
  final bool? firstInstallWalkthroughCompletedOverride;
  final EntitlementState entitlementState;
  final bool canPurchaseExpandedVaultStorage;
  final bool purchaseInProgress;
  final String? entitlementErrorMessage;
  final Future<void> Function()? onRefreshEntitlements;
  final Future<bool> Function()? onPurchaseExpandedVaultStorage;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with WidgetsBindingObserver {
  static const _vaultOpTimeout = Duration(seconds: 20);
  static const _unlockBackExitWindow = Duration(seconds: 2);
  static const _prefsDeviceIdKey = 'nija_device_id_v1';
  static const _prefsFirstInstallWalkthroughCompletedKey =
      'nija_first_install_walkthrough_completed_v1';
  static const _defaultVaultName = 'Nija Vault';
  OnboardingStep _step = OnboardingStep.walkthrough;
  OnboardingStep _selectVaultReturnStep = OnboardingStep.welcome;
  _VaultSelectionMode _vaultSelectionMode = _VaultSelectionMode.known;
  List<VaultReference> _cloudVaultReferences = <VaultReference>[];
  Map<String, CloudVaultBackupFile> _cloudBackupsByStorageId =
      <String, CloudVaultBackupFile>{};
  String _cloudVaultSelectionHeading = AppStrings.importVaultFromCloud;
  Completer<CloudVaultBackupFile?>? _cloudBackupPickerCompleter;
  OnboardingStep? _cloudPickerOuterReturnStep;
  bool _stepTransitionForward = true;
  GuardianProfile _selectedGuardian = GuardianProfiles.owl;
  GuardianProfile _activeGuardianProfile = GuardianProfiles.owl;
  final _passwordController = TextEditingController();
  final _vaultNameController = TextEditingController();
  List<String> _recoveryWords = RecoveryPhraseGenerator.generate();
  bool _biometricEnabled = false;
  bool _biometricPromptShown = false;
  bool _biometricAvailable = false;
  bool _pinEnabled = false;
  String _biometricUnlockLabel = AppStrings.useBiometricUnlock;
  IconData _biometricUnlockIcon = Icons.fingerprint;
  Completer<_ImportVaultCredentialChoice?>? _importCredentialCompleter;
  bool _importCredentialAllowRecovery = true;
  Completer<bool>? _actionUnlockCompleter;
  String? _sessionMasterPassword;
  bool _isBusy = false;
  double _busyProgress = 0;
  String _busyMessage = '';
  bool _vaultCreatedInSession = false;
  bool _isExploreDemoSession = false;
  List<Map<String, dynamic>> _vaultItems = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _vaultNotes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _customTypeDefinitions = <Map<String, dynamic>>[];
  Future<void> _persistVaultChain = Future<void>.value();
  Timer? _busyWatchdog;
  Timer? _backgroundLockTimer;
  Timer? _inactivityLockTimer;
  int _busyRunId = 0;
  bool _lifecycleLockSuppressed = false;
  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;
  final _vaultReferenceCache = VaultReferenceCache();
  final VaultPortabilityAdapter _vaultPortability =
      VaultPortabilityAdapterImpl();
  final SecretSharePortabilityAdapter _secretSharePortability =
      SecretSharePortabilityAdapterImpl();
  final _secretIntentBridge = SecretIntentBridge();
  final _encryptedShareCodec = EncryptedShareCodec();
  final _vaultMergeHelper = const VaultMergeHelper();
  late final BiometricAuthService _biometricAuthService;
  late final BiometricCredentialStore _biometricCredentialStore;
  late final BiometricEnrollmentStore _biometricEnrollmentStore;
  final _pinCredentialStore = PinCredentialStore();
  List<VaultReference> _knownVaults = const <VaultReference>[];
  bool _enableVaultReferenceCache = true;
  bool _storageReady = false;
  late final VaultService _vaultService;
  late String _vaultFilePath;
  String _activeVaultName = 'vault.nija';
  int _activeVaultSizeBytes = 0;
  int _activeVaultRevision = 0;
  String _activeVaultVersionId = '';
  String _activeVaultUpdatedAt = '';
  String _draftVaultId = '';
  final Random _idRandom = Random.secure();
  String _deviceId = '';
  String _deviceLabel = 'unknown';
  DateTime? _lastUnlockBackPressAt;
  SharedTextIntent? _pendingSharedTextIntent;
  bool _setupOpenedFromUnlock = false;
  bool _consumingPendingSecretIntent = false;
  bool _consumingPendingSharedTextIntent = false;
  bool _handlingRootPop = false;

  @override
  void initState() {
    super.initState();
    _biometricAuthService =
        widget.biometricAuthService ?? BiometricAuthService();
    _biometricCredentialStore =
        widget.biometricCredentialStore ?? BiometricCredentialStore();
    _biometricEnrollmentStore =
        widget.biometricEnrollmentStore ?? BiometricEnrollmentStore();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      registerWebPageHiddenListener(_handleWebPageHidden);
    }
    _prepareVaultDraft();
    unawaited(_initializeDeviceMetadata());
    _initializeFirstInstallWalkthroughState();
    if (widget.vaultService != null) {
      _enableVaultReferenceCache = false;
      _vaultService = widget.vaultService!;
      _vaultFilePath = widget.vaultFilePath ?? 'nija_vault.nija';
      _activeVaultName = _displayNameForVault(_vaultFilePath);
      _storageReady = true;
      unawaited(_consumePendingSecretIntent());
      unawaited(_consumePendingSharedTextIntent());
      return;
    }

    if (kIsWeb) {
      _vaultService = DefaultVaultService(
        storageAdapter: const WebVaultStorageAdapter(),
        cryptoAdapter: SecureCryptoAdapter(),
      );
      _vaultFilePath = widget.vaultFilePath ?? 'web_vault.nija';
      _activeVaultName = _displayNameForVault(_vaultFilePath);
      _storageReady = true;
      _scheduleKnownVaultDiscovery();
      unawaited(_consumePendingSecretIntent());
      unawaited(_consumePendingSharedTextIntent());
      return;
    }

    _vaultFilePath = widget.vaultFilePath ?? '';
    _activeVaultName = _displayNameForVault(_vaultFilePath);
    unawaited(_initializeLocalVaultPath());
  }

  @override
  void dispose() {
    if (kIsWeb) {
      registerWebPageHiddenListener(null);
    }
    WidgetsBinding.instance.removeObserver(this);
    _busyWatchdog?.cancel();
    _backgroundLockTimer?.cancel();
    _inactivityLockTimer?.cancel();
    _passwordController.dispose();
    _vaultNameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _backgroundLockTimer?.cancel();
      _scheduleInactivityLockIfNeeded();
      unawaited(_consumePendingSecretIntent());
      unawaited(_consumePendingSharedTextIntent());
      return;
    }
    if (state == AppLifecycleState.detached && _step == OnboardingStep.app) {
      if (_shouldSuppressLifecycleLock) return;
      _backgroundLockTimer?.cancel();
      _inactivityLockTimer?.cancel();
      _lockVaultSession();
      return;
    }
    if (state == AppLifecycleState.paused && _step == OnboardingStep.app) {
      _scheduleBackgroundLockIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = switch (_step) {
      OnboardingStep.walkthrough => FirstInstallWalkthroughScreen(
        onSkip: _completeFirstInstallWalkthrough,
        onFinish: _completeFirstInstallWalkthrough,
      ),
      OnboardingStep.welcome => WelcomeScreen(
        onCreateVault: () {
          _prepareVaultDraft();
          setState(() {
            _setupOpenedFromUnlock = false;
            _step = OnboardingStep.setup;
          });
        },
        onSelectKnownVault: _selectKnownVault,
        onOpenVaultFile: () =>
            unawaited(_importVaultFromLocal(continueToUnlock: true)),
        onImportVault: () =>
            unawaited(_importVaultFromLocal(continueToUnlock: true)),
        onImportVaultFromCloud: () =>
            unawaited(_importVaultFromCloud(continueToUnlock: true)),
        onExploreDemo: _enterExploreDemoSession,
        recentVaults: _knownVaults,
        onRecentVaultSelected: _handleKnownVaultSelected,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
      OnboardingStep.setup => SetupScreen(
        selectedGuardian: _selectedGuardian,
        onSelectGuardian: (guardian) =>
            setState(() => _selectedGuardian = guardian),
        vaultNameController: _vaultNameController,
        defaultVaultId: _draftVaultId,
        passwordController: _passwordController,
        onNext: _createVaultAndProceed,
      ),
      OnboardingStep.recovery => RecoveryScreen(
        words: _recoveryWords,
        onNext: () => setState(() => _step = OnboardingStep.created),
      ),
      OnboardingStep.created => VaultCreatedScreen(
        onContinue: () => unawaited(_presentUnlockStep()),
      ),
      OnboardingStep.selectVault => KnownVaultSelectionScreen(
        knownVaults: _vaultSelectionMode == _VaultSelectionMode.known
            ? _knownVaults
            : _cloudVaultReferences,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        onBack: _goBackFromSelectVault,
        onVaultSelected: _vaultSelectionMode == _VaultSelectionMode.known
            ? _handleKnownVaultSelected
            : _handleCloudVaultSelected,
        onImportFromDevice: _vaultSelectionMode == _VaultSelectionMode.known
            ? () async {
                final picked = await _pickVaultFileForUnlock();
                if (picked == null || !mounted) return;
                _handleKnownVaultSelected(picked);
              }
            : null,
        onImportFromCloud: _vaultSelectionMode == _VaultSelectionMode.known
            ? () => _importVaultFromCloud(
                continueToUnlock: true,
                returnOnCancel: _selectVaultReturnStep,
              )
            : null,
        sectionLabel: _vaultSelectionMode == _VaultSelectionMode.known
            ? null
            : AppStrings.cloudVaultsSection,
        heading: _vaultSelectionMode == _VaultSelectionMode.known
            ? null
            : _cloudVaultSelectionHeading,
        description: _vaultSelectionMode == _VaultSelectionMode.known
            ? null
            : AppStrings.cloudVaultsDescription,
        showImportFromDevice: _vaultSelectionMode == _VaultSelectionMode.known,
        useCloudBackupCards:
            _vaultSelectionMode == _VaultSelectionMode.cloudBackup,
      ),
      OnboardingStep.unlock => UnlockScreen(
        vaultName: _activeVaultName,
        guardianProfile: _activeGuardianProfile,
        passwordController: _passwordController,
        pinEnabled: _pinEnabled,
        biometricEnabled: _biometricEnabled,
        biometricUnlockLabel: _biometricUnlockLabel,
        biometricUnlockIcon: _biometricUnlockIcon,
        showRecoveryAction:
            _importCredentialCompleter == null ||
            _importCredentialAllowRecovery,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        onBack: _goBackFromUnlock,
        onUnlock: _unlockWithPassword,
        onPinUnlock: _unlockWithPin,
        onBiometricUnlock: _unlockWithBiometric,
        onRecover: _unlockWithRecoveryPhrase,
        onSelectDifferentVault: _openExistingVault,
        onOpenEncryptedSecret: _openEncryptedSecretFromUnlock,
        onCreateVault: _openCreateVaultFromUnlock,
      ),
      OnboardingStep.app => VaultAppShell(
        activeVaultName: _activeVaultName,
        vaultSizeBytes: _activeVaultSizeBytes,
        activeVaultRevision: _activeVaultRevision,
        activeVaultVersionId: _activeVaultVersionId,
        activeVaultUpdatedAt: _activeVaultUpdatedAt,
        recoveryWords: _recoveryWords,
        initialItems: _vaultItems,
        initialNotes: _vaultNotes,
        initialCustomTypeDefinitions: _customTypeDefinitions,
        languageMode: widget.languageMode,
        onLanguageModeChanged: widget.onLanguageModeChanged,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        autoLockSeconds: widget.autoLockSeconds,
        onAutoLockSecondsChanged: widget.onAutoLockSecondsChanged,
        biometricEnabled: _isExploreDemoSession ? false : _biometricEnabled,
        biometricAvailable: _isExploreDemoSession ? false : _biometricAvailable,
        pinEnabled: _isExploreDemoSession ? false : _pinEnabled,
        onPinChanged: _isExploreDemoSession ? (_) {} : _onPinPreferenceChanged,
        onBiometricChanged: _isExploreDemoSession
            ? (_) {}
            : _onBiometricPreferenceChanged,
        onPersistVaultData: _isExploreDemoSession
            ? ({
                required items,
                required notes,
                required customTypeDefinitions,
              }) async {}
            : _persistVaultData,
        onPersistVaultDocument: _isExploreDemoSession
            ? null
            : _persistVaultDocument,
        onPersistVaultDocumentStream: _isExploreDemoSession
            ? null
            : _persistVaultDocumentStream,
        onReadVaultDocument: _isExploreDemoSession ? null : _readVaultDocument,
        onLifecycleLockSuppressed: _setLifecycleLockSuppressed,
        onRotateMasterPassword: _isExploreDemoSession
            ? ({required currentPassword, required newPassword}) async {}
            : _rotateMasterPassword,
        onRotateRecoveryPhrase: _isExploreDemoSession
            ? ({
                required currentRecoveryPhrase,
                required newRecoveryPhrase,
              }) async {}
            : _rotateRecoveryPhrase,
        onExportVault: _isExploreDemoSession
            ? () async {}
            : () => _exportCurrentVaultToLocal(setAsActiveLocation: false),
        onImportVault: _isExploreDemoSession
            ? () async {}
            : () => _importVaultFromLocal(continueToUnlock: false),
        onBackupToCloud: _isExploreDemoSession
            ? () async {}
            : _backupCurrentVaultToCloud,
        onRestoreFromCloud: _isExploreDemoSession
            ? () async {}
            : _restoreCurrentVaultFromCloud,
        onReadCloudBackupAccount: _isExploreDemoSession
            ? () async => null
            : _readCloudBackupAccountLabel,
        onChangeCloudBackupAccount: _isExploreDemoSession
            ? () async => false
            : _changeCloudBackupAccount,
        onRenameVault: _isExploreDemoSession ? null : _renameActiveVault,
        onReadVaultInternals: kDebugMode && !_isExploreDemoSession
            ? _readVaultInternals
            : null,
        onLockNow: _lockVaultSession,
        onSwitchVault: _isExploreDemoSession
            ? _exitExploreDemoSession
            : _switchVaultFromApp,
        isExploreDemoSession: _isExploreDemoSession,
        onExitExploreDemo: _exitExploreDemoSession,
        cloudBackupFeatureAvailableOverride: _isExploreDemoSession
            ? false
            : null,
        debugInternalsFeatureAvailableOverride: _isExploreDemoSession
            ? false
            : null,
        expandedVaultStorageEntitled:
            !_isExploreDemoSession &&
            widget.entitlementState.expandedVaultStorage,
        canPurchaseExpandedVaultStorage:
            !_isExploreDemoSession && widget.canPurchaseExpandedVaultStorage,
        purchaseInProgress: !_isExploreDemoSession && widget.purchaseInProgress,
        entitlementSource: widget.entitlementState.source,
        entitlementLastVerifiedAt: widget.entitlementState.lastVerifiedAt,
        entitlementErrorMessage: widget.entitlementErrorMessage,
        onRefreshEntitlements: _isExploreDemoSession
            ? null
            : widget.onRefreshEntitlements,
        onPurchaseExpandedVaultStorage: _isExploreDemoSession
            ? null
            : widget.onPurchaseExpandedVaultStorage,
      ),
    };

    final usesEntryFlowTransition =
        _step == OnboardingStep.welcome ||
        _step == OnboardingStep.selectVault ||
        _step == OnboardingStep.unlock;
    final body = usesEntryFlowTransition
        ? ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                final begin = _stepTransitionForward
                    ? const Offset(1, 0)
                    : const Offset(-0.22, 0);
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: begin,
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                );
              },
              child: KeyedSubtree(
                key: ValueKey('$_step-${_vaultSelectionMode.name}'),
                child: screen,
              ),
            ),
          )
        : screen;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleRootPopInvoked());
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _step == OnboardingStep.app && !kIsWeb
            ? (_) => _scheduleUserActivityAfterFrame()
            : null,
        child: Stack(
          children: [
            body,
            if (_isBusy && !_isExploreDemoSession)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.25),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: Text(
                                  _busyMessage,
                                  key: ValueKey(_busyMessage),
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: _busyProgress.clamp(0, 1),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(_busyProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _handleRootBackPress() async {
    if (_isBusy) {
      if (!mounted) return false;
      final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please wait for the operation to finish.'),
        ),
      );
      return false;
    }
    if (_step == OnboardingStep.app) {
      _lockVaultSession();
      return false;
    }
    if (_step == OnboardingStep.walkthrough) {
      return true;
    }
    if (_step == OnboardingStep.setup) {
      if (!mounted) return false;
      setState(() {
        _step = _setupOpenedFromUnlock
            ? OnboardingStep.unlock
            : OnboardingStep.welcome;
        _setupOpenedFromUnlock = false;
      });
      return false;
    }
    if (_step == OnboardingStep.recovery) {
      if (!mounted) return false;
      _setOnboardingStep(OnboardingStep.setup, forward: false);
      return false;
    }
    if (_step == OnboardingStep.created) {
      if (!mounted) return false;
      _setOnboardingStep(OnboardingStep.recovery, forward: false);
      return false;
    }
    if (_step == OnboardingStep.selectVault) {
      if (!mounted) return false;
      _goBackFromSelectVault();
      return false;
    }
    if (_step != OnboardingStep.unlock) return true;

    final now = DateTime.now();
    final allowExit =
        _lastUnlockBackPressAt != null &&
        now.difference(_lastUnlockBackPressAt!) <= _unlockBackExitWindow;
    _lastUnlockBackPressAt = now;
    if (allowExit) return true;

    if (!mounted) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Press back again to exit.')));
    return false;
  }

  Future<void> _handleRootPopInvoked() async {
    if (_handlingRootPop) return;
    _handlingRootPop = true;
    try {
      final allowPop = await _handleRootBackPress();
      if (!allowPop || !mounted) return;
      await SystemNavigator.pop();
    } finally {
      _handlingRootPop = false;
    }
  }

  void _handleUnlock() {
    _setOnboardingStep(OnboardingStep.app, forward: true);
    _scheduleInactivityLockIfNeeded();
    unawaited(_markVaultAsOpened(_vaultFilePath));
    unawaited(_importPendingSharedTextIfReady());

    unawaited(_maybePromptToEnableBiometrics());
  }

  void _setOnboardingStep(OnboardingStep step, {required bool forward}) {
    setState(() {
      _stepTransitionForward = forward;
      _step = step;
    });
    if (step == OnboardingStep.welcome) {
      unawaited(_syncKnownVaults());
    }
  }

  Future<void> _presentSelectVaultStep({
    required OnboardingStep returnOnCancel,
  }) async {
    await _syncKnownVaults();
    if (!mounted) return;
    _selectVaultReturnStep = returnOnCancel;
    _setOnboardingStep(OnboardingStep.selectVault, forward: true);
  }

  void _goBackFromSelectVault() {
    if (_vaultSelectionMode == _VaultSelectionMode.cloudBackup) {
      _cloudBackupPickerCompleter?.complete(null);
      _cloudBackupPickerCompleter = null;
    }
    setState(() {
      if (_vaultSelectionMode == _VaultSelectionMode.cloudBackup) {
        _clearCloudVaultSelectionState();
        if (_cloudPickerOuterReturnStep != null) {
          _step = OnboardingStep.selectVault;
          _cloudPickerOuterReturnStep = null;
        } else {
          _step = _selectVaultReturnStep;
        }
      } else {
        _step = _selectVaultReturnStep;
      }
      _stepTransitionForward = false;
    });
  }

  void _clearCloudVaultSelectionState() {
    _vaultSelectionMode = _VaultSelectionMode.known;
    _cloudVaultReferences = <VaultReference>[];
    _cloudBackupsByStorageId = <String, CloudVaultBackupFile>{};
    _cloudVaultSelectionHeading = AppStrings.importVaultFromCloud;
  }

  VaultReference _vaultReferenceForCloudBackup(CloudVaultBackupFile backup) {
    final updatedAt = cloudBackupEffectiveUpdatedAt(backup);
    return VaultReference(
      id: backup.storageId,
      label: cloudBackupDisplayTitle(backup),
      addedAtEpochMs: updatedAt?.millisecondsSinceEpoch ?? 0,
      lastOpenedAtEpochMs: updatedAt?.millisecondsSinceEpoch ?? 0,
      sourceDescription: AppStrings.googleDriveBackup,
    );
  }

  void _handleCloudVaultSelected(VaultReference selected) {
    final backup = _cloudBackupsByStorageId[selected.id];
    final completer = _cloudBackupPickerCompleter;
    setState(() {
      _cloudBackupPickerCompleter = null;
      _cloudPickerOuterReturnStep = null;
      _clearCloudVaultSelectionState();
      if (completer == null) {
        _stepTransitionForward = false;
        _step = _selectVaultReturnStep;
      }
    });
    completer?.complete(backup);
  }

  void _handleKnownVaultSelected(VaultReference selected) {
    unawaited(_openKnownVault(selected));
  }

  Future<void> _openKnownVault(VaultReference selected) async {
    _clearSensitiveSessionState();
    _clearImportCredentialUi();
    final storagePath = await _resolveVaultStoragePath(selected.id);
    if (!mounted) return;
    setState(() {
      _vaultFilePath = storagePath;
      _vaultCreatedInSession = false;
    });
    await _presentUnlockStep(forward: true);
  }

  void _initializeFirstInstallWalkthroughState() {
    final override = widget.firstInstallWalkthroughCompletedOverride;
    if (override != null) {
      _step = override ? OnboardingStep.welcome : OnboardingStep.walkthrough;
      return;
    }
    if (widget.vaultService != null) {
      _step = OnboardingStep.welcome;
      return;
    }
    if (kIsWeb) {
      _step = OnboardingStep.welcome;
      return;
    }
    unawaited(_restoreFirstInstallWalkthroughState());
  }

  Future<void> _restoreFirstInstallWalkthroughState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed =
          prefs.getBool(_prefsFirstInstallWalkthroughCompletedKey) ?? false;
      if (!mounted) return;
      setState(() {
        _step = completed ? OnboardingStep.welcome : OnboardingStep.walkthrough;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _step = OnboardingStep.walkthrough);
    }
  }

  Future<void> _completeFirstInstallWalkthrough() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsFirstInstallWalkthroughCompletedKey, true);
    } catch (_) {
      // Completion should still move the user forward if preferences fail.
    }
    if (!mounted) return;
    setState(() => _step = OnboardingStep.welcome);
    unawaited(_syncKnownVaults());
  }

  Future<void> _maybePromptToEnableBiometrics() async {
    if (_biometricEnabled) return;
    final vaultId = _vaultFilePath;
    final hasPinForVault = await _pinCredentialStore.hasPin(vaultId: vaultId);
    final enrolledForVault = await _biometricEnrollmentStore.isEnrolledForVault(
      vaultId,
    );
    if (enrolledForVault && hasPinForVault) return;
    if (enrolledForVault && !hasPinForVault) {
      await _biometricCredentialStore.removeMasterPassword(vaultId: vaultId);
      await _biometricEnrollmentStore.setEnrolledForVault(
        vaultId: vaultId,
        enrolled: false,
      );
    }
    final hasSavedCredential = await _biometricCredentialStore
        .hasStoredCredential(vaultId: vaultId);
    if (hasSavedCredential && !hasPinForVault) {
      await _biometricCredentialStore.removeMasterPassword(vaultId: vaultId);
    }
    if (hasSavedCredential && hasPinForVault) {
      await _biometricEnrollmentStore.setEnrolledForVault(
        vaultId: vaultId,
        enrolled: true,
      );
      if (mounted && _vaultFilePath == vaultId && !_biometricEnabled) {
        setState(() => _biometricEnabled = true);
      }
      return;
    }

    if (_biometricPromptShown) return;
    _biometricPromptShown = true;

    if (!mounted || _step != OnboardingStep.app || _vaultFilePath != vaultId) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _vaultFilePath != vaultId) return;
      String? pin;
      if (kIsWeb) {
        pin = await _ensurePinForCurrentVault();
        if (pin == null || !mounted || _vaultFilePath != vaultId) return;
      }
      final canUseBiometrics = await _biometricAuthService.canUseBiometrics();
      if (!canUseBiometrics) {
        await _refreshBiometricStateForActiveVault();
        return;
      }
      if (!mounted || _vaultFilePath != vaultId) return;
      final shouldEnable = kIsWeb
          ? await showWebBiometricEnableDialog(
              context,
              onConfirm: () async {
                await _biometricCredentialStore.saveMasterPassword(
                  vaultId: vaultId,
                  password: pin!,
                  displayName: _activeVaultName,
                  newEnrollment: true,
                );
              },
            )
          : await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(AppStrings.enableBiometricPromptTitle),
                content: Text(AppStrings.enableBiometricPromptMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(AppStrings.notNow),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(AppStrings.enable),
                  ),
                ],
              ),
            );

      if (shouldEnable == true && mounted && _vaultFilePath == vaultId) {
        if (kIsWeb) {
          await _biometricEnrollmentStore.setEnrolledForVault(
            vaultId: vaultId,
            enrolled: true,
          );
          await _refreshBiometricStateForActiveVault();
          if (!mounted || _vaultFilePath != vaultId) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric unlock enabled.')),
          );
        } else {
          await _enableBiometricForCurrentVault();
        }
      }
    });
  }

  void _handleWebPageHidden() {
    if (!mounted ||
        _step != OnboardingStep.app ||
        _shouldSuppressLifecycleLock) {
      return;
    }
    _lockVaultSession();
  }

  void _onBiometricPreferenceChanged(bool enabled) {
    if (enabled) {
      unawaited(_confirmAndEnableBiometricForCurrentVault());
      return;
    }
    unawaited(_confirmAndDisableBiometricForCurrentVault());
  }

  void _onPinPreferenceChanged(bool _) {
    unawaited(_setOrChangePinForCurrentVault());
  }

  Future<GuardianProfile> _resolveGuardianForVault(String filePath) async {
    try {
      final raw = await _vaultService.readRawVaultFile(filePath: filePath);
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final guardian = decoded['guardian'];
      if (guardian is Map) {
        final profileId = guardian['profile']?.toString() ?? '';
        for (final candidate in GuardianProfiles.all) {
          if (candidate.id == profileId) return candidate;
        }
      }
    } catch (_) {
      // Fall back to the last selected guardian profile.
    }
    return _selectedGuardian;
  }

  Future<void> _syncUnlockPresentation({String? vaultLabel}) async {
    _activeVaultName = vaultLabel ?? await _resolveVaultLabel(_vaultFilePath);
    _activeGuardianProfile = await _resolveGuardianForVault(_vaultFilePath);
  }

  Future<void> _presentUnlockStep({
    String? vaultLabel,
    bool forward = true,
  }) async {
    await _syncUnlockPresentation(vaultLabel: vaultLabel);
    if (!mounted) return;
    _setOnboardingStep(OnboardingStep.unlock, forward: forward);
    await _refreshBiometricStateForActiveVault();
  }

  Future<void> _goBackFromUnlock() async {
    if (!mounted) return;
    _completeImportCredentialRequest(null);
    _completeActionUnlockRequest(success: false);
    _passwordController.clear();
    await _syncKnownVaults();
    if (!mounted) return;
    _selectVaultReturnStep = OnboardingStep.welcome;
    _setOnboardingStep(OnboardingStep.selectVault, forward: false);
  }

  void _completeImportCredentialRequest(_ImportVaultCredentialChoice? choice) {
    final completer = _importCredentialCompleter;
    _importCredentialCompleter = null;
    _importCredentialAllowRecovery = true;
    if (completer != null && !completer.isCompleted) {
      completer.complete(choice);
    }
  }

  void _completeActionUnlockRequest({required bool success}) {
    final completer = _actionUnlockCompleter;
    _actionUnlockCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(success);
    }
  }

  Future<void> _openExistingVault() async {
    if (!_storageReady) return;
    if (!mounted) return;
    await _presentSelectVaultStep(returnOnCancel: OnboardingStep.unlock);
  }

  Future<void> _selectKnownVault() async {
    if (!_storageReady || !mounted) return;
    await _presentSelectVaultStep(returnOnCancel: OnboardingStep.welcome);
  }

  Future<VaultReference?> _pickVaultFileForUnlock() async {
    try {
      final imported = await _vaultPortability.importVaultFromLocal();
      if (imported == null) return null;
      final importedPath = await _localPathForImportedVault(imported);
      await _vaultService.writeRawVaultFile(
        filePath: importedPath,
        rawContent: imported.content,
      );
      final label = _humanImportLabel(imported);
      await _rememberVaultReference(
        importedPath,
        label: label,
        sourceDescription: _sourceDescriptionForImportedVault(imported),
      );
      if (!mounted) return null;
      return VaultReference(
        id: importedPath,
        label: label,
        addedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        sourceDescription: _sourceDescriptionForImportedVault(imported),
      );
    } catch (error, stackTrace) {
      if (_isFilePickerCancellation(error)) return null;
      _logOperationError('pickVaultFileForUnlock', error, stackTrace);
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.vaultImportFailed)));
      return null;
    }
  }

  Future<void> _createVaultAndProceed() async {
    if (!_storageReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vault storage is still initializing. Please try again.',
          ),
        ),
      );
      return;
    }
    _startBusy('Starting vault creation...');
    try {
      _updateBusy(
        const VaultOperationProgress(
          value: 0.08,
          message: 'Generating recovery phrase...',
        ),
      );
      _recoveryWords = RecoveryPhraseGenerator.generate();
      final recoveryPhrase = _recoveryWords.join(' ');
      final vaultName = _vaultNameController.text.trim().isEmpty
          ? _defaultVaultName
          : _vaultNameController.text.trim();
      await _vaultService.createVault(
        filePath: _vaultFilePath,
        vaultId: _draftVaultId,
        vaultName: vaultName,
        guardianProfileId: _selectedGuardian.id,
        password: _passwordController.text,
        recoveryPhrase: recoveryPhrase,
        onProgress: _updateBusy,
      );
      if (!mounted) return;
      _activeVaultName = vaultName;
      await _resetBiometricForVault(_vaultFilePath);
      await _rememberVaultReference(
        _vaultFilePath,
        label: vaultName,
        sourceDescription: _defaultVaultSourceDescription(),
      );
      _busyWatchdog?.cancel();
      setState(() {
        _isBusy = false;
        _busyProgress = 0;
        _busyMessage = '';
        _vaultCreatedInSession = true;
        _step = OnboardingStep.recovery;
      });
      if (_lastLifecycleState == AppLifecycleState.paused) {
        _scheduleBackgroundLockIfNeeded();
      }
    } catch (error, stackTrace) {
      _logOperationError('createVault', error, stackTrace);
      _stopBusy();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create vault file. ${_errorHint(error)}'),
        ),
      );
    }
  }

  Future<void> _unlockWithPassword() async {
    if (!_storageReady) return;
    if (_isBusy) return;

    final importCompleter = _importCredentialCompleter;
    if (importCompleter != null) {
      final password = _passwordController.text.trim();
      if (password.isEmpty) return;
      _importCredentialCompleter = null;
      if (!importCompleter.isCompleted) {
        importCompleter.complete(
          _ImportVaultCredentialChoice.password(password),
        );
      }
      return;
    }

    _startBusy('Starting vault unlock...');
    try {
      final vaultPath = await _resolveVaultStoragePath(_vaultFilePath);
      if (vaultPath != _vaultFilePath && mounted) {
        setState(() => _vaultFilePath = vaultPath);
      }
      await _vaultService
          .unlockVault(
            filePath: vaultPath,
            password: _passwordController.text,
            onProgress: _updateBusy,
          )
          .timeout(_vaultOpTimeout);
      await _loadVaultData(_passwordController.text);
      _activeVaultName = await _resolveVaultLabel(vaultPath);
      await _refreshVaultSize();
      _sessionMasterPassword = _passwordController.text;
      if (_biometricEnabled && !kIsWeb) {
        try {
          await _biometricCredentialStore.saveMasterPassword(
            vaultId: _vaultFilePath,
            password: _passwordController.text,
            displayName: _activeVaultName,
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppStrings.webBiometricEnableFailed)),
            );
          }
        }
      }
      if (!mounted) return;
      if (_actionUnlockCompleter != null) {
        _completeActionUnlockRequest(success: true);
      }
      _handleUnlock();
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock timed out. Please try again.')),
      );
    } catch (error, stackTrace) {
      _logOperationError('unlockWithPassword', error, stackTrace);
      if (!mounted) return;
      final exists = await _vaultService.vaultExists(filePath: _vaultFilePath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exists
                ? AppStrings.wrongVaultPassword
                : AppStrings.noExistingVaultFound,
          ),
        ),
      );
    } finally {
      _stopBusy();
    }
  }

  Future<void> _unlockWithBiometric() async {
    if (!_biometricEnabled || _isBusy || !_storageReady) return;
    final vaultId = _vaultFilePath;
    final hasCredential = await _biometricCredentialStore.hasStoredCredential(
      vaultId: vaultId,
    );
    if (!hasCredential) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unlock once with master password to enable biometrics.',
          ),
        ),
      );
      return;
    }
    final authenticated = await _biometricAuthService.authenticateForUnlock(
      localizedReason: AppStrings.biometricAuthenticateReason,
      vaultId: vaultId,
    );
    if (!authenticated || !mounted || _vaultFilePath != vaultId) return;
    final savedPassword = await _biometricCredentialStore.readMasterPassword(
      vaultId: vaultId,
      webAuthCompleted: true,
    );
    if (savedPassword == null || savedPassword.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.webBiometricUnlockFailed)),
      );
      return;
    }
    if (kIsWeb) {
      final password = await _pinCredentialStore.readMasterPassword(
        vaultId: vaultId,
        pin: savedPassword,
      );
      if (password == null || password.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.webBiometricUnlockFailed)),
        );
        return;
      }
      _passwordController.text = password;
    } else {
      _passwordController.text = savedPassword;
    }
    await _unlockWithPassword();
  }

  Future<void> _unlockWithPin() async {
    if (!_pinEnabled || _isBusy || !_storageReady) return;
    final vaultId = _vaultFilePath;
    final pin = await _promptForPin(title: AppStrings.appPinUnlockTitle);
    if (pin == null || !mounted || _vaultFilePath != vaultId) return;
    final password = await _pinCredentialStore.readMasterPassword(
      vaultId: vaultId,
      pin: pin,
    );
    if (password == null || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.appPinInvalidMessage)));
      return;
    }
    _passwordController.text = password;
    await _unlockWithPassword();
  }

  Future<void> _openCreateVaultFromUnlock() async {
    _passwordController.clear();
    _prepareVaultDraft();
    if (!mounted) return;
    setState(() {
      _setupOpenedFromUnlock = true;
      _step = OnboardingStep.setup;
    });
  }

  Future<void> _openEncryptedSecretFromUnlock() async {
    final imported = await _secretSharePortability.importEncryptedFile();
    if (imported == null || !mounted) return;
    await _openImportedEncryptedSecret(imported);
  }

  Future<void> _consumePendingSecretIntent() async {
    if (_isExploreDemoSession) return;
    if (_consumingPendingSecretIntent) return;
    _consumingPendingSecretIntent = true;
    try {
      final imported = await _secretIntentBridge.consumePendingSecret();
      if (imported == null || !mounted) return;
      await _openImportedEncryptedSecret(imported);
    } finally {
      _consumingPendingSecretIntent = false;
    }
  }

  Future<void> _consumePendingSharedTextIntent() async {
    if (_isExploreDemoSession) return;
    if (_consumingPendingSharedTextIntent) return;
    _consumingPendingSharedTextIntent = true;
    try {
      final shared = await _secretIntentBridge.consumePendingSharedText();
      if (shared == null || !mounted) return;
      _pendingSharedTextIntent = shared;
      if (_step == OnboardingStep.app) {
        await _importPendingSharedTextIfReady();
      } else {
        await _routeToVaultForPendingSharedText();
      }
    } finally {
      _consumingPendingSharedTextIntent = false;
    }
  }

  Future<void> _routeToVaultForPendingSharedText() async {
    if (!mounted || _pendingSharedTextIntent == null || !_storageReady) return;
    if (_step != OnboardingStep.welcome) return;
    final hasDefaultVault = await _vaultService.vaultExists(
      filePath: _vaultFilePath,
    );
    if (!mounted || _pendingSharedTextIntent == null) return;
    if (hasDefaultVault) {
      await _presentUnlockStep();
      return;
    }
    if (_knownVaults.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pendingSharedTextIntent == null) return;
        unawaited(_openExistingVault());
      });
    }
  }

  Future<void> _importPendingSharedTextIfReady() async {
    if (_isExploreDemoSession) return;
    final shared = _pendingSharedTextIntent;
    if (shared == null || !mounted || _step != OnboardingStep.app) return;
    _pendingSharedTextIntent = null;
    final note = _noteFromSharedText(shared);
    final nextNotes = <Map<String, dynamic>>[
      note,
      ..._vaultNotes.map((entry) => Map<String, dynamic>.from(entry)),
    ];
    await _persistVaultData(
      items: _vaultItems,
      notes: nextNotes,
      customTypeDefinitions: _customTypeDefinitions,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shared text saved to ${note['title']}')),
    );
  }

  Map<String, dynamic> _noteFromSharedText(SharedTextIntent shared) {
    final importedAt = DateTime.now().toUtc();
    final importedAtIso = importedAt.toIso8601String();
    final sourceApplication = shared.sourceApplication.trim().isEmpty
        ? 'Unknown app'
        : shared.sourceApplication.trim();
    final sourceTag = _tagFromSharedSource(sourceApplication);
    final tags = <String>{
      'shared',
      sourceTag,
    }.where((entry) => entry.trim().isNotEmpty).toList()..sort();
    final title =
        'Shared from $sourceApplication ${_formatSharedImportTimestamp(importedAt)}';
    final body = shared.text.endsWith('\n') ? shared.text : '${shared.text}\n';
    final preview = shared.text
        .split('\n')
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '')
        .trim();
    return {
      'id': 'note-shared-${DateTime.now().microsecondsSinceEpoch}',
      'title': title,
      'preview': preview,
      'updated': 'Now',
      'pinned': false,
      'tags': tags,
      'createdAt': importedAtIso,
      'updatedAt': importedAtIso,
      'sharedAt': importedAtIso,
      'importedAt': importedAtIso,
      'sourceApplication': sourceApplication,
      if (shared.sourcePackage != null) 'sourcePackage': shared.sourcePackage,
      'delta': [
        {'insert': body},
      ],
    };
  }

  String _tagFromSharedSource(String sourceApplication) {
    return sourceApplication
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _formatSharedImportTimestamp(DateTime timestamp) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final local = timestamp.toLocal();
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  Future<void> _openImportedEncryptedSecret(ImportedSecretFile imported) async {
    final password = await _promptSecretPassword();
    if (password == null || password.trim().isEmpty || !mounted) return;
    var busyStarted = false;
    try {
      _startBusy(
        'Decrypting imported file...',
        timeout: const Duration(minutes: 1),
        timeoutMessage:
            'Import is taking longer than expected. Large files may need more time.',
      );
      busyStarted = true;
      await _waitForOverlayTeardown();
      final decoded = await _encryptedShareCodec.decode(
        encoded: imported.content,
        password: password.trim(),
      );
      if (!mounted) return;
      _updateBusyStep('Preparing import preview...', 0.65);
      final normalizedType = decoded.contentType.trim().toLowerCase();
      if (normalizedType == 'vault_bundle') {
        final entries = _encryptedImportEntriesFromBundle(decoded.plainText);
        if (entries.isNotEmpty) {
          if (entries.length > 1) {
            _stopBusy();
            busyStarted = false;
            final importedAny = await Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (context) => _EncryptedImportBundleScreen(
                  entries: entries,
                  onImportEntry: _importEncryptedBundleEntryWithAuth,
                  onImportAll: _importEncryptedBundleEntriesWithAuth,
                ),
              ),
            );
            if (importedAny == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppStrings.encryptedSecretImported)),
              );
            }
            return;
          }
          _stopBusy();
          busyStarted = false;
          final importedSingle = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (context) => _EncryptedImportEntryPreviewScreen(
                entry: entries.first,
                alreadyImported: false,
                onImport: () =>
                    _importEncryptedBundleEntryWithAuth(entries.first),
              ),
            ),
          );
          if (importedSingle == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppStrings.encryptedSecretImported)),
            );
          }
          return;
        }
      }
      if (normalizedType == 'document') {
        final entry = _encryptedImportEntryFromDocument(decoded.plainText);
        if (entry == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.encryptedSecretImportFailed)),
          );
          return;
        }
        _stopBusy();
        busyStarted = false;
        final importedSingle = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) => _EncryptedImportEntryPreviewScreen(
              entry: entry,
              alreadyImported: false,
              onImport: () => _importDecodedSecretToVaultWithResult(
                decoded,
                actionLabel: 'Import document',
              ),
            ),
          ),
        );
        if (importedSingle == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.encryptedSecretImported)),
          );
        }
        return;
      }
      final fields = _parseEncryptedSecretFields(decoded.plainText);
      _stopBusy();
      busyStarted = false;
      final shouldImport = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (context) => _EncryptedSecretViewerScreen(
            title: decoded.fileName,
            fields: fields,
            onImport: () => Navigator.of(context).pop(true),
          ),
        ),
      );
      if (shouldImport == true && mounted) {
        await _importDecodedSecretToVault(decoded);
      }
    } catch (_) {
      if (busyStarted) _stopBusy();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImportFailed)),
      );
    }
  }

  _EncryptedImportEntry? _encryptedImportEntryFromDocument(String plainText) {
    try {
      final decoded = jsonDecode(plainText);
      if (decoded is! Map) return null;
      final entry = Map<String, dynamic>.from(decoded);
      return _EncryptedImportEntry(
        index: 0,
        kind: 'document',
        bundleEntry: entry,
        title: _bundleImportTitle(entry, 'document'),
        subtitle: _bundleImportSubtitle(entry, 'document'),
      );
    } catch (_) {
      return null;
    }
  }

  List<_SecretField> _parseEncryptedSecretFields(String plainText) {
    final lines = plainText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return const <_SecretField>[];
    }
    final fields = <_SecretField>[];
    for (final line in lines) {
      final sep = line.indexOf(':');
      if (sep > 0 && sep < line.length - 1) {
        final key = line.substring(0, sep).trim();
        final value = line.substring(sep + 1).trim();
        if (key.isEmpty || value.isEmpty) continue;
        fields.add(
          _SecretField(
            key: key,
            value: value,
            sensitive: _isSensitiveFieldKey(key),
          ),
        );
      }
    }
    if (fields.isNotEmpty) {
      return fields;
    }
    return <_SecretField>[
      _SecretField(key: 'Content', value: plainText.trim(), sensitive: false),
    ];
  }

  bool _isSensitiveFieldKey(String key) {
    final normalized = key.toLowerCase();
    const sensitiveTokens = <String>[
      'password',
      'passcode',
      'pin',
      'secret',
      'token',
      'key',
    ];
    return sensitiveTokens.any(normalized.contains);
  }

  Future<void> _importDecodedSecretToVault(
    DecryptedSharePayload payload,
  ) async {
    final imported = await _importDecodedSecretToVaultWithResult(payload);
    if (imported && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImported)),
      );
    }
  }

  Future<bool> _importDecodedSecretToVaultWithResult(
    DecryptedSharePayload payload, {
    String actionLabel = 'Import secret',
  }) async {
    final authenticated = await _ensureAuthenticatedVaultSessionForAction(
      actionLabel: actionLabel,
    );
    if (!authenticated) {
      return false;
    }
    final applied = await _applyImportedSecret(payload);
    if (!applied) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImportFailed)),
      );
      return false;
    }
    try {
      await _persistVaultData(
        items: _vaultItems,
        notes: _vaultNotes,
        customTypeDefinitions: _customTypeDefinitions,
      );
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to import secret into vault.')),
      );
      return false;
    }
  }

  Future<bool> _ensureAuthenticatedVaultSessionForAction({
    required String actionLabel,
  }) async {
    if (_step == OnboardingStep.app &&
        _passwordController.text.trim().isNotEmpty) {
      return true;
    }
    if (!_storageReady || !mounted) return false;

    final selectedVault = await _selectVaultForAuthenticatedAction();
    if (selectedVault == null || !mounted) return false;

    setState(() {
      _vaultFilePath = selectedVault.id;
    });
    _actionUnlockCompleter = Completer<bool>();
    final unlockResult = _actionUnlockCompleter!;
    await _presentUnlockStep(vaultLabel: selectedVault.label);
    return unlockResult.future;
  }

  Future<VaultReference?> _selectVaultForAuthenticatedAction() async {
    await _syncKnownVaults();
    if (!mounted) return null;
    if (_knownVaults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved vaults found to unlock.')),
      );
      return null;
    }
    return showModalBottomSheet<VaultReference>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Select vault',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ..._knownVaults.map(
              (entry) => ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(entry.label),
                subtitle: Text(entry.id),
                onTap: () => Navigator.of(context).pop(entry),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _applyImportedSecret(DecryptedSharePayload payload) async {
    final normalized = payload.contentType.trim().toLowerCase();
    if (normalized == 'note') {
      final note = _noteFromImported(payload.plainText);
      if (note == null) return false;
      setState(() => _vaultNotes.insert(0, note));
      return true;
    }
    if (normalized == 'vault_item') {
      final item = _itemFromImported(payload.plainText);
      if (item == null) return false;
      setState(() => _vaultItems.insert(0, item));
      return true;
    }
    if (normalized == 'document') {
      final item = await _documentFromImported(payload.plainText);
      if (item == null) return false;
      if (!mounted) return false;
      setState(() => _vaultItems.insert(0, item));
      return true;
    }
    if (normalized == 'vault_bundle') {
      return _importEncryptedBundleEntries(
        _encryptedImportEntriesFromBundle(payload.plainText),
      );
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
    if (firstLine.isEmpty || _looksLikeEncodedPreviewData(firstLine)) {
      return null;
    }
    return firstLine;
  }

  String _bundleImportSubtitle(Map<String, dynamic> entry, String kind) {
    if (kind == 'note') return 'Secure Note';
    if (kind == 'document') {
      final extension = entry['extension']?.toString().trim().toUpperCase();
      final size = entry['sizeBytes'];
      final formattedSize = size == null
          ? ''
          : _formatDocumentByteCount(int.tryParse(size.toString()) ?? 0);
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

  Future<bool> _importEncryptedBundleEntryWithAuth(
    _EncryptedImportEntry entry,
  ) async {
    final authenticated = await _ensureAuthenticatedVaultSessionForAction(
      actionLabel: 'Import secret',
    );
    if (!authenticated) return false;
    final ok = await _importEncryptedBundleEntry(entry);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImportFailed)),
      );
    }
    return ok;
  }

  Future<bool> _importEncryptedBundleEntriesWithAuth(
    List<_EncryptedImportEntry> entries,
  ) async {
    final authenticated = await _ensureAuthenticatedVaultSessionForAction(
      actionLabel: 'Import secret',
    );
    if (!authenticated) return false;
    final ok = await _importEncryptedBundleEntries(entries);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImportFailed)),
      );
    }
    return ok;
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
    await _persistVaultData(
      items: _vaultItems,
      notes: _vaultNotes,
      customTypeDefinitions: _customTypeDefinitions,
    );
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
    await _persistVaultData(
      items: _vaultItems,
      notes: _vaultNotes,
      customTypeDefinitions: _customTypeDefinitions,
    );
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
      _vaultItems.insertAll(0, imported.items);
      _vaultNotes.insertAll(0, imported.notes);
    });
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
    final sizeBytes = _bundleDocumentMetadataSizeBytes(
      bundleEntry,
      item,
      fallbackBytes: bytes.length,
    );
    if (!_canStoreDocumentBytes(sizeBytes)) return null;
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
          extension ?? item['documentExtension'] ?? _extensionFromFileName(item)
      ..['documentSizeBytes'] = sizeBytes;
    final sectionName = await _persistVaultDocument(
      documentId: item['id']?.toString() ?? '',
      bytes: bytes,
      sizeBytes: sizeBytes,
    );
    item['documentStorage'] = 'private-section';
    item['documentSection'] = sectionName;
    return item;
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

  String _extensionFromFileName(Map<String, dynamic> item) {
    final fileName = item['documentFileName']?.toString().trim();
    if (fileName == null || fileName.isEmpty) return 'FILE';
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'FILE';
    return fileName.substring(dot + 1).toUpperCase();
  }

  bool _canStoreDocumentBytes(int bytes) {
    if (bytes > VaultLimits.maxDocumentBytes) {
      _showVaultLimitMessage(
        'Document must be ${VaultLimits.formatBytes(VaultLimits.maxDocumentBytes)} or smaller.',
      );
      return false;
    }
    final projected = _activeVaultSizeBytes + bytes;
    final maxVaultBytes = VaultLimits.maxVaultBytesFor(
      currentVaultSizeBytes: _activeVaultSizeBytes,
      expandedStorageEntitled: widget.entitlementState.expandedVaultStorage,
    );
    if (projected > maxVaultBytes) {
      _showVaultLimitMessage(
        'Not enough vault space. Limit is ${VaultLimits.formatBytes(maxVaultBytes)}.',
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
    final fields = <Map<String, dynamic>>[];
    for (final line in lines.skip(1)) {
      final sep = line.indexOf(':');
      if (sep <= 0 || sep >= line.length - 1) continue;
      final key = line.substring(0, sep).trim();
      final value = line.substring(sep + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      fields.add({
        'label': key,
        'value': value,
        'sensitive': _isSensitiveFieldKey(key),
      });
    }
    final id = 'item-imported-${DateTime.now().microsecondsSinceEpoch}';
    final subtitle = fields.isEmpty
        ? 'Imported encrypted secret'
        : fields.take(2).map((entry) => entry['label']).join(' · ');
    return {
      'id': id,
      'type': 'Imported Secret',
      'title': title,
      'subtitle': subtitle,
      'updated': 'Now',
      'pinned': false,
      'fields': fields,
    };
  }

  Future<String?> _promptSecretPassword() async {
    final controller = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setLocalState) {
            final canContinue = controller.text.trim().isNotEmpty;
            return AlertDialog(
              title: Text(AppStrings.openEncryptedSecret),
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
                  child: const Text('Open'),
                ),
              ],
            );
          },
        ),
      );
      await _waitForDialogTeardown();
      return result;
    } finally {
      controller.dispose();
    }
  }

  Future<void> _loadVaultData(String password) async {
    final payload = await _vaultService.readVaultPayload(
      filePath: _vaultFilePath,
      password: password,
    );
    final customTypes =
        (payload.settings['customTypeDefinitions'] as List<dynamic>? ??
                const <dynamic>[])
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();
    if (!mounted) return;
    setState(() {
      _vaultItems = payload.items
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _vaultNotes = payload.notes
          .map((note) => Map<String, dynamic>.from(note))
          .toList();
      _customTypeDefinitions = customTypes;
    });
    await _refreshVaultSize();
    await _ensureRecoveryPhraseNoteInVault(password: password);
  }

  Map<String, dynamic> _buildRecoveryPhraseNote() {
    final lines = <String>[
      'Recovery phrase',
      '',
      _recoveryWords.join(' '),
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

  Future<void> _ensureRecoveryPhraseNoteInVault({
    required String password,
  }) async {
    if (_vaultNotes.any(
      (note) => note['id']?.toString() == 'note-recovery-phrase',
    )) {
      return;
    }
    final notes = <Map<String, dynamic>>[
      _buildRecoveryPhraseNote(),
      ..._vaultNotes.map((note) => Map<String, dynamic>.from(note)),
    ];
    await _persistVaultData(
      items: _vaultItems,
      notes: notes,
      customTypeDefinitions: _customTypeDefinitions,
      passwordOverride: password,
    );
  }

  Future<void> _persistVaultData({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> notes,
    required List<Map<String, dynamic>> customTypeDefinitions,
    String? passwordOverride,
  }) async {
    final run = _persistVaultChain.then(
      (_) => _persistVaultDataImpl(
        items: items,
        notes: notes,
        customTypeDefinitions: customTypeDefinitions,
        passwordOverride: passwordOverride,
      ),
    );
    _persistVaultChain = run.catchError((_) {});
    await run;
  }

  Future<void> _persistVaultDataImpl({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> notes,
    required List<Map<String, dynamic>> customTypeDefinitions,
    String? passwordOverride,
  }) async {
    final password =
        passwordOverride?.trim() ?? _passwordController.text.trim();
    if (password.isEmpty) {
      throw StateError('Master password missing for persistence.');
    }

    final normalizedItems = _applyEntryMetadata(
      kind: 'item',
      nextEntries: items,
      previousEntries: _vaultItems,
    );
    final normalizedNotes = _applyEntryMetadata(
      kind: 'note',
      nextEntries: notes,
      previousEntries: _vaultNotes,
    );

    final payload = VaultPayload(
      schemaVersion: 1,
      items: normalizedItems,
      notes: normalizedNotes,
      tags: const <String>[],
      settings: <String, dynamic>{
        'customTypeDefinitions': customTypeDefinitions
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(),
      },
      audit: const <Map<String, dynamic>>[],
    );
    await _vaultService.persistVaultPayload(
      filePath: _vaultFilePath,
      password: password,
      payload: payload,
    );
    await _refreshVaultSize();
    if (!mounted) return;
    setState(() {
      _vaultItems = normalizedItems
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _vaultNotes = normalizedNotes
          .map((note) => Map<String, dynamic>.from(note))
          .toList();
      _customTypeDefinitions = customTypeDefinitions
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    });
  }

  Future<String> _persistVaultDocument({
    required String documentId,
    required List<int> bytes,
    int? sizeBytes,
  }) async {
    return _persistVaultDocumentStream(
      documentId: documentId,
      chunks: Stream<List<int>>.value(bytes),
      sizeBytes: sizeBytes ?? bytes.length,
    );
  }

  Future<String> _persistVaultDocumentStream({
    required String documentId,
    required Stream<List<int>> chunks,
    required int sizeBytes,
  }) async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      throw StateError('Master password missing for document persistence.');
    }
    final sectionName = await _vaultService.persistVaultDocumentStream(
      filePath: _vaultFilePath,
      password: password,
      documentId: documentId,
      chunks: chunks,
      sizeBytes: sizeBytes,
    );
    await _refreshVaultSize();
    return sectionName;
  }

  Future<List<int>> _readVaultDocument({
    required String sectionName,
    VaultDocumentLoadProgress? onProgress,
  }) async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      throw StateError('Master password missing for document preview.');
    }
    return _vaultService.readVaultDocument(
      filePath: _vaultFilePath,
      password: password,
      sectionName: sectionName,
      onProgress: onProgress == null
          ? null
          : (progress) => onProgress(progress.message, progress.value),
    );
  }

  void _setLifecycleLockSuppressed(bool suppressed) {
    _lifecycleLockSuppressed = suppressed;
    if (suppressed) {
      _backgroundLockTimer?.cancel();
      _inactivityLockTimer?.cancel();
      return;
    }
    if (_lastLifecycleState == AppLifecycleState.paused) {
      _scheduleBackgroundLockIfNeeded();
    } else {
      _scheduleInactivityLockIfNeeded();
    }
  }

  bool get _shouldSuppressLifecycleLock => _lifecycleLockSuppressed || _isBusy;

  bool get _shouldSuppressAutoLock =>
      _shouldSuppressLifecycleLock ||
      _isExploreDemoSession ||
      widget.autoLockDelay <= Duration.zero;

  void _deferAfterPointer(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action();
    });
  }

  void _scheduleUserActivityAfterFrame() {
    if (_step != OnboardingStep.app ||
        _lastLifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _deferAfterPointer(_scheduleInactivityLockIfNeeded);
  }

  void _scheduleInactivityLockIfNeeded() {
    _inactivityLockTimer?.cancel();
    if (!mounted ||
        _step != OnboardingStep.app ||
        _lastLifecycleState != AppLifecycleState.resumed ||
        _shouldSuppressAutoLock) {
      return;
    }
    _inactivityLockTimer = Timer(widget.autoLockDelay, () {
      if (!mounted ||
          _step != OnboardingStep.app ||
          _lastLifecycleState != AppLifecycleState.resumed ||
          _shouldSuppressAutoLock) {
        return;
      }
      _lockVaultSession();
    });
  }

  void _scheduleBackgroundLockIfNeeded() {
    _backgroundLockTimer?.cancel();
    if (!mounted || _step != OnboardingStep.app || _shouldSuppressAutoLock) {
      return;
    }
    _inactivityLockTimer?.cancel();
    _backgroundLockTimer = Timer(widget.autoLockDelay, () {
      if (!mounted ||
          _step != OnboardingStep.app ||
          _lastLifecycleState == AppLifecycleState.resumed ||
          _shouldSuppressAutoLock) {
        return;
      }
      _lockVaultSession();
    });
  }

  void _enterExploreDemoSession() {
    _backgroundLockTimer?.cancel();
    _inactivityLockTimer?.cancel();
    _pendingSharedTextIntent = null;
    _deferAfterPointer(() {
      if (!mounted) return;
      _busyWatchdog?.cancel();
      setState(() {
        _isBusy = false;
        _busyProgress = 0;
        _busyMessage = '';
        _isExploreDemoSession = true;
        _activeVaultName = VaultHomeDemoData.vaultName;
        _activeGuardianProfile = GuardianProfiles.owl;
        _recoveryWords = List<String>.from(VaultHomeDemoData.recoveryWords);
        _vaultItems = VaultHomeDemoData.cloneItems();
        _vaultNotes = VaultHomeDemoData.cloneNotes();
        _customTypeDefinitions = <Map<String, dynamic>>[];
        _stepTransitionForward = true;
        _step = OnboardingStep.app;
      });
    });
  }

  void _exitExploreDemoSession() {
    _backgroundLockTimer?.cancel();
    _inactivityLockTimer?.cancel();
    _deferAfterPointer(() {
      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
      if (!mounted) return;
      setState(() {
        _isExploreDemoSession = false;
        _stepTransitionForward = false;
        _step = OnboardingStep.welcome;
      });
    });
  }

  void _lockVaultSession() {
    if (_isExploreDemoSession) {
      _exitExploreDemoSession();
      return;
    }
    final lockedVault = VaultReference(
      id: _vaultFilePath,
      label: _activeVaultName,
      addedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      sourceDescription:
          _findVaultReference(_vaultFilePath)?.sourceDescription ??
          _defaultVaultSourceDescription(),
    );
    _backgroundLockTimer?.cancel();
    _inactivityLockTimer?.cancel();
    if (mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
    }
    _clearSensitiveSessionState();
    if (!mounted) return;
    setState(() {
      _selectVaultReturnStep = OnboardingStep.welcome;
      _stepTransitionForward = true;
      _step = OnboardingStep.selectVault;
      if (!_knownVaults.any((entry) => entry.id == lockedVault.id)) {
        _knownVaults = <VaultReference>[lockedVault, ..._knownVaults];
      }
    });
  }

  Future<void> _switchVaultFromApp() async {
    await _syncKnownVaults();
    if (!mounted) return;
    final currentVault = VaultReference(
      id: _vaultFilePath,
      label: _activeVaultName,
      addedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      sourceDescription:
          _findVaultReference(_vaultFilePath)?.sourceDescription ??
          _defaultVaultSourceDescription(),
    );
    setState(() {
      if (!_knownVaults.any((entry) => entry.id == currentVault.id)) {
        _knownVaults = <VaultReference>[currentVault, ..._knownVaults];
      }
    });

    await _presentSelectVaultStep(returnOnCancel: OnboardingStep.app);
  }

  Future<void> _renameActiveVault(String name) async {
    final renamed = name.trim();
    if (renamed.isEmpty) {
      throw StateError('Vault name cannot be empty.');
    }

    await _vaultService.renameVault(filePath: _vaultFilePath, label: renamed);
    await _rememberVaultReference(
      _vaultFilePath,
      label: renamed,
      sourceDescription: _findVaultReference(_vaultFilePath)?.sourceDescription,
    );
    await _refreshVaultSize();
    if (!mounted) return;
    setState(() => _activeVaultName = renamed);
  }

  List<Map<String, dynamic>> _applyEntryMetadata({
    required String kind,
    required List<Map<String, dynamic>> nextEntries,
    required List<Map<String, dynamic>> previousEntries,
  }) {
    final previousById = <String, Map<String, dynamic>>{};
    for (final entry in previousEntries) {
      final id = entry['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) {
        previousById[id] = Map<String, dynamic>.from(entry);
      }
    }

    final result = <Map<String, dynamic>>[];
    for (final raw in nextEntries) {
      final current = Map<String, dynamic>.from(raw);
      var id = current['id']?.toString().trim() ?? '';
      if (id.isEmpty) {
        id =
            '$kind-${DateTime.now().microsecondsSinceEpoch}-${_idRandom.nextInt(100000)}';
        current['id'] = id;
      }
      final previous = previousById[id];
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final fileUuid =
          previous?['fileUuid']?.toString().trim().isNotEmpty == true
          ? previous!['fileUuid'].toString().trim()
          : (current['fileUuid']?.toString().trim().isNotEmpty == true
                ? current['fileUuid'].toString().trim()
                : _newVaultId());

      final createdAt =
          previous?['createdAt']?.toString().trim().isNotEmpty == true
          ? previous!['createdAt'].toString().trim()
          : (current['createdAt']?.toString().trim().isNotEmpty == true
                ? current['createdAt'].toString().trim()
                : nowIso);

      final previousVersion = _entryVersion(previous);
      final currentVersion = _entryVersion(current);
      final changed = previous == null || _hasEntryChanged(previous, current);
      final version = previous == null
          ? (currentVersion > 0 ? currentVersion : 1)
          : (changed
                ? ((previousVersion > 0 ? previousVersion : 1) + 1)
                : (previousVersion > 0 ? previousVersion : 1));
      final updatedAt = changed
          ? nowIso
          : (previous['updatedAt']?.toString().trim().isNotEmpty == true
                ? previous['updatedAt'].toString().trim()
                : (current['updatedAt']?.toString().trim().isNotEmpty == true
                      ? current['updatedAt'].toString().trim()
                      : createdAt));
      final updatedByDevice = changed
          ? _deviceLabel
          : (previous['updatedByDevice']?.toString().trim().isNotEmpty == true
                ? previous['updatedByDevice'].toString().trim()
                : _deviceLabel);
      final entryDeviceId = changed
          ? _deviceId
          : (previous['deviceId']?.toString().trim().isNotEmpty == true
                ? previous['deviceId'].toString().trim()
                : _deviceId);

      current['fileUuid'] = fileUuid;
      current['version'] = version;
      current['createdAt'] = createdAt;
      current['updatedAt'] = updatedAt;
      current['updatedByDevice'] = updatedByDevice;
      current['deviceId'] = entryDeviceId;
      result.add(current);
    }
    return result;
  }

  int _entryVersion(Map<String, dynamic>? entry) {
    if (entry == null) return 0;
    final raw = entry['version'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  bool _hasEntryChanged(
    Map<String, dynamic> previous,
    Map<String, dynamic> current,
  ) {
    Map<String, dynamic> scrub(Map<String, dynamic> source) {
      final copy = Map<String, dynamic>.from(source);
      copy.remove('fileUuid');
      copy.remove('version');
      copy.remove('createdAt');
      copy.remove('updatedAt');
      copy.remove('updatedByDevice');
      copy.remove('deviceId');
      return copy;
    }

    return jsonEncode(scrub(previous)) != jsonEncode(scrub(current));
  }

  Future<void> _unlockWithRecoveryPhrase() async {
    if (!_storageReady) return;
    if (_isBusy) return;

    final importCompleter = _importCredentialCompleter;
    if (importCompleter != null) {
      if (!_importCredentialAllowRecovery) return;
      _importCredentialCompleter = null;
      _importCredentialAllowRecovery = true;
      if (!importCompleter.isCompleted) {
        importCompleter.complete(
          const _ImportVaultCredentialChoice.recoverWithPhrase(),
        );
      }
      return;
    }

    final recovery = await _promptRecoveryPhrase();
    if (recovery == null || recovery.isEmpty) return;
    if (!mounted) return;

    final normalizedRecovery = _normalizeRecoveryPhrase(recovery);
    if (!_validateRecoveryWords(normalizedRecovery)) return;
    if (_vaultCreatedInSession &&
        !listEquals(normalizedRecovery, _recoveryWords)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovery phrase order does not match.')),
      );
      return;
    }

    _startBusy('Starting recovery unlock...');
    try {
      await _vaultService
          .unlockVaultWithRecoveryPhrase(
            filePath: _vaultFilePath,
            recoveryPhrase: normalizedRecovery.join(' '),
            onProgress: _updateBusy,
          )
          .timeout(_vaultOpTimeout);
      if (!mounted) return;
      _stopBusy();
      final didReset = await _showMandatoryMasterPasswordReset(
        normalizedRecovery.join(' '),
      );
      if (!didReset || !mounted) return;
      _passwordController.clear();
      await _presentUnlockStep();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Recovery successful. Please log in with your new master password.',
          ),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovery timed out. Please try again.')),
      );
    } catch (error, stackTrace) {
      _logOperationError('unlockWithRecoveryPhrase', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovery phrase is invalid.')),
      );
    } finally {
      _stopBusy();
    }
  }

  Future<String?> _promptRecoveryPhrase() async {
    final recoveryController = TextEditingController();
    final recovery = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recover vault'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter all 12 words in exact order, separated by spaces.\n'
                'Example:\n'
                'anchor apple arrow atlas beacon breeze canyon cedar cobalt ember harbor willow',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: recoveryController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Recovery phrase',
                  hintText: '12 words separated by spaces',
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
              onPressed: () =>
                  Navigator.of(context).pop(recoveryController.text.trim()),
              child: const Text('Recover'),
            ),
          ],
        );
      },
    );
    await _waitForDialogTeardown();
    recoveryController.clear();
    recoveryController.dispose();
    return recovery;
  }

  List<String> _normalizeRecoveryPhrase(String recovery) {
    return recovery
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .map((word) => word.replaceAll(RegExp(r'[^a-z]'), ''))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  bool _validateRecoveryWords(List<String> normalizedRecovery) {
    if (normalizedRecovery.length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recovery phrase must be exactly 12 words.'),
        ),
      );
      return false;
    }
    final dictionary = RecoveryPhraseDictionary.words.toSet();
    final invalidWords = normalizedRecovery
        .where((word) => !dictionary.contains(word))
        .toList();
    if (invalidWords.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid recovery words: ${invalidWords.take(2).join(', ')}',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  void _startBusy(
    String message, {
    Duration timeout = _vaultOpTimeout,
    String timeoutMessage = 'Operation took too long. Please try again.',
  }) {
    if (!mounted) return;
    _busyWatchdog?.cancel();
    final runId = ++_busyRunId;
    _backgroundLockTimer?.cancel();
    _inactivityLockTimer?.cancel();
    setState(() {
      _isBusy = true;
      _busyProgress = 0.0;
      _busyMessage = message;
    });
    _busyWatchdog = Timer(timeout, () {
      if (!mounted || !_isBusy || runId != _busyRunId) return;
      _stopBusy();
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(timeoutMessage)));
    });
  }

  void _updateBusy(VaultOperationProgress progress) {
    if (!mounted) return;
    setState(() {
      _isBusy = true;
      _busyProgress = progress.value;
      _busyMessage = progress.message;
    });
  }

  void _updateBusyStep(String message, double progress) {
    _updateBusy(VaultOperationProgress(value: progress, message: message));
  }

  void _stopBusy() {
    if (!mounted) return;
    _busyWatchdog?.cancel();
    if (!_isBusy && _busyProgress == 0 && _busyMessage.isEmpty) {
      _scheduleLockAfterBusyChange();
      return;
    }
    setState(() {
      _isBusy = false;
      _busyProgress = 0;
      _busyMessage = '';
    });
    _scheduleLockAfterBusyChange();
  }

  void _scheduleLockAfterBusyChange() {
    if (_lastLifecycleState == AppLifecycleState.paused) {
      _scheduleBackgroundLockIfNeeded();
    } else {
      _scheduleInactivityLockIfNeeded();
    }
  }

  void _showOperationSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _waitForOverlayTeardown() async {
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
  }

  void _logOperationError(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!kDebugMode) return;
    debugPrint('[OnboardingFlow][$operation] ${error.runtimeType}');
    debugPrintStack(stackTrace: stackTrace);
  }

  String _errorHint(Object error) {
    final message = error.toString();
    if (message.contains('abortTrigger') ||
        message.contains('Request aborted')) {
      return 'Cloud request was interrupted. Stay on this tab and retry.';
    }
    if (message.contains('DetailedApiRequestError') &&
        message.contains('Invalid Value')) {
      return 'Google Drive rejected the backup search request. Retry in a moment.';
    }
    if (message.contains('TimeoutException') ||
        message.contains('Timed out while searching')) {
      return 'Cloud backup search timed out. Check your connection and retry.';
    }
    if (message.contains('DetailedApiRequestError') &&
        message.contains('insufficientPermissions')) {
      return 'Google Drive permissions are missing. Reconnect and allow Drive access.';
    }
    if (message.contains('ApiException: 10') ||
        message.contains('DEVELOPER_ERROR') ||
        message.contains('signed application') ||
        message.contains('selecting the google account')) {
      return 'Google sign-in is not configured for this app signature. Add the installed build SHA-1 (debug, release, or Play signing) to the Google Cloud Android OAuth client for com.nija, reinstall, then retry.';
    }
    if (message.contains('QuotaExceededError') ||
        message.contains('exceeded the quota')) {
      return 'This vault is too large for browser storage. Reload and retry after updating.';
    }
    if (message.contains('Google Drive is not connected') ||
        message.contains('allow Drive access')) {
      return 'Google Drive is not connected. Sign in again and allow Drive access.';
    }
    if (kDebugMode) {
      return '($error)';
    }
    return 'Please retry.';
  }

  Future<bool> _requestFileAccessConsent({
    required String title,
    required String message,
  }) async {
    if (!mounted) return false;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    await _waitForDialogTeardown();
    return decision == true;
  }

  Future<void> _syncKnownVaults() async {
    if (!_enableVaultReferenceCache || _isExploreDemoSession) return;
    final known = await _mergedKnownAndPrivateVaultReferences();
    if (!mounted || _isExploreDemoSession) return;
    if (listEquals(_knownVaults, known)) return;
    void apply() {
      if (!mounted || _isExploreDemoSession) return;
      setState(() {
        _knownVaults = known;
      });
    }

    if (kIsWeb) {
      _deferAfterPointer(apply);
      return;
    }
    apply();
  }

  Future<void> _restoreKnownVaultSession() async {
    await _syncKnownVaults();
  }

  Future<List<VaultReference>> _mergedKnownAndPrivateVaultReferences() async {
    final cached = await _vaultReferenceCache.readAll();
    final discovered = await _discoverPrivateVaultReferences();
    final byId = <String, VaultReference>{};
    for (final entry in discovered) {
      byId[entry.id] = entry;
    }
    for (final entry in cached) {
      byId[entry.id] = entry;
    }
    return byId.values.toList(growable: true)..sort((a, b) {
      final openCmp = b.lastOpenedAtEpochMs.compareTo(a.lastOpenedAtEpochMs);
      if (openCmp != 0) return openCmp;
      return b.addedAtEpochMs.compareTo(a.addedAtEpochMs);
    });
  }

  Future<List<VaultReference>> _discoverPrivateVaultReferences() async {
    if (kIsWeb) return const <VaultReference>[];
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final vaultsDir = Directory(
        '${docsDir.path}${Platform.pathSeparator}vaults',
      );
      if (!await vaultsDir.exists()) return const <VaultReference>[];
      final discovered = <VaultReference>[];
      await for (final entity in vaultsDir.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final vaultStoreId = entity.path.split(Platform.pathSeparator).last;
        if (vaultStoreId.isEmpty ||
            vaultStoreId.endsWith('.incoming') ||
            vaultStoreId.endsWith('.rollback')) {
          continue;
        }
        final headerFile = File(
          '${entity.path}${Platform.pathSeparator}header.json',
        );
        if (!await headerFile.exists()) continue;
        final reference = await _privateVaultReferenceFromHeader(
          vaultStoreId: vaultStoreId,
          headerFile: headerFile,
        );
        if (reference != null) discovered.add(reference);
      }
      return discovered;
    } catch (_) {
      return const <VaultReference>[];
    }
  }

  Future<VaultReference?> _privateVaultReferenceFromHeader({
    required String vaultStoreId,
    required File headerFile,
  }) async {
    try {
      final decoded = jsonDecode(await headerFile.readAsString());
      if (decoded is! Map) return null;
      final header = Map<String, dynamic>.from(decoded);
      final vaultId = header['vaultId']?.toString().trim() ?? '';
      final id = vaultId.isEmpty ? vaultStoreId : vaultId;
      final label = header['vaultName']?.toString().trim().isNotEmpty == true
          ? header['vaultName'].toString().trim()
          : id;
      final stat = await headerFile.stat();
      return VaultReference(
        id: id,
        label: label,
        addedAtEpochMs: stat.changed.millisecondsSinceEpoch,
        lastOpenedAtEpochMs: 0,
        sourceDescription: _defaultVaultSourceDescription(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _initializeLocalVaultPath() async {
    if (widget.vaultFilePath != null && widget.vaultFilePath!.isNotEmpty) {
      if (!mounted) return;
      setState(() => _storageReady = true);
      return;
    }
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final path = '${docsDir.path}/nija_vault.nija';
      _vaultService = DefaultVaultService(
        storageAdapter: const FileVaultStorageAdapter(),
        cryptoAdapter: SecureCryptoAdapter(),
        privateVaultStore: FilePrivateVaultStore(baseDirectory: docsDir),
        deviceId: _deviceId,
      );
      if (!mounted) return;
      setState(() {
        _vaultFilePath = path;
        _activeVaultName = _displayNameForVault(path);
        _storageReady = true;
      });
      _scheduleKnownVaultDiscovery();
      unawaited(_consumePendingSecretIntent());
      unawaited(_consumePendingSharedTextIntent());
    } catch (_) {
      _vaultService = DefaultVaultService(
        storageAdapter: const FileVaultStorageAdapter(),
        cryptoAdapter: SecureCryptoAdapter(),
        privateVaultStore: FilePrivateVaultStore(
          baseDirectory: Directory.current,
        ),
        deviceId: _deviceId,
      );
      if (!mounted) return;
      setState(() {
        _vaultFilePath = '${Directory.current.path}/nija_vault.nija';
        _activeVaultName = _displayNameForVault(_vaultFilePath);
        _storageReady = true;
      });
      _scheduleKnownVaultDiscovery();
      unawaited(_consumePendingSecretIntent());
      unawaited(_consumePendingSharedTextIntent());
    }
  }

  void _scheduleKnownVaultDiscovery() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_restoreKnownVaultSession());
    });
  }

  Future<void> _rememberVaultReference(
    String filePath, {
    String? label,
    String? sourceDescription,
  }) async {
    if (!_enableVaultReferenceCache) return;
    final previous = _findVaultReference(filePath);
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolvedLabel = label ?? await _resolveVaultLabel(filePath);
    final resolvedSource = sourceDescription?.trim().isNotEmpty == true
        ? sourceDescription!.trim()
        : previous?.sourceDescription.trim().isNotEmpty == true
        ? previous!.sourceDescription
        : _defaultVaultSourceDescription();
    final reference = VaultReference(
      id: filePath,
      label: resolvedLabel,
      addedAtEpochMs: previous?.addedAtEpochMs ?? now,
      lastOpenedAtEpochMs: previous?.lastOpenedAtEpochMs ?? 0,
      sourceDescription: resolvedSource,
    );
    await _vaultReferenceCache.upsert(reference);
    await _syncKnownVaults();
  }

  Future<void> _markVaultAsOpened(String filePath) async {
    if (!_enableVaultReferenceCache) return;
    final previous = _findVaultReference(filePath);
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolvedLabel = await _resolveVaultLabel(filePath);
    final reference = VaultReference(
      id: filePath,
      label: resolvedLabel,
      addedAtEpochMs: previous?.addedAtEpochMs ?? now,
      lastOpenedAtEpochMs: now,
      sourceDescription:
          previous?.sourceDescription ?? _defaultVaultSourceDescription(),
    );
    await _vaultReferenceCache.upsert(reference);
    await _syncKnownVaults();
  }

  String _sourceDescriptionForImportedVault(ImportedVaultFile imported) {
    final selectedFile = imported.sourceDescription.trim().isNotEmpty
        ? imported.sourceDescription.trim()
        : _displayNameForVault(imported.storageId);
    return '${_defaultVaultSourceDescription()} · '
        '${AppStrings.selectedVaultFile} $selectedFile';
  }

  String _defaultVaultSourceDescription() {
    return kIsWeb
        ? AppStrings.webVaultPrivateStorage
        : AppStrings.appVaultPrivateStorage;
  }

  VaultReference? _findVaultReference(String filePath) {
    for (final entry in _knownVaults) {
      if (entry.id == filePath) return entry;
    }
    return null;
  }

  String _displayNameForVault(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final parts = normalized.split('/');
    final last = parts.isEmpty ? normalized : parts.last;
    return last.isEmpty ? 'vault.nija' : last;
  }

  Future<String> _resolveVaultStoragePath(String candidate) async {
    final trimmed = candidate.trim();
    if (trimmed.isNotEmpty &&
        await _vaultService.vaultExists(filePath: trimmed)) {
      return trimmed;
    }

    if (kIsWeb) {
      const webHandle = 'web_vault.nija';
      if (trimmed != webHandle &&
          await _vaultService.vaultExists(filePath: webHandle)) {
        if (trimmed.isEmpty) return webHandle;
        try {
          final raw = await _vaultService.readRawVaultFile(filePath: webHandle);
          final decoded = jsonDecode(raw);
          if (decoded is Map && decoded['vaultId']?.toString() == trimmed) {
            return webHandle;
          }
        } catch (_) {
          // Ignore metadata read failures and keep searching other handles.
        }
      }
    }

    return trimmed.isEmpty ? _vaultFilePath : trimmed;
  }

  Future<String> _resolveVaultLabel(String filePath) async {
    try {
      final raw = await _vaultService.readRawVaultFile(filePath: filePath);
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final name = decoded['vaultName']?.toString().trim() ?? '';
      if (name.isNotEmpty) return name;
      final id = decoded['vaultId']?.toString().trim() ?? '';
      if (id.isNotEmpty) return id;
    } catch (_) {
      // Fallback to path-based label.
    }
    return _displayNameForVault(filePath);
  }

  void _prepareVaultDraft() {
    _draftVaultId = _newVaultId();
    _vaultNameController.text = _defaultVaultName;
    _biometricEnabled = false;
    _biometricPromptShown = false;
  }

  String _newVaultId() {
    final bytes = List<int>.generate(16, (_) => _idRandom.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<void> _initializeDeviceMetadata() async {
    _deviceLabel = _platformLabel();
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_prefsDeviceIdKey)?.trim() ?? '';
      if (existing.isNotEmpty) {
        _deviceId = existing;
        return;
      }
      final generated = _newVaultId();
      await prefs.setString(_prefsDeviceIdKey, generated);
      _deviceId = generated;
    } catch (_) {
      _deviceId = _newVaultId();
    }
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'desktop';
      case TargetPlatform.windows:
        return 'desktop';
      case TargetPlatform.linux:
        return 'desktop';
      case TargetPlatform.fuchsia:
        return 'desktop';
    }
  }

  Future<void> _importVaultFromLocal({required bool continueToUnlock}) async {
    try {
      final imported = await _vaultPortability.importVaultFromLocal();
      if (imported == null) return;
      final importedPath = await _localPathForImportedVault(imported);
      await _importVaultFile(
        imported: ImportedVaultFile(
          storageId: importedPath,
          label: imported.label,
          content: imported.content,
        ),
        continueToUnlock: continueToUnlock,
        stageRawContent: true,
      );
    } catch (error, stackTrace) {
      if (_isFilePickerCancellation(error)) return;
      _logOperationError('importVaultFromLocal', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.vaultImportFailed)));
    }
  }

  Future<void> _importVaultFromCloud({
    required bool continueToUnlock,
    OnboardingStep returnOnCancel = OnboardingStep.welcome,
  }) async {
    try {
      final signedIn = await _ensureCloudBackupGoogleAccountSelected();
      if (!signedIn || !mounted) return;

      _startBusy(
        'Checking cloud backups...',
        timeout: const Duration(minutes: 2),
        timeoutMessage:
            'Cloud import is still working. This can take longer on slow connections.',
      );
      final backups = await _vaultPortability.listCloudBackups(
        forceAccountChooser: false,
      );
      _stopBusy();
      if (!mounted) return;
      if (backups.isEmpty) {
        _showOperationSnackBar(
          'No cloud vault backups found. If you backed up on mobile, open Backup there once, then retry.',
        );
        return;
      }
      final selected = await _pickCloudBackupFromList(
        backups,
        title: AppStrings.importVaultFromCloud,
        returnOnCancel: returnOnCancel,
      );
      if (selected == null || !mounted) return;
      final hydrated = await _ensureCloudBackupContent(selected);
      if (!mounted) return;
      final importedPath = await _localPathForCloudBackup(hydrated);
      await _importVaultFile(
        imported: ImportedVaultFile(
          storageId: importedPath,
          label: cloudBackupDisplayTitle(hydrated),
          content: hydrated.content,
        ),
        continueToUnlock: continueToUnlock,
        stageRawContent: true,
      );
    } catch (error, stackTrace) {
      _stopBusy();
      _logOperationError('importVaultFromCloud', error, stackTrace);
      if (!mounted) return;
      _showOperationSnackBar(
        'Failed to import cloud vault. ${_errorHint(error)}',
      );
    }
  }

  Future<bool> _ensureCloudBackupGoogleAccountSelected() async {
    if (kIsWeb) {
      final selected = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (context) =>
            const GoogleDriveWebSignInDialog(forceAccountChooser: true),
      );
      if (selected != true && mounted) {
        _showOperationSnackBar(
          'Google sign-in cancelled. If the button fails, add http://localhost '
          'and http://localhost:5173 to Authorized JavaScript origins in Google Cloud Console.',
        );
      }
      if (selected != true) return false;
      const drivePortability = GoogleDriveVaultPortability();
      final ready = await drivePortability.ensureDriveSessionReady();
      if (!ready && mounted) {
        _showOperationSnackBar(
          'Google Drive access was not granted. Sign in again and allow Drive access.',
        );
      }
      return ready;
    }

    final selected = await _vaultPortability.ensureCloudBackupAccountSelected(
      forceAccountChooser: true,
    );
    if (!selected && mounted) {
      _showOperationSnackBar('Google account sign-in cancelled.');
    }
    return selected;
  }

  Future<CloudVaultBackupFile?> _pickCloudBackupFromList(
    List<CloudVaultBackupFile> backups, {
    required String title,
    required OnboardingStep returnOnCancel,
  }) async {
    if (backups.isEmpty || !mounted) return null;

    final openedFromKnownVaultPicker =
        _step == OnboardingStep.selectVault &&
        _vaultSelectionMode == _VaultSelectionMode.known;
    final completer = Completer<CloudVaultBackupFile?>();
    setState(() {
      _cloudBackupsByStorageId = {
        for (final backup in backups) backup.storageId: backup,
      };
      _cloudVaultReferences = backups
          .map(_vaultReferenceForCloudBackup)
          .toList(growable: false);
      _cloudVaultSelectionHeading = title;
      _vaultSelectionMode = _VaultSelectionMode.cloudBackup;
      if (openedFromKnownVaultPicker) {
        _cloudPickerOuterReturnStep = _selectVaultReturnStep;
      } else {
        _cloudPickerOuterReturnStep = null;
        _selectVaultReturnStep = returnOnCancel;
      }
      _cloudBackupPickerCompleter = completer;
      _stepTransitionForward = true;
      _step = OnboardingStep.selectVault;
    });
    return completer.future;
  }

  void _clearImportCredentialUi() {
    _importCredentialCompleter = null;
    _importCredentialAllowRecovery = true;
  }

  Future<void> _stageImportedVaultForUnlock({
    required String storageId,
    required String vaultLabel,
  }) async {
    final storagePath = await _resolveVaultStoragePath(storageId);
    if (!mounted) return;
    setState(() {
      _vaultFilePath = storagePath;
      _activeVaultName = vaultLabel;
    });
  }

  Future<void> _importVaultFile({
    required ImportedVaultFile imported,
    required bool continueToUnlock,
    required bool stageRawContent,
  }) async {
    if (stageRawContent) {
      await _vaultService.writeRawVaultFile(
        filePath: imported.storageId,
        rawContent: imported.content,
      );
    }
    final selectedVaultLabel = _humanImportLabel(imported);
    await _stageImportedVaultForUnlock(
      storageId: imported.storageId,
      vaultLabel: selectedVaultLabel,
    );
    if (!mounted) return;

    try {
      var credential = _passwordController.text.trim();
      if (credential.isEmpty) {
        final prompted = await _promptImportVaultCredential(
          vaultLabel: selectedVaultLabel,
          message: 'Selected vault: $selectedVaultLabel',
        );
        if (prompted == null) return;
        if (prompted.recoverWithPhrase) {
          await _recoverImportedVault(
            imported: imported,
            selectedVaultLabel: selectedVaultLabel,
            continueToUnlock: continueToUnlock,
          );
          return;
        }
        if (prompted.password.isEmpty) return;
        credential = prompted.password;
      }

      _startBusy('Importing vault...');
      var result = await _vaultService.importNijaFile(
        filePath: imported.storageId,
        unlockCredential: credential,
      );
      if (result.status == ImportStatus.failed) {
        _stopBusy();
        final prompted = await _promptImportVaultCredential(
          vaultLabel: selectedVaultLabel,
          title: AppStrings.unlockImportedVaultTitle,
          message:
              'Selected vault: $selectedVaultLabel\n\nThe selected file did not unlock with the active vault password. Enter the password that was valid when this file was exported.',
        );
        if (prompted == null) {
          throw StateError(result.userSafeMessage);
        }
        if (prompted.recoverWithPhrase) {
          await _recoverImportedVault(
            imported: imported,
            selectedVaultLabel: selectedVaultLabel,
            continueToUnlock: continueToUnlock,
          );
          return;
        }
        if (prompted.password.isEmpty || prompted.password == credential) {
          throw StateError(result.userSafeMessage);
        }
        credential = prompted.password;
        _startBusy('Importing vault...');
        result = await _vaultService.importNijaFile(
          filePath: imported.storageId,
          unlockCredential: credential,
        );
      }
      if (result.status == ImportStatus.failed &&
          result.userSafeMessage.contains('Confirm replace')) {
        _stopBusy();
        final replace = await _confirmReplaceNewerImportedVault(result);
        if (replace) {
          _startBusy('Importing vault...');
          result = await _vaultService.importNijaFile(
            filePath: imported.storageId,
            unlockCredential: credential,
            confirmReplace: true,
          );
        }
      }
      if (result.status == ImportStatus.failed) {
        throw StateError(result.userSafeMessage);
      }
      if (result.status == ImportStatus.alreadyUpToDate ||
          result.status == ImportStatus.incomingOlder) {
        if (!mounted) return;
        if (continueToUnlock && result.vaultId.isNotEmpty) {
          final resolvedLabel = await _resolveVaultLabel(result.vaultId);
          final importedLabel = resolvedLabel == result.vaultId
              ? selectedVaultLabel
              : resolvedLabel;
          await _rememberVaultReference(
            result.vaultId,
            label: importedLabel,
            sourceDescription: _sourceDescriptionForImportedVault(imported),
          );
          if (!mounted) return;
          setState(() {
            _vaultFilePath = result.vaultId;
            _activeVaultName = importedLabel;
            _vaultCreatedInSession = false;
            _clearImportCredentialUi();
          });
          _passwordController.text = credential;
          await _loadVaultData(credential);
          await _refreshBiometricStateForActiveVault();
          if (!mounted) return;
          _handleUnlock();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result.userSafeMessage)));
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.userSafeMessage)));
        return;
      }
      if (result.status == ImportStatus.conflictCreated) {
        final conflictVaultId = result.conflictVaultId;
        if (conflictVaultId == null || conflictVaultId.isEmpty) {
          throw StateError('Conflict import did not return conflict vault id.');
        }
        await _reviewAndMergeVaultConflict(
          conflictVaultId: conflictVaultId,
          importedPassword: credential,
        );
        return;
      }
      final activeId = result.conflictVaultId ?? result.vaultId;
      final resolvedLabel = await _resolveVaultLabel(activeId);
      final importedLabel = result.status == ImportStatus.conflictCreated
          ? 'Vault conflict copy'
          : resolvedLabel == activeId
          ? selectedVaultLabel
          : resolvedLabel;
      await _resetBiometricForVault(activeId);
      await _rememberVaultReference(
        activeId,
        label: importedLabel,
        sourceDescription: _sourceDescriptionForImportedVault(imported),
      );
      if (!mounted) return;
      setState(() {
        _vaultFilePath = activeId;
        _activeVaultName = importedLabel;
        _vaultCreatedInSession = false;
        _clearImportCredentialUi();
      });
      if (continueToUnlock) {
        _passwordController.text = credential;
        await _loadVaultData(credential);
        await _refreshBiometricStateForActiveVault();
        if (!mounted) return;
        _handleUnlock();
      } else {
        await _refreshVaultSize();
        await _refreshBiometricStateForActiveVault();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.userSafeMessage.trim().isEmpty
                ? AppStrings.vaultImportedSuccess
                : result.userSafeMessage,
          ),
        ),
      );
    } finally {
      _stopBusy();
      if (mounted) {
        setState(_clearImportCredentialUi);
      }
    }
  }

  Future<void> _recoverImportedVault({
    required ImportedVaultFile imported,
    required String selectedVaultLabel,
    required bool continueToUnlock,
  }) async {
    final recoveryPhrase = await _promptRecoveryPhrase();
    if (recoveryPhrase == null) return;
    final normalizedRecovery = _normalizeRecoveryPhrase(recoveryPhrase);
    if (!_validateRecoveryWords(normalizedRecovery)) return;

    _startBusy('Starting imported vault recovery...');
    try {
      await _vaultService
          .unlockVaultWithRecoveryPhrase(
            filePath: imported.storageId,
            recoveryPhrase: normalizedRecovery.join(' '),
            onProgress: _updateBusy,
          )
          .timeout(_vaultOpTimeout);
      if (!mounted) return;
      _stopBusy();
      final didReset = await _showMandatoryMasterPasswordReset(
        normalizedRecovery.join(' '),
        filePath: imported.storageId,
      );
      if (!didReset || !mounted) return;
      final newPassword = _passwordController.text.trim();
      final result = await _vaultService.importNijaFile(
        filePath: imported.storageId,
        unlockCredential: newPassword,
      );
      if (result.status == ImportStatus.failed) {
        throw StateError(result.userSafeMessage);
      }
      final activeId = result.conflictVaultId ?? result.vaultId;
      final resolvedLabel = await _resolveVaultLabel(activeId);
      final importedLabel = resolvedLabel == activeId
          ? selectedVaultLabel
          : resolvedLabel;
      await _resetBiometricForVault(activeId);
      await _rememberVaultReference(
        activeId,
        label: importedLabel,
        sourceDescription: _sourceDescriptionForImportedVault(imported),
      );
      if (!mounted) return;
      setState(() {
        _vaultFilePath = activeId;
        _activeVaultName = importedLabel;
        _vaultCreatedInSession = false;
      });
      if (continueToUnlock) {
        _passwordController.text = newPassword;
        await _loadVaultData(newPassword);
        await _refreshBiometricStateForActiveVault();
        if (!mounted) return;
        _handleUnlock();
      } else {
        await _refreshVaultSize();
        await _refreshBiometricStateForActiveVault();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovery successful. Vault opened.')),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovery timed out. Please try again.')),
      );
    } catch (error, stackTrace) {
      _logOperationError('recoverImportedVault', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovery phrase is invalid.')),
      );
    } finally {
      _stopBusy();
    }
  }

  String _humanImportLabel(ImportedVaultFile imported) {
    final label = imported.label.trim();
    if (label.isNotEmpty) return label;
    final storageName = _displayNameForVault(imported.storageId);
    final withoutExtension = storageName.toLowerCase().endsWith('.nija')
        ? storageName.substring(0, storageName.length - 5)
        : storageName;
    final humanized = withoutExtension
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return humanized.isEmpty ? 'Imported vault' : humanized;
  }

  bool _isFilePickerCancellation(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('cancel') || text.contains('abort');
  }

  Future<void> _reviewAndMergeVaultConflict({
    required String conflictVaultId,
    required String importedPassword,
    String? resolvedVaultVersionId,
    bool askBackupAfterMerge = false,
    String importedSourceLabel = 'Imported vault',
  }) async {
    final currentPassword = await _activeVaultPasswordForMerge();
    if (currentPassword == null || currentPassword.isEmpty) return;
    var busyActive = false;
    void startMergeBusy(String message) {
      _startBusy(
        message,
        timeout: const Duration(minutes: 2),
        timeoutMessage:
            'Vault merge is still working. Large vaults can take longer.',
      );
      busyActive = true;
    }

    void stopMergeBusy() {
      if (!busyActive) return;
      _stopBusy();
      busyActive = false;
    }

    try {
      startMergeBusy('Preparing vault merge...');
      _updateBusyStep('Reading current vault...', 0.15);
      final currentPayload = await _vaultService.readVaultPayload(
        filePath: _vaultFilePath,
        password: currentPassword,
      );
      _updateBusyStep('Reading imported vault...', 0.35);
      final importedPayload = await _vaultService.readVaultPayload(
        filePath: conflictVaultId,
        password: importedPassword,
      );
      _updateBusyStep('Comparing vault versions...', 0.55);
      final plan = _vaultMergeHelper.buildPlan(
        current: currentPayload,
        imported: importedPayload,
      );
      if (plan.conflictCount == 0) {
        final mergedPayload = _vaultMergeHelper.merge(
          current: currentPayload,
          imported: importedPayload,
          selections: const <String, VaultMergeSource>{},
        );
        await _applyMergedVaultPayload(
          payload: mergedPayload,
          password: currentPassword,
          resolvedVaultVersionId: resolvedVaultVersionId,
          progressStart: 0.70,
        );
        stopMergeBusy();
        if (!mounted) return;
        _showOperationSnackBar(
          'Same vault detected. Non-conflicting changes were merged automatically. Please review if needed.',
        );
        if (askBackupAfterMerge) {
          await _confirmBackupAfterCloudMerge();
        }
        return;
      }
      stopMergeBusy();
      if (!mounted) return;
      final mergedPayload = await Navigator.of(context).push<VaultPayload>(
        MaterialPageRoute<VaultPayload>(
          builder: (context) => _VaultMergeScreen(
            plan: plan,
            currentPayload: currentPayload,
            importedPayload: importedPayload,
            mergeHelper: _vaultMergeHelper,
            importedSourceLabel: importedSourceLabel,
          ),
        ),
      );
      if (mergedPayload == null) {
        if (!mounted) return;
        _showOperationSnackBar('Vault merge cancelled.');
        return;
      }

      startMergeBusy('Applying vault merge...');
      await _applyMergedVaultPayload(
        payload: mergedPayload,
        password: currentPassword,
        resolvedVaultVersionId: resolvedVaultVersionId,
      );
      stopMergeBusy();
      if (!mounted) return;
      _showOperationSnackBar('Vault merged successfully.');
      if (askBackupAfterMerge) {
        await _confirmBackupAfterCloudMerge();
      }
    } catch (error, stackTrace) {
      stopMergeBusy();
      _logOperationError('reviewAndMergeVaultConflict', error, stackTrace);
      if (!mounted) return;
      _showOperationSnackBar('Failed to merge vault. ${_errorHint(error)}');
    }
  }

  Future<void> _applyMergedVaultPayload({
    required VaultPayload payload,
    required String password,
    String? resolvedVaultVersionId,
    double progressStart = 0.20,
  }) async {
    _updateBusyStep('Saving merged vault...', progressStart);
    await _vaultService.persistVaultPayload(
      filePath: _vaultFilePath,
      password: password,
      payload: payload,
    );
    if (resolvedVaultVersionId != null && resolvedVaultVersionId.isNotEmpty) {
      _updateBusyStep('Marking conflict resolved...', progressStart + 0.25);
      await _vaultService.markVaultConflictResolved(
        filePath: _vaultFilePath,
        resolvedVaultVersionId: resolvedVaultVersionId,
      );
    }
    _updateBusyStep('Reloading merged vault...', 0.85);
    await _loadVaultData(password);
    _updateBusyStep('Refreshing vault size...', 0.95);
    await _refreshVaultSize();
  }

  Future<String?> _activeVaultPasswordForMerge() async {
    final activePassword = _passwordController.text.trim();
    if (activePassword.isNotEmpty) return activePassword;
    final unlocked = await _ensureAuthenticatedVaultSessionForAction(
      actionLabel: 'Merge vault',
    );
    if (!unlocked || !mounted) return null;
    return _passwordController.text.trim();
  }

  Future<void> _exportCurrentVaultToLocal({
    required bool setAsActiveLocation,
  }) async {
    final approved = await _requestFileAccessConsent(
      title: 'Allow vault export',
      message:
          'Nija needs temporary file access to let you choose where to save your encrypted vault file. '
          'Only the selected output file is written.',
    );
    if (!approved) return;
    try {
      final exportName = await _promptExportFileName(
        initialName: _defaultVaultExportName(),
      );
      if (exportName == null) return;
      await _waitForDialogTeardown();
      if (!mounted) return;
      final rawContent = await _vaultService.readRawVaultFile(
        filePath: _vaultFilePath,
      );
      final exportedPath = await _vaultPortability.exportVaultToLocal(
        suggestedName: exportName,
        content: rawContent,
      );
      if (exportedPath != null &&
          exportedPath.isNotEmpty &&
          exportedPath != '__web_download__' &&
          setAsActiveLocation) {
        final sourceDescription =
            _findVaultReference(_vaultFilePath)?.sourceDescription ??
            _defaultVaultSourceDescription();
        _vaultFilePath = exportedPath;
        await _rememberVaultReference(
          exportedPath,
          sourceDescription: sourceDescription,
        );
        await _refreshBiometricStateForActiveVault();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exportedPath != null && exportedPath.isNotEmpty
                ? AppStrings.vaultExportedSuccess
                : AppStrings.vaultExportCancelled,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logOperationError('exportCurrentVaultToLocal', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.vaultExportFailed)));
    }
  }

  Future<void> _backupCurrentVaultToCloud() async {
    var busyActive = false;
    void startCloudBusy(String message) {
      _startBusy(
        message,
        timeout: const Duration(minutes: 2),
        timeoutMessage:
            'Cloud backup is taking longer than expected. Please check your connection and retry.',
      );
      busyActive = true;
    }

    void stopCloudBusy() {
      if (!busyActive) return;
      _stopBusy();
      busyActive = false;
    }

    try {
      final signedIn = await _ensureCloudBackupGoogleAccountSelected();
      if (!signedIn || !mounted) return;

      startCloudBusy('Preparing cloud backup...');
      final rawContent = await _vaultService.readRawVaultFile(
        filePath: _vaultFilePath,
      );
      _updateBusyStep('Reading vault metadata...', 0.15);
      final decoded = Map<String, dynamic>.from(jsonDecode(rawContent) as Map);
      final vaultId = decoded['vaultId']?.toString().trim() ?? '';
      if (vaultId.isEmpty) {
        throw StateError('Vault metadata is missing vaultId');
      }
      final now = DateTime.now();
      final stamp =
          '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final baseName = _defaultVaultExportName().replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final suggestedName = 'backup_${stamp}_$baseName';
      _updateBusyStep('Checking cloud backup status...', 0.30);
      final existingBackup = await _vaultPortability.readCloudBackup(
        vaultId: vaultId,
        forceAccountChooser: false,
      );
      stopCloudBusy();
      var shouldContinue = true;
      var uploadContent = rawContent;
      if (existingBackup != null) {
        final result = await _importCloudBackupForMerge(
          backup: existingBackup,
          askBackupAfterMerge: true,
        );
        shouldContinue = result != _CloudMergeOutcome.cancelled;
        if (shouldContinue) {
          uploadContent = await _vaultService.readRawVaultFile(
            filePath: _vaultFilePath,
          );
        }
      }
      if (!shouldContinue) return;
      startCloudBusy('Uploading cloud backup...');
      final finalContent = uploadContent;
      _updateBusyStep('Sending vault to cloud storage...', 0.55);
      final backedUp = await _vaultPortability.backupVaultToCloud(
        vaultId: vaultId,
        suggestedName: suggestedName,
        content: finalContent,
        forceAccountChooser: false,
      );
      _updateBusyStep('Finishing cloud backup...', 0.95);
      stopCloudBusy();
      if (!mounted) return;
      if (!backedUp) {
        _showOperationSnackBar('Cloud backup cancelled.');
        return;
      }
      _showOperationSnackBar('Cloud backup completed.');
    } catch (error, stackTrace) {
      stopCloudBusy();
      _logOperationError('backupCurrentVaultToCloud', error, stackTrace);
      if (!mounted) return;
      _showOperationSnackBar(
        'Failed to prepare cloud backup. ${_errorHint(error)}',
      );
    } finally {
      stopCloudBusy();
    }
  }

  Future<void> _restoreCurrentVaultFromCloud() async {
    var busyActive = false;
    void startCloudBusy(String message) {
      _startBusy(
        message,
        timeout: const Duration(minutes: 2),
        timeoutMessage:
            'Cloud restore is still working. This can take longer on slow connections.',
      );
      busyActive = true;
    }

    void stopCloudBusy() {
      if (!busyActive) return;
      _stopBusy();
      busyActive = false;
    }

    try {
      final signedIn = await _ensureCloudBackupGoogleAccountSelected();
      if (!signedIn || !mounted) return;

      startCloudBusy('Preparing cloud restore...');
      final rawContent = await _vaultService.readRawVaultFile(
        filePath: _vaultFilePath,
      );
      _updateBusyStep('Reading vault metadata...', 0.20);
      final decoded = Map<String, dynamic>.from(jsonDecode(rawContent) as Map);
      final vaultId = decoded['vaultId']?.toString().trim() ?? '';
      if (vaultId.isEmpty) {
        throw StateError('Vault metadata is missing vaultId');
      }
      _updateBusyStep('Downloading cloud backup...', 0.45);
      var backup = await _vaultPortability.readCloudBackup(
        vaultId: vaultId,
        forceAccountChooser: false,
      );
      if (backup == null) {
        _updateBusyStep('Searching all cloud backups...', 0.60);
        final allBackups = await _vaultPortability.listCloudBackups(
          forceAccountChooser: false,
        );
        stopCloudBusy();
        if (allBackups.isEmpty) {
          if (!mounted) return;
          _showOperationSnackBar(
            'No cloud backup found. If you backed up on mobile, open Backup there once, then retry.',
          );
          return;
        }
        backup = await _pickCloudBackupFromList(
          allBackups,
          title: AppStrings.importVaultFromCloud,
          returnOnCancel: OnboardingStep.app,
        );
        if (backup == null || !mounted) return;
      } else {
        _updateBusyStep('Preparing backup restore...', 0.75);
        stopCloudBusy();
      }
      await _importCloudBackupForMerge(
        backup: backup,
        askBackupAfterMerge: false,
      );
    } catch (error, stackTrace) {
      stopCloudBusy();
      _logOperationError('restoreCurrentVaultFromCloud', error, stackTrace);
      if (!mounted) return;
      _showOperationSnackBar(
        'Failed to restore cloud backup. ${_errorHint(error)}',
      );
    } finally {
      stopCloudBusy();
    }
  }

  Future<CloudVaultBackupFile> _ensureCloudBackupContent(
    CloudVaultBackupFile backup,
  ) async {
    if (backup.hasContent) return backup;
    _startBusy(
      'Downloading cloud backup...',
      timeout: const Duration(minutes: 2),
      timeoutMessage:
          'Cloud import is still working. This can take longer on slow connections.',
    );
    try {
      return await _vaultPortability.hydrateCloudBackupContent(backup);
    } finally {
      _stopBusy();
    }
  }

  Future<_CloudMergeOutcome> _importCloudBackupForMerge({
    required CloudVaultBackupFile backup,
    required bool askBackupAfterMerge,
  }) async {
    final hydrated = await _ensureCloudBackupContent(backup);
    final backupFilePath = await _localPathForCloudBackup(hydrated);
    await _vaultService.writeRawVaultFile(
      filePath: backupFilePath,
      rawContent: hydrated.content,
    );
    var credential = _passwordController.text.trim();
    if (credential.isEmpty) {
      final prompted = await _promptImportVaultCredential(
        title: 'Unlock cloud backup',
        allowRecovery: false,
      );
      if (prompted == null || prompted.password.isEmpty) {
        return _CloudMergeOutcome.cancelled;
      }
      credential = prompted.password;
    }
    var result = await _vaultService.importNijaFile(
      filePath: backupFilePath,
      unlockCredential: credential,
    );
    if (_cloudImportNeedsReplaceConfirmation(result)) {
      final replace = await _confirmReplaceNewerImportedVault(result);
      if (!replace) return _CloudMergeOutcome.cancelled;
      result = await _vaultService.importNijaFile(
        filePath: backupFilePath,
        unlockCredential: credential,
        confirmReplace: true,
      );
    }
    if (result.status == ImportStatus.failed) {
      final prompted = await _promptImportVaultCredential(
        title: 'Unlock cloud backup',
        message:
            'The cloud backup did not unlock with the active vault password. Enter the password that was valid when it was backed up.',
        allowRecovery: false,
      );
      if (prompted == null ||
          prompted.password.isEmpty ||
          prompted.password == credential) {
        return _CloudMergeOutcome.cancelled;
      }
      credential = prompted.password;
      result = await _vaultService.importNijaFile(
        filePath: backupFilePath,
        unlockCredential: credential,
      );
      if (_cloudImportNeedsReplaceConfirmation(result)) {
        final replace = await _confirmReplaceNewerImportedVault(result);
        if (!replace) return _CloudMergeOutcome.cancelled;
        result = await _vaultService.importNijaFile(
          filePath: backupFilePath,
          unlockCredential: credential,
          confirmReplace: true,
        );
      }
    }
    if (result.status == ImportStatus.alreadyUpToDate) {
      if (!mounted) return _CloudMergeOutcome.cancelled;
      _showOperationSnackBar(result.userSafeMessage);
      return _CloudMergeOutcome.noMergeNeeded;
    }
    if (result.status == ImportStatus.imported) {
      final activeId = result.vaultId;
      final restoredLabel = await _resolveVaultLabel(activeId);
      await _resetBiometricForVault(activeId);
      await _rememberVaultReference(
        activeId,
        label: restoredLabel,
        sourceDescription: AppStrings.googleDriveBackup,
      );
      if (!mounted) return _CloudMergeOutcome.cancelled;
      setState(() {
        _vaultFilePath = activeId;
        _activeVaultName = restoredLabel;
        _vaultCreatedInSession = false;
      });
      _passwordController.text = credential;
      await _loadVaultData(credential);
      await _refreshVaultSize();
      await _refreshBiometricStateForActiveVault();
      if (!mounted) return _CloudMergeOutcome.cancelled;
      _showOperationSnackBar('Cloud backup restored.');
      return _CloudMergeOutcome.noMergeNeeded;
    }
    if (result.status == ImportStatus.conflictCreated) {
      final conflictVaultId = result.conflictVaultId;
      if (conflictVaultId == null || conflictVaultId.isEmpty) {
        return _CloudMergeOutcome.cancelled;
      }
      await _reviewAndMergeVaultConflict(
        conflictVaultId: conflictVaultId,
        importedPassword: credential,
        resolvedVaultVersionId: await _vaultVersionIdFromRaw(hydrated.content),
        askBackupAfterMerge: askBackupAfterMerge,
        importedSourceLabel: 'Cloud backup',
      );
      return _CloudMergeOutcome.merged;
    }
    if (!mounted) return _CloudMergeOutcome.cancelled;
    _showOperationSnackBar(result.userSafeMessage);
    return _CloudMergeOutcome.cancelled;
  }

  bool _cloudImportNeedsReplaceConfirmation(ImportResult result) {
    return result.status == ImportStatus.failed &&
        result.userSafeMessage.contains('Confirm replace');
  }

  Future<String> _localPathForCloudBackup(CloudVaultBackupFile backup) async {
    final contentName = backup.hasContent
        ? _importStagingNameFromRaw(backup.content)
        : '';
    final fallbackName = backup.storageId
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final safeName = contentName.isNotEmpty ? contentName : fallbackName;
    if (kIsWeb) return safeName;
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/$safeName';
  }

  Future<String> _localPathForImportedVault(ImportedVaultFile imported) async {
    final contentName = _importStagingNameFromRaw(imported.content);
    final fallbackName = imported.storageId
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final safeName = contentName.isNotEmpty ? contentName : fallbackName;
    if (kIsWeb) return safeName;
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/$safeName';
  }

  String _importStagingNameFromRaw(String raw) {
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final vaultId = decoded['vaultId']?.toString().trim() ?? '';
      final versionId = decoded['vaultVersionId']?.toString().trim() ?? '';
      final base = [vaultId, versionId]
          .where((part) => part.isNotEmpty)
          .join('-')
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      if (base.isEmpty) return '';
      return 'import_$base.nija';
    } catch (_) {
      return '';
    }
  }

  Future<String?> _vaultVersionIdFromRaw(String raw) async {
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return decoded['vaultVersionId']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmBackupAfterCloudMerge() async {
    if (!mounted) return;
    final backupNow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup merged vault?'),
        content: const Text(
          'The cloud version was merged into this vault. Back up now so the same conflict is not shown again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Backup now'),
          ),
        ],
      ),
    );
    if (backupNow == true) {
      await _backupCurrentVaultToCloud();
    }
  }

  Future<String?> _readCloudBackupAccountLabel() {
    return _vaultPortability.getCloudBackupAccountLabel();
  }

  Future<bool> _changeCloudBackupAccount() {
    return _ensureCloudBackupGoogleAccountSelected();
  }

  Future<void> _refreshVaultSize() async {
    var size = 0;
    var revision = 0;
    var versionId = '';
    var updatedAt = '';

    try {
      size = await _vaultService.readVaultSizeBytes(filePath: _vaultFilePath);
    } catch (_) {
      size = 0;
    }

    try {
      final raw = await _vaultService.readRawVaultFile(
        filePath: _vaultFilePath,
      );
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        revision = int.tryParse(decoded['revision']?.toString() ?? '') ?? 0;
        versionId = decoded['vaultVersionId']?.toString().trim() ?? '';
        updatedAt = decoded['updatedAt']?.toString().trim() ?? '';
      }
    } catch (_) {
      revision = 0;
      versionId = '';
      updatedAt = '';
    }

    if (!mounted) return;
    setState(() {
      _activeVaultSizeBytes = size;
      _activeVaultRevision = revision;
      _activeVaultVersionId = versionId;
      _activeVaultUpdatedAt = updatedAt;
    });
  }

  Future<Map<String, dynamic>> _readVaultInternals() async {
    return _vaultService.readVaultInternals(filePath: _vaultFilePath);
  }

  Future<String?> _promptExportFileName({required String initialName}) async {
    final normalized = initialName.trim().isEmpty
        ? 'vault.nija'
        : initialName.trim();
    final defaultName = normalized.toLowerCase().endsWith('.nija')
        ? normalized
        : '$normalized.nija';
    final controller = TextEditingController(text: defaultName);
    try {
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setLocalState) {
            final canContinue = controller.text.trim().isNotEmpty;
            return AlertDialog(
              title: const Text('Export file name'),
              content: TextField(
                controller: controller,
                autofocus: true,
                onChanged: (_) => setLocalState(() {}),
                decoration: const InputDecoration(
                  labelText: 'File name',
                  hintText: 'my_vault.nija',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canContinue
                      ? () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final raw = controller.text.trim();
                          final ensured = raw.toLowerCase().endsWith('.nija')
                              ? raw
                              : '$raw.nija';
                          Navigator.of(context).pop(ensured);
                        }
                      : null,
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        ),
      );
      await _waitForDialogTeardown();
      return selected;
    } finally {
      controller.dispose();
    }
  }

  String _defaultVaultExportName() {
    final visibleName = _activeVaultName.trim().isNotEmpty
        ? _activeVaultName.trim()
        : _displayNameForVault(_vaultFilePath);
    final withoutExtension = visibleName.toLowerCase().endsWith('.nija')
        ? visibleName.substring(0, visibleName.length - 5)
        : visibleName;
    final safeName = withoutExtension
        .replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final baseName = safeName.isEmpty ? 'vault' : safeName;
    return '$baseName.nija';
  }

  Future<void> _waitForDialogTeardown() async {
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<_ImportVaultCredentialChoice?> _promptImportVaultCredential({
    String? title,
    String? message,
    String? vaultLabel,
    bool allowRecovery = true,
  }) async {
    if (!mounted) return null;
    final completer = Completer<_ImportVaultCredentialChoice?>();
    _importCredentialCompleter = completer;
    _importCredentialAllowRecovery = allowRecovery;

    if (_step != OnboardingStep.unlock) {
      await _presentUnlockStep(vaultLabel: vaultLabel);
    } else if (mounted) {
      setState(() {
        if (vaultLabel != null && vaultLabel.trim().isNotEmpty) {
          _activeVaultName = vaultLabel.trim();
        }
      });
    }

    return completer.future;
  }

  Future<bool> _confirmReplaceNewerImportedVault(ImportResult result) async {
    if (!mounted) return false;
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace local vault?'),
        content: Text(
          'The imported vault has a newer revision '
          '(${result.incomingRevision}) than your local copy '
          '(${result.localRevision}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return decision == true;
  }

  void _clearSensitiveSessionState() {
    final vaultPath = _vaultFilePath.trim();
    if (vaultPath.isNotEmpty) {
      _vaultService.clearUnlockedSession(filePath: vaultPath);
    }
    _passwordController.clear();
    _sessionMasterPassword = null;
    _biometricAuthService.clearWebAuthentication();
  }

  Future<void> _resetBiometricForVault(String vaultId) async {
    try {
      await Future.wait<void>([
        _pinCredentialStore.remove(vaultId: vaultId),
        _biometricCredentialStore.removeMasterPassword(vaultId: vaultId),
        _biometricEnrollmentStore.setEnrolledForVault(
          vaultId: vaultId,
          enrolled: false,
        ),
      ]).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Biometric cleanup should not block vault creation, import, or unlock.
    }
    if (!mounted || vaultId != _vaultFilePath) return;
    setState(() {
      _pinEnabled = false;
      _biometricEnabled = false;
    });
  }

  Future<void> _enableBiometricForCurrentVault() async {
    final vaultId = _vaultFilePath;
    if (kIsWeb) {
      final pin = await _ensurePinForCurrentVault();
      if (pin == null || !mounted || _vaultFilePath != vaultId) {
        await _refreshBiometricStateForActiveVault();
        return;
      }
      final webAuthnSupported = await _biometricAuthService
          .canAttemptWebBiometricEnrollment();
      if (!webAuthnSupported) {
        if (!mounted || _vaultFilePath != vaultId) return;
        await showWebBiometricUnavailableDialog(
          context,
          reason: WebBiometricUnavailableReason.browserUnsupported,
        );
        await _refreshBiometricStateForActiveVault();
        return;
      }
      if (!mounted || _vaultFilePath != vaultId) return;
      final enabled = await showWebBiometricEnableDialog(
        context,
        onConfirm: () => _biometricCredentialStore.saveMasterPassword(
          vaultId: vaultId,
          password: pin,
          displayName: _activeVaultName,
          newEnrollment: true,
        ),
      );
      if (!enabled || !mounted || _vaultFilePath != vaultId) {
        await _refreshBiometricStateForActiveVault();
        return;
      }
      await _biometricEnrollmentStore.setEnrolledForVault(
        vaultId: vaultId,
        enrolled: true,
      );
      await _refreshBiometricStateForActiveVault();
      if (!mounted || _vaultFilePath != vaultId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric unlock enabled.')),
      );
      return;
    }
    final canUse = await _biometricAuthService.canUseBiometrics();
    if (!canUse) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometrics not available on this device.'),
        ),
      );
      return;
    }
    final password = await _resolveMasterPasswordForBiometricEnrollment();
    if (password == null || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unlock with master password first, then enable biometrics.',
          ),
        ),
      );
      return;
    }
    final authenticated = await _biometricAuthService.authenticateForUnlock(
      localizedReason: AppStrings.biometricAuthenticateReason,
      vaultId: vaultId,
    );
    if (!authenticated) {
      if (!mounted || _vaultFilePath != vaultId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.webBiometricEnableFailed)),
      );
      return;
    }
    try {
      await _biometricCredentialStore.saveMasterPassword(
        vaultId: vaultId,
        password: password,
        displayName: _activeVaultName,
      );
    } catch (error) {
      if (!mounted || _vaultFilePath != vaultId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.webBiometricEnableFailed)),
      );
      return;
    }
    await _biometricEnrollmentStore.setEnrolledForVault(
      vaultId: vaultId,
      enrolled: true,
    );
    if (!mounted || _vaultFilePath != vaultId) return;
    setState(() => _biometricEnabled = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Biometric unlock enabled.')));
  }

  Future<void> _disableBiometricForCurrentVault() async {
    final vaultId = _vaultFilePath;
    await _biometricCredentialStore.removeMasterPassword(vaultId: vaultId);
    await _biometricEnrollmentStore.setEnrolledForVault(
      vaultId: vaultId,
      enrolled: false,
    );
    if (!mounted || _vaultFilePath != vaultId) return;
    setState(() {
      _biometricEnabled = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Biometric unlock disabled.')));
  }

  Future<String?> _ensurePinForCurrentVault() async {
    final vaultId = _vaultFilePath;
    final hasPin = await _pinCredentialStore.hasPin(vaultId: vaultId);
    if (!hasPin) {
      return _setOrChangePinForCurrentVault(returnPin: true);
    }
    final pin = await _promptForPin(title: AppStrings.appPinUnlockTitle);
    if (pin == null || !mounted || _vaultFilePath != vaultId) return null;
    final password = await _pinCredentialStore.readMasterPassword(
      vaultId: vaultId,
      pin: pin,
    );
    if (password == null || password.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.appPinInvalidMessage)));
      return null;
    }
    return pin;
  }

  Future<String?> _setOrChangePinForCurrentVault({
    bool returnPin = false,
  }) async {
    final vaultId = _vaultFilePath;
    final wasPinEnabled = _pinEnabled;
    String? password;
    if (_pinEnabled) {
      final currentPin = await _promptForPin(
        title: AppStrings.appPinUnlockTitle,
      );
      if (currentPin == null || !mounted || _vaultFilePath != vaultId) {
        return null;
      }
      password = await _pinCredentialStore.readMasterPassword(
        vaultId: vaultId,
        pin: currentPin,
      );
      if (password == null || password.isEmpty) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.appPinInvalidMessage)),
        );
        return null;
      }
    } else {
      password = await _resolveMasterPasswordForPinSetup();
      if (password == null || password.isEmpty) return null;
    }
    final pin = await _promptForNewPin(
      title: _pinEnabled
          ? AppStrings.appPinChangeTitle
          : AppStrings.appPinSetupTitle,
    );
    if (pin == null || !mounted || _vaultFilePath != vaultId) return null;
    await _pinCredentialStore.saveMasterPassword(
      vaultId: vaultId,
      pin: pin,
      password: password,
    );
    await _refreshPinStateForActiveVault();
    if (!mounted || _vaultFilePath != vaultId) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasPinEnabled
              ? AppStrings.appPinChangedMessage
              : AppStrings.appPinEnabledMessage,
        ),
      ),
    );
    return returnPin ? pin : null;
  }

  Future<void> _refreshBiometricStateForActiveVault() async {
    final vaultId = _vaultFilePath;
    await _refreshPinStateForActiveVault();
    if (kIsWeb) {
      final purgedLegacy = await _biometricCredentialStore
          .purgeLegacyWebEnrollment(vaultId: vaultId);
      final hasPin = await _pinCredentialStore.hasPin(vaultId: vaultId);
      final hasSavedCredential = await _biometricCredentialStore
          .hasStoredCredential(vaultId: vaultId);
      var enrolled = await _biometricEnrollmentStore.isEnrolledForVault(
        vaultId,
      );
      if (purgedLegacy) {
        await _biometricEnrollmentStore.setEnrolledForVault(
          vaultId: vaultId,
          enrolled: false,
        );
        enrolled = false;
      }
      if (!enrolled && hasSavedCredential) {
        await _biometricEnrollmentStore.setEnrolledForVault(
          vaultId: vaultId,
          enrolled: true,
        );
        enrolled = true;
      }
      final canUseBiometrics = await _biometricAuthService.canUseBiometrics();
      final presentation = await _biometricAuthService
          .describeUnlockPresentation(
            genericLabel: AppStrings.useBiometricUnlock,
            fingerprintLabel: AppStrings.useFingerprintUnlock,
            faceIdLabel: AppStrings.useFaceIdUnlock,
            deviceLockLabel: AppStrings.useDeviceLockUnlock,
          );
      if (!mounted || _vaultFilePath != vaultId) return;
      setState(() {
        _biometricAvailable = hasPin && canUseBiometrics;
        _biometricEnabled =
            hasPin && enrolled && hasSavedCredential && canUseBiometrics;
        _biometricUnlockLabel = presentation.label;
        _biometricUnlockIcon = presentation.icon;
      });
      return;
    }
    final hasSavedCredential = await _biometricCredentialStore
        .hasStoredCredential(vaultId: vaultId);
    var enrolled = await _biometricEnrollmentStore.isEnrolledForVault(vaultId);
    if (!enrolled && hasSavedCredential) {
      await _biometricEnrollmentStore.setEnrolledForVault(
        vaultId: vaultId,
        enrolled: true,
      );
      enrolled = true;
    }
    final canUseBiometrics = await _biometricAuthService.canUseBiometrics();
    final presentation = await _biometricAuthService.describeUnlockPresentation(
      genericLabel: AppStrings.useBiometricUnlock,
      fingerprintLabel: AppStrings.useFingerprintUnlock,
      faceIdLabel: AppStrings.useFaceIdUnlock,
      deviceLockLabel: AppStrings.useDeviceLockUnlock,
    );
    if (!mounted || _vaultFilePath != vaultId) return;
    setState(() {
      _biometricAvailable = canUseBiometrics;
      _biometricEnabled = enrolled && hasSavedCredential && canUseBiometrics;
      _biometricUnlockLabel = presentation.label;
      _biometricUnlockIcon = presentation.icon;
    });
  }

  Future<void> _refreshPinStateForActiveVault() async {
    final vaultId = _vaultFilePath;
    final hasPin = await _pinCredentialStore.hasPin(vaultId: vaultId);
    if (!mounted || _vaultFilePath != vaultId) return;
    setState(() => _pinEnabled = hasPin);
  }

  Future<String?> _resolveMasterPasswordForBiometricEnrollment() async {
    final fromField = _passwordController.text.trim();
    if (fromField.isNotEmpty) return fromField;
    if (_sessionMasterPassword != null &&
        _sessionMasterPassword!.trim().isNotEmpty) {
      return _sessionMasterPassword!.trim();
    }
    if (!mounted || _step != OnboardingStep.app) return null;
    return _promptForMasterPassword(
      title: AppStrings.biometricEnableConfirmTitle,
      message: AppStrings.biometricEnableConfirmMessage,
    );
  }

  Future<String?> _resolveMasterPasswordForPinSetup() async {
    final fromField = _passwordController.text.trim();
    if (fromField.isNotEmpty) return fromField;
    if (_sessionMasterPassword != null &&
        _sessionMasterPassword!.trim().isNotEmpty) {
      return _sessionMasterPassword!.trim();
    }
    if (!mounted || _step != OnboardingStep.app) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.appPinUnavailableMessage)),
      );
      return null;
    }
    return _promptForMasterPassword(
      title: AppStrings.appPinSetupTitle,
      message: AppStrings.appPinSetupMessage,
    );
  }

  Future<String?> _promptForMasterPassword({
    required String title,
    required String message,
  }) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: AppStrings.masterPassword,
                ),
                onSubmitted: (value) =>
                    Navigator.of(dialogContext).pop(value.trim()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(AppStrings.enable),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (password == null || password.isEmpty || !mounted) return null;
    try {
      await _vaultService
          .unlockVault(
            filePath: _vaultFilePath,
            password: password,
            onProgress: (_) {},
          )
          .timeout(_vaultOpTimeout);
      _sessionMasterPassword = password;
      return password;
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.wrongVaultPassword)));
      return null;
    }
  }

  Future<String?> _promptForPin({required String title}) async {
    final pin = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => _NijaPinEntryDialog(title: title),
    );
    if (pin == null || pin.isEmpty) return null;
    return pin;
  }

  Future<String?> _promptForNewPin({required String title}) async {
    final pin = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => _NijaPinSetupDialog(title: title),
    );
    return pin;
  }

  Future<void> _confirmAndEnableBiometricForCurrentVault() async {
    if (!mounted) return;
    if (kIsWeb) {
      await _enableBiometricForCurrentVault();
      return;
    }
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.biometricEnableConfirmTitle),
        content: Text(AppStrings.biometricEnableConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppStrings.notNow),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppStrings.enable),
          ),
        ],
      ),
    );
    if (decision == true) {
      await _enableBiometricForCurrentVault();
      return;
    }
    await _refreshBiometricStateForActiveVault();
  }

  Future<void> _confirmAndDisableBiometricForCurrentVault() async {
    if (!mounted) return;
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.biometricDisableConfirmTitle),
        content: Text(AppStrings.biometricDisableConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppStrings.notNow),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppStrings.disable),
          ),
        ],
      ),
    );
    if (decision == true) {
      await _disableBiometricForCurrentVault();
      return;
    }
    await _refreshBiometricStateForActiveVault();
  }

  Future<bool> _showMandatoryMasterPasswordReset(
    String recoveryPhrase, {
    String? filePath,
  }) async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    try {
      if (!context.mounted) return false;
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setLocalState) {
            final newPassword = newPasswordController.text;
            final confirm = confirmPasswordController.text;
            final canSubmit =
                newPassword.trim().isNotEmpty && newPassword == confirm;

            return AlertDialog(
              title: const Text('Reset master password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recovery unlock requires setting a new master password before continuing.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'New master password',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Confirm master password',
                      helperText:
                          confirmPasswordController.text.isEmpty || canSubmit
                          ? null
                          : 'Passwords do not match',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop('cancel'),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canSubmit
                      ? () => Navigator.of(context).pop('submit')
                      : null,
                  child: const Text('Reset password'),
                ),
              ],
            );
          },
        ),
      );

      if (action != 'submit') return false;

      final vaultId = filePath ?? _vaultFilePath;
      _startBusy('Resetting master password...');
      try {
        await _vaultService
            .resetMasterPasswordAfterRecovery(
              filePath: vaultId,
              recoveryPhrase: recoveryPhrase,
              newPassword: newPasswordController.text.trim(),
              onProgress: _updateBusy,
            )
            .timeout(_vaultOpTimeout);
        _passwordController.text = newPasswordController.text.trim();
        await _resetBiometricForVault(vaultId);
        return true;
      } on TimeoutException {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset timed out. Please retry.'),
          ),
        );
      } catch (error, stackTrace) {
        _logOperationError(
          'resetMasterPasswordAfterRecovery',
          error,
          stackTrace,
        );
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reset password. Check phrase and retry.'),
          ),
        );
      } finally {
        _stopBusy();
      }
    } finally {
      await _waitForDialogTeardown();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }

    return _showMandatoryMasterPasswordReset(recoveryPhrase);
  }

  Future<void> _rotateMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_isBusy) return;
    final vaultId = _vaultFilePath;
    _startBusy('Rotating master password...');
    try {
      await _vaultService
          .rotateMasterPassword(
            filePath: vaultId,
            currentPassword: currentPassword,
            newPassword: newPassword,
            onProgress: _updateBusy,
          )
          .timeout(_vaultOpTimeout);
      if (!mounted) return;
      _passwordController.text = newPassword;
      await _resetBiometricForVault(vaultId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Master password updated.')));
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Master password rotation timed out.')),
      );
    } catch (error, stackTrace) {
      _logOperationError('rotateMasterPassword', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to rotate master password. Check current password.',
          ),
        ),
      );
    } finally {
      _stopBusy();
    }
  }

  Future<void> _rotateRecoveryPhrase({
    required String currentRecoveryPhrase,
    required String newRecoveryPhrase,
  }) async {
    if (_isBusy) return;
    final normalizedCurrent = currentRecoveryPhrase
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .map((word) => word.replaceAll(RegExp(r'[^a-z]'), ''))
        .where((word) => word.isNotEmpty)
        .toList();
    final normalizedNext = newRecoveryPhrase
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .map((word) => word.replaceAll(RegExp(r'[^a-z]'), ''))
        .where((word) => word.isNotEmpty)
        .toList();
    final dictionary = RecoveryPhraseDictionary.words.toSet();
    if (normalizedCurrent.length != 12 || normalizedNext.length != 12) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recovery phrases must be exactly 12 words.'),
        ),
      );
      return;
    }
    if (normalizedCurrent.any((w) => !dictionary.contains(w)) ||
        normalizedNext.any((w) => !dictionary.contains(w))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recovery phrase contains invalid words.'),
        ),
      );
      return;
    }
    _startBusy('Rotating recovery phrase...');
    try {
      await _vaultService
          .rotateRecoveryPhrase(
            filePath: _vaultFilePath,
            currentRecoveryPhrase: normalizedCurrent.join(' '),
            newRecoveryPhrase: normalizedNext.join(' '),
            onProgress: _updateBusy,
          )
          .timeout(_vaultOpTimeout);
      if (!mounted) return;
      setState(() => _recoveryWords = normalizedNext);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recovery phrase updated.')));
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovery phrase rotation timed out.')),
      );
    } catch (error, stackTrace) {
      _logOperationError('rotateRecoveryPhrase', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to rotate recovery phrase. Check current phrase.',
          ),
        ),
      );
    } finally {
      _stopBusy();
    }
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.selectedGuardian,
    required this.onSelectGuardian,
    required this.vaultNameController,
    required this.defaultVaultId,
    required this.passwordController,
    required this.onNext,
  });

  final GuardianProfile selectedGuardian;
  final ValueChanged<GuardianProfile> onSelectGuardian;
  final TextEditingController vaultNameController;
  final String defaultVaultId;
  final TextEditingController passwordController;
  final Future<void> Function() onNext;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _confirmPasswordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canCreateVault {
    final password = widget.passwordController.text;
    final confirm = _confirmPasswordController.text;
    final hasPassword = password.trim().isNotEmpty;
    final hasConfirm = confirm.trim().isNotEmpty;
    return hasPassword && hasConfirm && password == confirm;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OnboardingScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: ListView(
          children: [
            Text(AppStrings.step1Of2, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(AppStrings.chooseGuardian, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(AppStrings.guardianHelper, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 14),
            ...GuardianProfiles.all.map(
              (guardian) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GuardianCard(
                  guardian: guardian,
                  selected: guardian.id == widget.selectedGuardian.id,
                  onTap: () => widget.onSelectGuardian(guardian),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.selectedGuardian.displayName} details',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.selectedGuardian.detail,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text(
                      'Argon2id + XChaCha20-Poly1305\nProfile: ${widget.selectedGuardian.id}',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            TextField(
              key: const ValueKey('setup-vault-name-field'),
              controller: widget.vaultNameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '${AppStrings.vaultName} (optional)',
                helperText: widget.defaultVaultId.isEmpty
                    ? null
                    : 'Used to identify this vault later',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: widget.passwordController,
              onChanged: (_) => setState(() {}),
              obscureText: true,
              decoration: InputDecoration(labelText: AppStrings.masterPassword),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmPasswordController,
              onChanged: (_) => setState(() {}),
              obscureText: true,
              decoration: InputDecoration(
                labelText: AppStrings.confirmPassword,
                helperText:
                    _confirmPasswordController.text.isEmpty || _canCreateVault
                    ? null
                    : 'Passwords do not match',
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                AppStrings.masterPasswordGuidance,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const ValueKey('create-encrypted-vault-button'),
                onPressed: _canCreateVault && !_submitting
                    ? () async {
                        setState(() => _submitting = true);
                        try {
                          await widget.onNext();
                        } finally {
                          if (mounted) setState(() => _submitting = false);
                        }
                      }
                    : null,
                child: Text(AppStrings.createEncryptedVault),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({super.key, required this.words, required this.onNext});

  final List<String> words;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final phrase = words.join(' ');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final phraseCardColor = colorScheme.inverseSurface;
    final phraseTextColor = colorScheme.onInverseSurface;

    return OnboardingScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: ListView(
          children: [
            Text(AppStrings.step2Of2, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(AppStrings.recoveryPhrase, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(AppStrings.recoveryOffline, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: phraseCardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: phraseCardColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 8,
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        AppStrings.recoveryPhrase,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          color: phraseTextColor,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: phraseTextColor,
                        ),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: phrase));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppStrings.recoveryCopied)),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(AppStrings.copyRecoveryPhrase),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: words.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 3.2,
                        ),
                    itemBuilder: (context, index) {
                      final word = words[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: phraseTextColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          '${index + 1}. $word',
                          style: TextStyle(color: phraseTextColor),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(AppStrings.recoveryWarning, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              AppStrings.recoverySavedInVault,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onNext,
                child: Text(AppStrings.savedMyPhrase),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KnownVaultSelectionScreen extends StatelessWidget {
  const KnownVaultSelectionScreen({
    super.key,
    required this.knownVaults,
    required this.themeMode,
    this.onThemeModeChanged,
    this.onBack,
    this.onVaultSelected,
    this.onImportFromDevice,
    this.onImportFromCloud,
    this.sectionLabel,
    this.heading,
    this.description,
    this.showImportFromDevice = true,
    this.useCloudBackupCards = false,
  });

  final List<VaultReference> knownVaults;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final VoidCallback? onBack;
  final ValueChanged<VaultReference>? onVaultSelected;
  final Future<void> Function()? onImportFromDevice;
  final Future<void> Function()? onImportFromCloud;
  final String? sectionLabel;
  final String? heading;
  final String? description;
  final bool showImportFromDevice;
  final bool useCloudBackupCards;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedSectionLabel = sectionLabel ?? AppStrings.knownVaults;
    final resolvedHeading = heading ?? AppStrings.chooseWhatToOpen;
    final resolvedDescription =
        description ?? AppStrings.knownVaultsDescription;
    return OnboardingScaffold(
      fullWidth: true,
      child: Column(
        children: [
          _KnownVaultHeader(
            themeMode: themeMode,
            onThemeModeChanged: onThemeModeChanged,
            onBack: onBack,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 68,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      key: const ValueKey('known-vault-shell'),
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        key: const ValueKey('known-vault-selection-screen'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resolvedSectionLabel.toUpperCase(),
                            style: EntryTypography.sectionLabel(
                              colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            resolvedHeading,
                            style: EntryTypography.pageHeading(
                              colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            resolvedDescription,
                            style: EntryTypography.pageDescription(
                              colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (knownVaults.isEmpty)
                            useCloudBackupCards
                                ? _CloudVaultEmptyState()
                                : _KnownVaultEmptyState()
                          else
                            ...knownVaults.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: _KnownVaultCard(
                                  entry: entry,
                                  useCloudBackupIcon: useCloudBackupCards,
                                  useLastUpdatedLabel: useCloudBackupCards,
                                  onSelected: onVaultSelected == null
                                      ? null
                                      : () => onVaultSelected!(entry),
                                ),
                              ),
                            ),
                          if (showImportFromDevice) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                key: const ValueKey('known-vault-open-file'),
                                onPressed: () {
                                  if (onImportFromDevice != null) {
                                    unawaited(onImportFromDevice!());
                                    return;
                                  }
                                  Navigator.of(
                                    context,
                                  ).pop(_VaultPickerAction.importFromDevice);
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                  textStyle: EntryTypography.restoreButton(
                                    colorScheme.onSurface,
                                  ),
                                ),
                                child: Text(
                                  AppStrings.selectDifferentVaultFile,
                                ),
                              ),
                            ),
                          ],
                          if (onImportFromCloud != null) ...[
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppStrings.restoreFromStorage.toUpperCase(),
                                style: EntryTypography.sectionLabel(
                                  colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key: const ValueKey(
                                  'known-vault-restore-cloud',
                                ),
                                onPressed: () =>
                                    unawaited(onImportFromCloud!()),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                  textStyle: EntryTypography.restoreButton(
                                    colorScheme.onSurface,
                                  ),
                                ),
                                icon: const Icon(Icons.cloud_download_outlined),
                                label: Text(AppStrings.restoreFromStorage),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KnownVaultHeader extends StatelessWidget {
  const _KnownVaultHeader({
    required this.themeMode,
    this.onThemeModeChanged,
    this.onBack,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('known-vault-back'),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack ?? () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              AppStrings.selectVault,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EntryTypography.headerTitle(colorScheme.onSurface),
            ),
          ),
          IconButton(
            key: const ValueKey('known-vault-theme-toggle'),
            tooltip: 'Change theme',
            onPressed: onThemeModeChanged == null
                ? null
                : () => onThemeModeChanged!(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  ),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _KnownVaultCard extends StatelessWidget {
  const _KnownVaultCard({
    required this.entry,
    this.onSelected,
    this.useCloudBackupIcon = false,
    this.useLastUpdatedLabel = false,
  });

  final VaultReference entry;
  final VoidCallback? onSelected;
  final bool useCloudBackupIcon;
  final bool useLastUpdatedLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        key: ValueKey('known-vault-card-${entry.id}'),
        borderRadius: BorderRadius.circular(13),
        hoverColor: colorScheme.surfaceContainerHighest,
        onTap: onSelected ?? () => Navigator.of(context).pop(entry),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  useCloudBackupIcon
                      ? Icons.cloud_done_outlined
                      : Icons.shield_outlined,
                  size: 22,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EntryTypography.vaultCardTitle(
                        colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.sourceDescription.trim().isEmpty
                          ? AppStrings.localVaultReference
                          : entry.sourceDescription.trim(),
                      style: EntryTypography.vaultCardMeta(
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activityText(
                        entry.lastOpenedAtEpochMs,
                        useLastUpdatedLabel: useLastUpdatedLabel,
                      ),
                      style: EntryTypography.vaultCardMeta(
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  String _activityText(int epochMs, {required bool useLastUpdatedLabel}) {
    if (epochMs <= 0) {
      return useLastUpdatedLabel
          ? AppStrings.lastUpdated
          : AppStrings.neverOpened;
    }
    final opened = DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final openedDay = DateTime(opened.year, opened.month, opened.day);
    final timeLabel = _formatClock(opened);
    if (useLastUpdatedLabel) {
      if (openedDay == today) {
        return '${AppStrings.lastUpdated} · $timeLabel';
      }
      if (openedDay == today.subtract(const Duration(days: 1))) {
        return '${AppStrings.lastUpdated} · Yesterday';
      }
      return '${AppStrings.lastUpdated} · ${_formatShortDate(opened)}';
    }
    if (openedDay == today) return 'Today · $timeLabel';
    if (openedDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return _formatShortDate(opened);
  }

  String _formatClock(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatShortDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}';
  }
}

class _KnownVaultEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.noSavedVaultLocations,
            style: EntryTypography.emptyStateTitle(colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.importVaultToContinue,
            style: EntryTypography.emptyStateBody(colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CloudVaultEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.importVaultFromCloud,
            style: EntryTypography.emptyStateTitle(colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.cloudVaultsDescription,
            style: EntryTypography.emptyStateBody(colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({
    super.key,
    required this.vaultName,
    required this.guardianProfile,
    required this.passwordController,
    this.pinEnabled = false,
    required this.biometricEnabled,
    required this.biometricUnlockLabel,
    required this.biometricUnlockIcon,
    this.showRecoveryAction = true,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
    required this.onBack,
    required this.onUnlock,
    this.onPinUnlock,
    required this.onBiometricUnlock,
    required this.onRecover,
    required this.onSelectDifferentVault,
    required this.onOpenEncryptedSecret,
    required this.onCreateVault,
  });

  final String vaultName;
  final GuardianProfile guardianProfile;
  final TextEditingController passwordController;
  final bool pinEnabled;
  final bool biometricEnabled;
  final String biometricUnlockLabel;
  final IconData biometricUnlockIcon;
  final bool showRecoveryAction;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final Future<void> Function() onBack;
  final Future<void> Function() onUnlock;
  final Future<void> Function()? onPinUnlock;
  final Future<void> Function() onBiometricUnlock;
  final Future<void> Function() onRecover;
  final Future<void> Function() onSelectDifferentVault;
  final Future<void> Function() onOpenEncryptedSecret;
  final Future<void> Function() onCreateVault;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  bool _obscurePassword = true;
  bool _autoPinAttempted = false;
  bool _autoBiometricAttempted = false;

  @override
  void initState() {
    super.initState();
    _schedulePreferredQuickUnlock();
  }

  @override
  void didUpdateWidget(covariant UnlockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.biometricEnabled &&
        !oldWidget.biometricEnabled &&
        !_autoBiometricAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoBiometricAttempted) return;
        _autoBiometricAttempted = true;
        unawaited(widget.onBiometricUnlock());
      });
    }
    if (widget.pinEnabled &&
        !oldWidget.pinEnabled &&
        !widget.biometricEnabled &&
        !_autoPinAttempted) {
      _schedulePreferredQuickUnlock();
    }
  }

  void _schedulePreferredQuickUnlock() {
    if (widget.biometricEnabled && !_autoBiometricAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoBiometricAttempted) return;
        _autoBiometricAttempted = true;
        unawaited(widget.onBiometricUnlock());
      });
      return;
    }
    if (widget.pinEnabled &&
        widget.onPinUnlock != null &&
        !widget.biometricEnabled &&
        !_autoPinAttempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoPinAttempted) return;
        _autoPinAttempted = true;
        unawaited(widget.onPinUnlock!());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final protectedBy =
        'Protected by ${widget.guardianProfile.displayName} Guardian';

    return OnboardingScaffold(
      fullWidth: true,
      child: Column(
        key: const ValueKey('unlock-screen'),
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('unlock-back'),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => unawaited(widget.onBack()),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    AppStrings.unlockVault,
                    textAlign: TextAlign.center,
                    style: EntryTypography.headerTitle(colorScheme.onSurface),
                  ),
                ),
                IconButton(
                  key: const ValueKey('unlock-theme-toggle'),
                  tooltip: 'Change theme',
                  onPressed: widget.onThemeModeChanged == null
                      ? null
                      : () => widget.onThemeModeChanged!(
                          isDark ? ThemeMode.light : ThemeMode.dark,
                        ),
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 68,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              widget.guardianProfile.icon,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.vaultName,
                            textAlign: TextAlign.center,
                            style: EntryTypography.unlockTitle(
                              colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            protectedBy,
                            textAlign: TextAlign.center,
                            style: EntryTypography.unlockSubtitle(
                              colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.masterPassword.toUpperCase(),
                                  style: EntryTypography.fieldLabel(
                                    colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                TextField(
                                  key: const ValueKey('unlock-password-field'),
                                  controller: widget.passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _unlockIfReady(),
                                  decoration: InputDecoration(
                                    hintText: AppStrings.masterPassword,
                                    filled: true,
                                    fillColor: colorScheme.surface,
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      tooltip: _obscurePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const ValueKey('unlock-submit-button'),
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.onSurface,
                                foregroundColor: colorScheme.surface,
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: EntryTypography.restoreButton(
                                  colorScheme.surface,
                                ),
                              ),
                              onPressed: _unlockIfReady,
                              child: Text(AppStrings.unlock),
                            ),
                          ),
                          if (widget.pinEnabled &&
                              widget.onPinUnlock != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key: const ValueKey('unlock-pin-button'),
                                onPressed: () =>
                                    unawaited(widget.onPinUnlock!()),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                icon: const Icon(Icons.pin_outlined),
                                label: Text(AppStrings.unlockWithPin),
                              ),
                            ),
                          ],
                          if (widget.biometricEnabled) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key: const ValueKey('unlock-biometric-button'),
                                onPressed: () =>
                                    unawaited(widget.onBiometricUnlock()),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                icon: Icon(widget.biometricUnlockIcon),
                                label: Text(widget.biometricUnlockLabel),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (widget.showRecoveryAction)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: widget.onRecover,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                  textStyle: EntryTypography.restoreButton(
                                    colorScheme.onSurface,
                                  ),
                                ),
                                child: Text(AppStrings.webRecoverWithPhrase),
                              ),
                            ),
                          if (widget.showRecoveryAction)
                            const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: widget.onSelectDifferentVault,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                                textStyle: EntryTypography.restoreButton(
                                  colorScheme.onSurface,
                                ),
                              ),
                              child: Text(AppStrings.selectDifferentVault),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 2,
                            children: [
                              TextButton(
                                onPressed: widget.onOpenEncryptedSecret,
                                child: Text(AppStrings.openEncryptedSecret),
                              ),
                              TextButton(
                                onPressed: widget.onCreateVault,
                                child: Text(AppStrings.createVault),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Text(
                            AppStrings.webLocalYours,
                            textAlign: TextAlign.center,
                            style: EntryTypography.unlockFooter(
                              colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unlockIfReady() async {
    if (widget.passwordController.text.trim().isNotEmpty) {
      await widget.onUnlock();
    }
  }
}

class _EncryptedSecretViewerScreen extends StatefulWidget {
  const _EncryptedSecretViewerScreen({
    required this.title,
    required this.fields,
    required this.onImport,
  });

  final String title;
  final List<_SecretField> fields;
  final VoidCallback onImport;

  @override
  State<_EncryptedSecretViewerScreen> createState() =>
      _EncryptedSecretViewerScreenState();
}

class _EncryptedSecretViewerScreenState
    extends State<_EncryptedSecretViewerScreen> {
  late final List<bool> _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.fields.map((field) => field.sensitive).toList();
  }

  String _displayValue(int index) {
    final field = widget.fields[index];
    if (!field.sensitive || !_obscured[index]) return field.value;
    return '••••••••';
  }

  Future<void> _copyField(_SecretField field) async {
    await Clipboard.setData(
      ClipboardData(text: '${field.key}: ${field.value}'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  Future<void> _copyVisibleSecret() async {
    final buffer = StringBuffer();
    for (var i = 0; i < widget.fields.length; i++) {
      final field = widget.fields[i];
      buffer.writeln('${field.key}: ${_displayValue(i)}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Visible secret copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _copyVisibleSecret,
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy full secret (visible)'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('import-secret-to-vault'),
                onPressed: widget.onImport,
                icon: const Icon(Icons.download_done_outlined),
                label: const Text('Import to vault'),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: widget.fields.isEmpty
                  ? const Center(child: Text('No content'))
                  : ListView.separated(
                      itemCount: widget.fields.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final field = widget.fields[index];
                        return Card(
                          child: ListTile(
                            title: Text(field.key),
                            subtitle: SelectableText(_displayValue(index)),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                if (field.sensitive)
                                  IconButton(
                                    onPressed: () => setState(
                                      () =>
                                          _obscured[index] = !_obscured[index],
                                    ),
                                    icon: Icon(
                                      _obscured[index]
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                IconButton(
                                  onPressed: () => _copyField(field),
                                  icon: const Icon(Icons.copy_outlined),
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
      ),
    );
  }
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

class _EncryptedImportBundleScreen extends StatefulWidget {
  const _EncryptedImportBundleScreen({
    required this.entries,
    required this.onImportEntry,
    required this.onImportAll,
  });

  final List<_EncryptedImportEntry> entries;
  final Future<bool> Function(_EncryptedImportEntry entry) onImportEntry;
  final Future<bool> Function(List<_EncryptedImportEntry> entries) onImportAll;

  @override
  State<_EncryptedImportBundleScreen> createState() =>
      _EncryptedImportBundleScreenState();
}

class _EncryptedImportBundleScreenState
    extends State<_EncryptedImportBundleScreen> {
  final Set<int> _importedIndexes = <int>{};
  final _scrollController = ScrollController();
  bool _importingAll = false;

  List<_EncryptedImportEntry> get _remainingEntries => widget.entries
      .where((entry) => !_importedIndexes.contains(entry.index))
      .toList();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          interactive: true,
          child: ListView.separated(
            controller: _scrollController,
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
      ),
    );
  }

  Future<void> _openEntry(
    _EncryptedImportEntry entry, {
    required bool imported,
  }) async {
    final didImport = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _EncryptedImportEntryPreviewScreen(
          entry: entry,
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
    }
  }
}

class _EncryptedImportEntryPreviewScreen extends StatefulWidget {
  const _EncryptedImportEntryPreviewScreen({
    required this.entry,
    required this.alreadyImported,
    required this.onImport,
  });

  final _EncryptedImportEntry entry;
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
    if (entry.kind == 'note') return _buildNotePreview(entry);
    if (entry.kind == 'document') return _buildDocumentPreview(entry);
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

  Widget _buildNotePreview(_EncryptedImportEntry entry) {
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

  Widget _buildDocumentPreview(_EncryptedImportEntry entry) {
    return _DocumentImportPreview(entry: entry);
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
    }
  }
}

class _DocumentImportPreview extends StatefulWidget {
  const _DocumentImportPreview({required this.entry});

  final _EncryptedImportEntry entry;

  @override
  State<_DocumentImportPreview> createState() => _DocumentImportPreviewState();
}

class _DocumentImportPreviewState extends State<_DocumentImportPreview> {
  static const MethodChannel _documentOpenChannel = MethodChannel(
    'nija/document_open',
  );

  final _textPreviewScrollController = ScrollController();
  bool _autoOpenedExternalPreview = false;

  @override
  void dispose() {
    _textPreviewScrollController.dispose();
    super.dispose();
  }

  String get _fileName =>
      widget.entry.bundleEntry['fileName']?.toString().trim().isNotEmpty == true
      ? widget.entry.bundleEntry['fileName'].toString().trim()
      : widget.entry.title;

  String get _extension {
    final extension = widget.entry.bundleEntry['extension']?.toString().trim();
    if (extension != null && extension.isNotEmpty) {
      return extension.toUpperCase();
    }
    final dot = _fileName.lastIndexOf('.');
    if (dot == -1 || dot == _fileName.length - 1) return 'FILE';
    return _fileName.substring(dot + 1).toUpperCase();
  }

  Uint8List? get _bytes {
    final rawBytes = widget.entry.bundleEntry['bytesBase64']?.toString();
    if (rawBytes == null || rawBytes.isEmpty) return null;
    try {
      return Uint8List.fromList(base64Decode(rawBytes));
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final size = int.tryParse(
      widget.entry.bundleEntry['sizeBytes']?.toString() ?? '',
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            children: [
              _DocumentImportHeader(
                title: widget.entry.title,
                fileName: _fileName,
                extension: _extension,
                size: size != null
                    ? _formatDocumentByteCount(size)
                    : bytes == null
                    ? '-'
                    : _formatDocumentByteCount(bytes.length),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildPreview(context, bytes),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context, Uint8List? bytes) {
    if (bytes == null) {
      return const _DocumentPreviewMessage(
        icon: Icons.error_outline,
        title: 'Unable to preview document',
        subtitle: 'The encrypted file does not contain readable document data.',
      );
    }
    if (bytes.isEmpty) {
      return const _DocumentPreviewMessage(
        icon: Icons.insert_drive_file_outlined,
        title: 'Empty document',
        subtitle: 'There is no content to preview.',
      );
    }
    if (_isImageExtension(_extension)) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              _openExternalPreviewOnce(bytes);
              return _DocumentPreviewMessage(
                icon: Icons.broken_image_outlined,
                title: 'Image preview failed',
                subtitle: 'Tap to choose an app that can open this file.',
                onTap: () => _openDocument(bytes),
              );
            },
          ),
        ),
      );
    }
    if (_isTextExtension(_extension)) {
      final text = utf8.decode(bytes, allowMalformed: true);
      return Scrollbar(
        controller: _textPreviewScrollController,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _textPreviewScrollController,
          padding: const EdgeInsets.all(14),
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      );
    }
    if (_isPdfExtension(_extension)) {
      return PdfViewer.data(
        bytes,
        sourceName: 'import-${widget.entry.index}-$_fileName-${bytes.length}',
        params: _pdfViewerParams,
      );
    }
    _openExternalPreviewOnce(bytes);
    return _DocumentPreviewMessage(
      icon: _extension == 'PDF'
          ? Icons.picture_as_pdf_outlined
          : Icons.insert_drive_file_outlined,
      title: 'Opening $_extension document',
      subtitle: 'Tap to choose an app that can preview this file.',
      onTap: () => _openDocument(bytes),
    );
  }

  void _openExternalPreviewOnce(Uint8List bytes) {
    if (_autoOpenedExternalPreview) return;
    _autoOpenedExternalPreview = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openDocument(bytes);
    });
  }

  Future<void> _openDocument(Uint8List bytes) async {
    final mimeType = _mimeTypeForExtension(_extension);
    try {
      await _documentOpenChannel.invokeMethod<bool>('openDocument', {
        'fileName': _fileName,
        'mimeType': mimeType,
        'bytes': bytes,
      });
    } on MissingPluginException {
      await _shareDocumentFallback(bytes, mimeType);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'No app can open this file.')),
      );
      await _shareDocumentFallback(bytes, mimeType);
    }
  }

  Future<void> _shareDocumentFallback(Uint8List bytes, String mimeType) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: _fileName, mimeType: mimeType)],
      ),
    );
  }
}

class _DocumentImportHeader extends StatelessWidget {
  const _DocumentImportHeader({
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
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Center(
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
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

const PdfViewerParams _pdfViewerParams = PdfViewerParams(
  loadingBannerBuilder: _buildPdfLoadingBanner,
  errorBannerBuilder: _buildPdfErrorBanner,
);

Widget _buildPdfLoadingBanner(
  BuildContext context,
  int bytesDownloaded,
  int? totalBytes,
) {
  final progress = totalBytes == null || totalBytes <= 0
      ? null
      : bytesDownloaded / totalBytes;
  return _PdfStatusBanner(
    icon: Icons.picture_as_pdf_outlined,
    title: 'Loading PDF...',
    subtitle: totalBytes == null
        ? 'Preparing preview'
        : '${_formatDocumentByteCount(bytesDownloaded)} of ${_formatDocumentByteCount(totalBytes)}',
    progress: progress,
  );
}

Widget _buildPdfErrorBanner(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
  PdfDocumentRef documentRef,
) {
  return const _PdfStatusBanner(
    icon: Icons.error_outline,
    title: 'PDF preview failed',
    subtitle: 'Use Open with app to view this document.',
  );
}

class _PdfStatusBanner extends StatelessWidget {
  const _PdfStatusBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.progress,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: colorScheme.primary, size: 30),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress),
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
        ),
      ),
    );
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
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
  return Icons.lock_outline;
}

Color _colorForImportEntry(_EncryptedImportEntry entry) {
  if (entry.kind == 'note') return const Color(0xFF6366F1);
  if (entry.kind == 'document') return const Color(0xFFFB923C);
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

bool _isPdfExtension(String extension) {
  return extension.toUpperCase() == 'PDF';
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

String _formatDocumentByteCount(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}

class _NijaPinDialog extends StatelessWidget {
  const _NijaPinDialog({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: IconTheme(
            data: IconThemeData(color: colorScheme.primary),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _NijaPinEntryDialog extends StatefulWidget {
  const _NijaPinEntryDialog({required this.title});

  final String title;

  @override
  State<_NijaPinEntryDialog> createState() => _NijaPinEntryDialogState();
}

class _NijaPinEntryDialogState extends State<_NijaPinEntryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return _NijaPinDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.pin_outlined, size: 28),
          const SizedBox(height: 12),
          _NijaPinDialogTitle(widget.title),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('app-pin-field'),
            controller: _controller,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: AppStrings.appPinLabel),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          _NijaPinDialogActions(
            primaryLabel: AppStrings.unlock,
            onCancel: () => Navigator.of(context).pop(),
            onPrimary: _submit,
          ),
        ],
      ),
    );
  }
}

class _NijaPinSetupDialog extends StatefulWidget {
  const _NijaPinSetupDialog({required this.title});

  final String title;

  @override
  State<_NijaPinSetupDialog> createState() => _NijaPinSetupDialogState();
}

class _NijaPinSetupDialogState extends State<_NijaPinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final candidate = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    if (candidate.length < 6 || candidate != confirm) {
      setState(() {
        _errorText = candidate.length < 6
            ? AppStrings.appPinTooShortMessage
            : AppStrings.appPinMismatchMessage;
      });
      return;
    }
    Navigator.of(context).pop(candidate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _NijaPinDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.pin_outlined, size: 28),
          const SizedBox(height: 12),
          _NijaPinDialogTitle(widget.title),
          const SizedBox(height: 12),
          Text(
            AppStrings.appPinSetupMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('app-pin-new-field'),
            controller: _pinController,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: AppStrings.appPinLabel,
              errorText: _errorText,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('app-pin-confirm-field'),
            controller: _confirmController,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: AppStrings.appPinConfirmLabel,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          _NijaPinDialogActions(
            primaryLabel: AppStrings.enable,
            onCancel: () => Navigator.of(context).pop(),
            onPrimary: _submit,
          ),
        ],
      ),
    );
  }
}

class _NijaPinDialogTitle extends StatelessWidget {
  const _NijaPinDialogTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: EntryTypography.unlockTitle(colorScheme.onSurface),
    );
  }
}

class _NijaPinDialogActions extends StatelessWidget {
  const _NijaPinDialogActions({
    required this.primaryLabel,
    required this.onCancel,
    required this.onPrimary,
  });

  final String primaryLabel;
  final VoidCallback onCancel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Text(AppStrings.cancel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.onSurface,
              foregroundColor: colorScheme.surface,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(primaryLabel),
          ),
        ),
      ],
    );
  }
}

class _VaultMergeScreen extends StatefulWidget {
  const _VaultMergeScreen({
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
  State<_VaultMergeScreen> createState() => _VaultMergeScreenState();
}

class _VaultMergeScreenState extends State<_VaultMergeScreen> {
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
        .whereType<Map>()
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

class _SecretField {
  const _SecretField({
    required this.key,
    required this.value,
    required this.sensitive,
  });

  final String key;
  final String value;
  final bool sensitive;
}

class VaultCreatedScreen extends StatelessWidget {
  const VaultCreatedScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return OnboardingScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.check,
                  color: colorScheme.onPrimary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.vaultCreated,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                AppStrings.vaultCreatedMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onContinue,
                  child: Text(AppStrings.continueToUnlock),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuardianCard extends StatelessWidget {
  const _GuardianCard({
    required this.guardian,
    required this.selected,
    required this.onTap,
  });

  final GuardianProfile guardian;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Text(guardian.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guardian.displayName,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    guardian.tagline,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: colorScheme.onPrimaryContainer,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
