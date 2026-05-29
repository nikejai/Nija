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
import '../../../core/config/guardian_profiles.dart';
import '../../../core/config/recovery_phrase_dictionary.dart';
import '../../../core/config/recovery_phrase_generator.dart';
import '../../../core/config/vault_limits.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/security/encrypted_share_codec.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/security/biometric_credential_store.dart';
import '../../../core/security/biometric_enrollment_store.dart';
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
import '../../../infrastructure/adapters/vault_portability.dart';
import '../../../infrastructure/adapters/vault_portability_base.dart';
import '../../../infrastructure/adapters/vault_portability_model.dart';
import '../../../infrastructure/adapters/vault_reference_cache.dart';
import '../../../infrastructure/adapters/web_vault_storage_adapter.dart';
import '../../vault/presentation/vault_app_shell.dart';
import 'onboarding_scaffold.dart';
import 'welcome_screen.dart';

enum OnboardingStep { welcome, setup, recovery, created, unlock, app }

enum _CloudMergeOutcome { noMergeNeeded, merged, cancelled }

enum _VaultPickerAction { importFromDevice, importFromCloud }

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

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with WidgetsBindingObserver {
  static const _vaultOpTimeout = Duration(seconds: 20);
  static const _unlockBackExitWindow = Duration(seconds: 2);
  static const _prefsDeviceIdKey = 'nija_device_id_v1';
  static const _defaultVaultName = 'Nija Vault';
  OnboardingStep _step = OnboardingStep.welcome;
  GuardianProfile _selectedGuardian = GuardianProfiles.owl;
  final _passwordController = TextEditingController();
  final _vaultNameController = TextEditingController();
  List<String> _recoveryWords = RecoveryPhraseGenerator.generate();
  bool _biometricEnabled = false;
  bool _biometricPromptShown = false;
  bool _isBusy = false;
  double _busyProgress = 0;
  String _busyMessage = '';
  bool _vaultCreatedInSession = false;
  List<Map<String, dynamic>> _vaultItems = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _vaultNotes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _customTypeDefinitions = <Map<String, dynamic>>[];
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
  List<VaultReference> _knownVaults = const <VaultReference>[];
  bool _enableVaultReferenceCache = true;
  bool _storageReady = false;
  late final VaultService _vaultService;
  late String _vaultFilePath;
  String _activeVaultName = 'vault.nija';
  int _activeVaultSizeBytes = 0;
  String _draftVaultId = '';
  final Random _idRandom = Random.secure();
  String _deviceId = '';
  String _deviceLabel = 'unknown';
  DateTime? _lastUnlockBackPressAt;
  bool _setupOpenedFromUnlock = false;
  bool _consumingPendingSecretIntent = false;
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
    _prepareVaultDraft();
    unawaited(_initializeDeviceMetadata());
    if (widget.vaultService != null) {
      _enableVaultReferenceCache = false;
      _vaultService = widget.vaultService!;
      _vaultFilePath = widget.vaultFilePath ?? 'nija_vault.nija';
      _activeVaultName = _displayNameForVault(_vaultFilePath);
      _storageReady = true;
      unawaited(_consumePendingSecretIntent());
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
      unawaited(_restoreKnownVaultSession());
      unawaited(_consumePendingSecretIntent());
      return;
    }

    _vaultFilePath = widget.vaultFilePath ?? '';
    _activeVaultName = _displayNameForVault(_vaultFilePath);
    unawaited(_initializeLocalVaultPath());
  }

  @override
  void dispose() {
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
      OnboardingStep.welcome => WelcomeScreen(
        onCreateVault: () {
          _prepareVaultDraft();
          setState(() {
            _setupOpenedFromUnlock = false;
            _step = OnboardingStep.setup;
          });
        },
        onOpenExistingVault: _openExistingVault,
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
        onContinue: () => setState(() => _step = OnboardingStep.unlock),
      ),
      OnboardingStep.unlock => UnlockScreen(
        passwordController: _passwordController,
        biometricEnabled: _biometricEnabled,
        onUnlock: _unlockWithPassword,
        onBiometricUnlock: _unlockWithBiometric,
        onRecover: _unlockWithRecoveryPhrase,
        onSelectDifferentVault: _openExistingVault,
        onOpenEncryptedSecret: _openEncryptedSecretFromUnlock,
        onCreateVault: _openCreateVaultFromUnlock,
      ),
      OnboardingStep.app => VaultAppShell(
        activeVaultName: _activeVaultName,
        vaultSizeBytes: _activeVaultSizeBytes,
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
        biometricEnabled: _biometricEnabled,
        onBiometricChanged: _onBiometricPreferenceChanged,
        onPersistVaultData: _persistVaultData,
        onPersistVaultDocument: _persistVaultDocument,
        onPersistVaultDocumentStream: _persistVaultDocumentStream,
        onReadVaultDocument: _readVaultDocument,
        onLifecycleLockSuppressed: _setLifecycleLockSuppressed,
        onRotateMasterPassword: _rotateMasterPassword,
        onRotateRecoveryPhrase: _rotateRecoveryPhrase,
        onExportVault: () =>
            _exportCurrentVaultToLocal(setAsActiveLocation: false),
        onImportVault: () => _importVaultFromLocal(continueToUnlock: false),
        onBackupToCloud: _backupCurrentVaultToCloud,
        onRestoreFromCloud: _restoreCurrentVaultFromCloud,
        onReadCloudBackupAccount: _readCloudBackupAccountLabel,
        onChangeCloudBackupAccount: _changeCloudBackupAccount,
        onRenameVault: _renameActiveVault,
        onReadVaultInternals: kDebugMode ? _readVaultInternals : null,
        onLockNow: _lockVaultSession,
      ),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleRootPopInvoked());
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _handleUserActivity(),
        onPointerMove: (_) => _handleUserActivity(),
        child: Stack(
          children: [
            screen,
            if (_isBusy)
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
    if (_step == OnboardingStep.app) {
      return false;
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
      setState(() => _step = OnboardingStep.setup);
      return false;
    }
    if (_step == OnboardingStep.created) {
      if (!mounted) return false;
      setState(() => _step = OnboardingStep.recovery);
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
    setState(() => _step = OnboardingStep.app);
    _scheduleInactivityLockIfNeeded();
    unawaited(_markVaultAsOpened(_vaultFilePath));

    unawaited(_maybePromptToEnableBiometrics());
  }

  Future<void> _maybePromptToEnableBiometrics() async {
    if (_biometricEnabled) return;
    final vaultId = _vaultFilePath;
    final enrolledForVault = await _biometricEnrollmentStore.isEnrolledForVault(
      vaultId,
    );
    if (enrolledForVault) return;
    final hasSavedCredential =
        (await _biometricCredentialStore.readMasterPassword(
          vaultId: vaultId,
        ))?.isNotEmpty ==
        true;
    if (hasSavedCredential) {
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

    final canUseBiometrics = await _biometricAuthService.canUseBiometrics();
    if (!canUseBiometrics) return;

    if (!mounted || _step != OnboardingStep.app || _vaultFilePath != vaultId) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _vaultFilePath != vaultId) return;
      final shouldEnable = await showDialog<bool>(
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
        await _enableBiometricForCurrentVault();
      }
    });
  }

  void _onBiometricPreferenceChanged(bool enabled) {
    if (enabled) {
      unawaited(_confirmAndEnableBiometricForCurrentVault());
      return;
    }
    unawaited(_confirmAndDisableBiometricForCurrentVault());
  }

  Future<void> _openExistingVault() async {
    if (!_storageReady) return;
    if (!mounted) return;
    await _syncKnownVaults();
    if (!mounted) return;

    final selected = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          ),
          children: [
            ListTile(
              title: Text(
                AppStrings.selectVaultToOpen,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_knownVaults.isEmpty)
              ListTile(
                title: Text(AppStrings.noSavedVaultLocations),
                subtitle: Text(AppStrings.importVaultToContinue),
              )
            else
              ..._knownVaults.map(
                (entry) => ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(entry.label),
                  subtitle: Text(entry.id),
                  onTap: () => Navigator.of(context).pop(entry),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: Text(AppStrings.importVaultFromDevice),
              onTap: () => Navigator.of(
                context,
              ).pop(_VaultPickerAction.importFromDevice),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Import vault from cloud'),
              onTap: () =>
                  Navigator.of(context).pop(_VaultPickerAction.importFromCloud),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (selected is VaultReference) {
      setState(() {
        _vaultFilePath = selected.id;
        _activeVaultName = selected.label;
        _step = OnboardingStep.unlock;
      });
      await _refreshBiometricStateForActiveVault();
      return;
    }
    if (selected == _VaultPickerAction.importFromDevice) {
      await _importVaultFromLocal(continueToUnlock: true);
    }
    if (selected == _VaultPickerAction.importFromCloud) {
      await _importVaultFromCloud(continueToUnlock: true);
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
      await _rememberVaultReference(_vaultFilePath, label: vaultName);
      _stopBusy();
      _vaultCreatedInSession = true;
      setState(() => _step = OnboardingStep.recovery);
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
    _startBusy('Starting vault unlock...');
    try {
      await _vaultService
          .unlockVault(
            filePath: _vaultFilePath,
            password: _passwordController.text,
            onProgress: _updateBusy,
          )
          .timeout(_vaultOpTimeout);
      await _loadVaultData(_passwordController.text);
      _activeVaultName = await _resolveVaultLabel(_vaultFilePath);
      await _refreshVaultSize();
      if (_biometricEnabled) {
        await _biometricCredentialStore.saveMasterPassword(
          vaultId: _vaultFilePath,
          password: _passwordController.text,
        );
      }
      if (!mounted) return;
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
    final savedPassword = await _biometricCredentialStore.readMasterPassword(
      vaultId: vaultId,
    );
    if (savedPassword == null || savedPassword.isEmpty) {
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
    final authenticated = await _biometricAuthService.authenticateForUnlock();
    if (!authenticated || !mounted || _vaultFilePath != vaultId) return;
    _passwordController.text = savedPassword;
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
      _activeVaultName = selectedVault.label;
      _step = OnboardingStep.unlock;
    });
    await _refreshBiometricStateForActiveVault();

    final password = await _promptVaultCredentialForAction(
      actionLabel: actionLabel,
    );
    if (password == null || password.isEmpty || !mounted) return false;

    _startBusy('Unlocking vault...');
    try {
      await _vaultService
          .unlockVault(
            filePath: _vaultFilePath,
            password: password,
            onProgress: _updateBusy,
          )
          .timeout(_vaultOpTimeout);
      await _loadVaultData(password);
      _activeVaultName = await _resolveVaultLabel(_vaultFilePath);
      await _refreshVaultSize();
      _passwordController.text = password;
      _handleUnlock();
      return true;
    } on TimeoutException {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock timed out. Please try again.')),
      );
      return false;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wrong vault password')));
      return false;
    } finally {
      _stopBusy();
    }
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

  Future<String?> _promptVaultCredentialForAction({
    required String actionLabel,
  }) async {
    final passwordController = TextEditingController();
    try {
      final hasSavedBiometricCredential =
          ((await _biometricCredentialStore.readMasterPassword(
            vaultId: _vaultFilePath,
          ))?.isNotEmpty ==
          true);
      if (!mounted) return null;
      final showBiometric = _biometricEnabled && hasSavedBiometricCredential;

      final decision = await showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setLocalState) {
            final canContinue = passwordController.text.trim().isNotEmpty;
            return AlertDialog(
              title: Text('$actionLabel: unlock vault'),
              content: TextField(
                controller: passwordController,
                autofocus: true,
                obscureText: true,
                onChanged: (_) => setLocalState(() {}),
                decoration: InputDecoration(
                  labelText: AppStrings.masterPassword,
                  hintText: _displayNameForVault(_vaultFilePath),
                ),
              ),
              actions: [
                if (showBiometric)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop('__biometric__'),
                    child: const Text('Use biometric'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canContinue
                      ? () => Navigator.of(
                          context,
                        ).pop(passwordController.text.trim())
                      : null,
                  child: const Text('Unlock'),
                ),
              ],
            );
          },
        ),
      );
      if (decision == '__biometric__') {
        final authenticated = await _biometricAuthService
            .authenticateForUnlock();
        if (!authenticated) return null;
        return await _biometricCredentialStore.readMasterPassword(
          vaultId: _vaultFilePath,
        );
      }
      return decision;
    } finally {
      await _waitForDialogTeardown();
      passwordController.dispose();
    }
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
    if (projected > VaultLimits.maxVaultBytes) {
      _showVaultLimitMessage(
        'Not enough vault space. Limit is ${VaultLimits.formatBytes(VaultLimits.maxVaultBytes)}.',
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
  }

  Future<void> _persistVaultData({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> notes,
    required List<Map<String, dynamic>> customTypeDefinitions,
  }) async {
    final password = _passwordController.text.trim();
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

  Future<List<int>> _readVaultDocument({required String sectionName}) async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      throw StateError('Master password missing for document preview.');
    }
    return _vaultService.readVaultDocument(
      filePath: _vaultFilePath,
      password: password,
      sectionName: sectionName,
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
      _shouldSuppressLifecycleLock || widget.autoLockDelay <= Duration.zero;

  void _handleUserActivity() {
    if (_step != OnboardingStep.app ||
        _lastLifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _scheduleInactivityLockIfNeeded();
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

  void _lockVaultSession() {
    _backgroundLockTimer?.cancel();
    _inactivityLockTimer?.cancel();
    _clearSensitiveSessionState();
    if (!mounted) return;
    setState(() => _step = OnboardingStep.unlock);
  }

  Future<void> _renameActiveVault(String name) async {
    final renamed = name.trim();
    if (renamed.isEmpty) {
      throw StateError('Vault name cannot be empty.');
    }

    await _vaultService.renameVault(filePath: _vaultFilePath, label: renamed);
    await _rememberVaultReference(_vaultFilePath, label: renamed);
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
                      : nowIso));
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
    if (recovery == null || recovery.isEmpty) return;
    if (!mounted) return;

    final normalizedRecovery = recovery
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .map((word) => word.replaceAll(RegExp(r'[^a-z]'), ''))
        .where((word) => word.isNotEmpty)
        .toList();
    if (normalizedRecovery.length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recovery phrase must be exactly 12 words.'),
        ),
      );
      return;
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
      return;
    }
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
      setState(() => _step = OnboardingStep.unlock);
      ScaffoldMessenger.of(context).showSnackBar(
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
    setState(() {
      _isBusy = false;
      _busyProgress = 0;
      _busyMessage = '';
    });
    if (_lastLifecycleState == AppLifecycleState.paused) {
      _scheduleBackgroundLockIfNeeded();
    } else {
      _scheduleInactivityLockIfNeeded();
    }
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
    debugPrint('[OnboardingFlow][$operation] $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  String _errorHint(Object error) {
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
    if (!_enableVaultReferenceCache) return;
    final known = await _mergedKnownAndPrivateVaultReferences();
    if (!mounted) return;
    setState(() {
      _knownVaults = known;
    });
  }

  Future<void> _restoreKnownVaultSession() async {
    if (!_enableVaultReferenceCache) return;
    final known = await _mergedKnownAndPrivateVaultReferences();
    if (!mounted) return;
    if (known.isEmpty) {
      setState(() => _knownVaults = known);
      return;
    }
    setState(() {
      _knownVaults = known;
      _vaultFilePath = known.first.id;
      _activeVaultName = known.first.label;
      _step = OnboardingStep.unlock;
    });
    await _refreshBiometricStateForActiveVault();
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
      unawaited(_restoreKnownVaultSession());
      unawaited(_consumePendingSecretIntent());
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
      unawaited(_restoreKnownVaultSession());
      unawaited(_consumePendingSecretIntent());
    }
  }

  Future<void> _rememberVaultReference(String filePath, {String? label}) async {
    if (!_enableVaultReferenceCache) return;
    final previous = _findVaultReference(filePath);
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolvedLabel = label ?? await _resolveVaultLabel(filePath);
    final reference = VaultReference(
      id: filePath,
      label: resolvedLabel,
      addedAtEpochMs: previous?.addedAtEpochMs ?? now,
      lastOpenedAtEpochMs: previous?.lastOpenedAtEpochMs ?? 0,
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
    );
    await _vaultReferenceCache.upsert(reference);
    await _syncKnownVaults();
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
      await _importVaultFile(
        imported: imported,
        continueToUnlock: continueToUnlock,
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

  Future<void> _importVaultFromCloud({required bool continueToUnlock}) async {
    try {
      _startBusy('Checking cloud backups...');
      final backups = await _vaultPortability.listCloudBackups();
      _stopBusy();
      if (!mounted) return;
      if (backups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cloud vault backups found.')),
        );
        return;
      }
      final selected = await showModalBottomSheet<CloudVaultBackupFile>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            children: [
              const ListTile(
                title: Text(
                  'Select cloud vault',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ...backups.map((backup) {
                return ListTile(
                  leading: const Icon(Icons.cloud_done_outlined),
                  title: Text(_cloudBackupLabel(backup)),
                  subtitle: Text(_cloudBackupSubtitle(backup)),
                  onTap: () => Navigator.of(context).pop(backup),
                );
              }),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      final importedPath = await _localPathForCloudBackup(selected.storageId);
      await _importVaultFile(
        imported: ImportedVaultFile(
          storageId: importedPath,
          label: _cloudBackupLabel(selected),
          content: selected.content,
        ),
        continueToUnlock: continueToUnlock,
      );
    } catch (error, stackTrace) {
      _stopBusy();
      _logOperationError('importVaultFromCloud', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import cloud vault. ${_errorHint(error)}'),
        ),
      );
    }
  }

  String _cloudBackupLabel(CloudVaultBackupFile backup) {
    final label = backup.label.trim();
    if (label.isNotEmpty) {
      final withoutExtension = label.toLowerCase().endsWith('.nija')
          ? label.substring(0, label.length - 5)
          : label;
      return withoutExtension
          .replaceAll(RegExp(r'^backup_\d{8}_\d{4}_'), '')
          .replaceAll(RegExp(r'[_-]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    return 'Cloud vault backup';
  }

  String _cloudBackupSubtitle(CloudVaultBackupFile backup) {
    final label = backup.label.trim();
    if (label.isEmpty) return 'Google Drive backup';
    return label.toLowerCase().endsWith('.nija') ? label : '$label.nija';
  }

  Future<void> _importVaultFile({
    required ImportedVaultFile imported,
    required bool continueToUnlock,
  }) async {
    await _vaultService.writeRawVaultFile(
      filePath: imported.storageId,
      rawContent: imported.content,
    );
    final selectedVaultLabel = _humanImportLabel(imported);
    var credential = _passwordController.text.trim();
    if (credential.isEmpty) {
      final prompted = await _promptImportVaultCredential(
        message: 'Selected vault: $selectedVaultLabel',
      );
      if (prompted == null || prompted.isEmpty) return;
      credential = prompted;
    }
    var result = await _vaultService.importNijaFile(
      filePath: imported.storageId,
      unlockCredential: credential,
    );
    if (result.status == ImportStatus.failed) {
      final prompted = await _promptImportVaultCredential(
        title: 'Unlock imported vault',
        message:
            'Selected vault: $selectedVaultLabel\n\nThe selected file did not unlock with the active vault password. Enter the password that was valid when this file was exported.',
      );
      if (prompted == null || prompted.isEmpty || prompted == credential) {
        throw StateError(result.userSafeMessage);
      }
      credential = prompted;
      result = await _vaultService.importNijaFile(
        filePath: imported.storageId,
        unlockCredential: credential,
      );
    }
    if (result.status == ImportStatus.failed &&
        result.userSafeMessage.contains('Confirm replace')) {
      final replace = await _confirmReplaceNewerImportedVault(result);
      if (replace) {
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
    await _rememberVaultReference(activeId, label: importedLabel);
    if (!mounted) return;
    setState(() {
      _vaultFilePath = activeId;
      _activeVaultName = importedLabel;
      if (continueToUnlock) {
        _step = OnboardingStep.unlock;
      }
    });
    await _refreshVaultSize();
    await _refreshBiometricStateForActiveVault();
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
    final currentPayload = await _vaultService.readVaultPayload(
      filePath: _vaultFilePath,
      password: currentPassword,
    );
    final importedPayload = await _vaultService.readVaultPayload(
      filePath: conflictVaultId,
      password: importedPassword,
    );
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
      await _vaultService.persistVaultPayload(
        filePath: _vaultFilePath,
        password: currentPassword,
        payload: mergedPayload,
      );
      if (resolvedVaultVersionId != null && resolvedVaultVersionId.isNotEmpty) {
        await _vaultService.markVaultConflictResolved(
          filePath: _vaultFilePath,
          resolvedVaultVersionId: resolvedVaultVersionId,
        );
      }
      await _loadVaultData(currentPassword);
      await _refreshVaultSize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Same vault detected. Non-conflicting changes were merged automatically. Please review if needed.',
          ),
        ),
      );
      if (askBackupAfterMerge) {
        await _confirmBackupAfterCloudMerge();
      }
      return;
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vault merge cancelled.')));
      return;
    }

    await _vaultService.persistVaultPayload(
      filePath: _vaultFilePath,
      password: currentPassword,
      payload: mergedPayload,
    );
    if (resolvedVaultVersionId != null && resolvedVaultVersionId.isNotEmpty) {
      await _vaultService.markVaultConflictResolved(
        filePath: _vaultFilePath,
        resolvedVaultVersionId: resolvedVaultVersionId,
      );
    }
    await _loadVaultData(currentPassword);
    await _refreshVaultSize();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Vault merged successfully.')));
    if (askBackupAfterMerge) {
      await _confirmBackupAfterCloudMerge();
    }
  }

  Future<String?> _activeVaultPasswordForMerge() async {
    final activePassword = _passwordController.text.trim();
    if (activePassword.isNotEmpty) return activePassword;
    return _promptVaultCredentialForAction(actionLabel: 'Merge vault');
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
        _vaultFilePath = exportedPath;
        await _rememberVaultReference(exportedPath);
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
      );
      stopCloudBusy();
      var shouldContinue = true;
      if (existingBackup != null) {
        final result = await _importCloudBackupForMerge(
          backup: existingBackup,
          askBackupAfterMerge: true,
        );
        shouldContinue = result != _CloudMergeOutcome.cancelled;
      }
      if (!shouldContinue) return;
      startCloudBusy('Uploading cloud backup...');
      final finalContent = await _vaultService.readRawVaultFile(
        filePath: _vaultFilePath,
      );
      _updateBusyStep('Sending vault to cloud storage...', 0.55);
      final backedUp = await _vaultPortability.backupVaultToCloud(
        vaultId: vaultId,
        suggestedName: suggestedName,
        content: finalContent,
      );
      _updateBusyStep('Finishing cloud backup...', 0.95);
      stopCloudBusy();
      if (!mounted) return;
      if (!backedUp) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloud backup cancelled.')),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cloud backup completed.')));
    } catch (error, stackTrace) {
      stopCloudBusy();
      _logOperationError('backupCurrentVaultToCloud', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to prepare cloud backup. ${_errorHint(error)}'),
        ),
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
            'Cloud restore is taking longer than expected. Please check your connection and retry.',
      );
      busyActive = true;
    }

    void stopCloudBusy() {
      if (!busyActive) return;
      _stopBusy();
      busyActive = false;
    }

    try {
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
      final backup = await _vaultPortability.readCloudBackup(vaultId: vaultId);
      _updateBusyStep('Preparing backup restore...', 0.75);
      stopCloudBusy();
      if (backup == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No cloud backup found.')));
        return;
      }
      await _importCloudBackupForMerge(
        backup: backup,
        askBackupAfterMerge: false,
      );
    } catch (error, stackTrace) {
      stopCloudBusy();
      _logOperationError('restoreCurrentVaultFromCloud', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore cloud backup. ${_errorHint(error)}'),
        ),
      );
    } finally {
      stopCloudBusy();
    }
  }

  Future<_CloudMergeOutcome> _importCloudBackupForMerge({
    required CloudVaultBackupFile backup,
    required bool askBackupAfterMerge,
  }) async {
    final backupFilePath = await _localPathForCloudBackup(backup.storageId);
    await _vaultService.writeRawVaultFile(
      filePath: backupFilePath,
      rawContent: backup.content,
    );
    var credential = _passwordController.text.trim();
    if (credential.isEmpty) {
      final prompted = await _promptImportVaultCredential(
        title: 'Unlock cloud backup',
      );
      if (prompted == null || prompted.isEmpty) {
        return _CloudMergeOutcome.cancelled;
      }
      credential = prompted;
    }
    var result = await _vaultService.importNijaFile(
      filePath: backupFilePath,
      unlockCredential: credential,
    );
    if (result.status == ImportStatus.failed) {
      final prompted = await _promptImportVaultCredential(
        title: 'Unlock cloud backup',
        message:
            'The cloud backup did not unlock with the active vault password. Enter the password that was valid when it was backed up.',
      );
      if (prompted == null || prompted.isEmpty || prompted == credential) {
        return _CloudMergeOutcome.cancelled;
      }
      credential = prompted;
      result = await _vaultService.importNijaFile(
        filePath: backupFilePath,
        unlockCredential: credential,
      );
    }
    if (result.status == ImportStatus.alreadyUpToDate) {
      if (!mounted) return _CloudMergeOutcome.cancelled;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.userSafeMessage)));
      return _CloudMergeOutcome.noMergeNeeded;
    }
    if (result.status == ImportStatus.imported) {
      await _resetBiometricForVault(_vaultFilePath);
      _passwordController.text = credential;
      await _loadVaultData(credential);
      await _refreshVaultSize();
      if (!mounted) return _CloudMergeOutcome.cancelled;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cloud backup restored.')));
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
        resolvedVaultVersionId: await _vaultVersionIdFromRaw(backup.content),
        askBackupAfterMerge: askBackupAfterMerge,
        importedSourceLabel: 'Cloud backup',
      );
      return _CloudMergeOutcome.merged;
    }
    if (!mounted) return _CloudMergeOutcome.cancelled;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.userSafeMessage)));
    return _CloudMergeOutcome.cancelled;
  }

  Future<String> _localPathForCloudBackup(String storageId) async {
    final safeName = storageId
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (kIsWeb) return safeName;
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/$safeName';
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
    return _vaultPortability.changeCloudBackupAccount();
  }

  Future<void> _refreshVaultSize() async {
    try {
      final size = await _vaultService.readVaultSizeBytes(
        filePath: _vaultFilePath,
      );
      if (!mounted) return;
      setState(() => _activeVaultSizeBytes = size);
    } catch (_) {
      if (!mounted) return;
      setState(() => _activeVaultSizeBytes = 0);
    }
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

  Future<String?> _promptImportVaultCredential({
    String title = 'Unlock imported vault',
    String? message,
  }) async {
    final controller = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setLocalState) {
            final canContinue = controller.text.trim().isNotEmpty;
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message != null && message.trim().isNotEmpty) ...[
                    Text(message),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: InputDecoration(
                      labelText: AppStrings.masterPassword,
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
                  onPressed: canContinue
                      ? () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(context).pop(controller.text.trim());
                        }
                      : null,
                  child: const Text('Import'),
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
    _passwordController.clear();
  }

  Future<void> _resetBiometricForVault(String vaultId) async {
    try {
      await _biometricCredentialStore.removeMasterPassword(vaultId: vaultId);
      await _biometricEnrollmentStore.setEnrolledForVault(
        vaultId: vaultId,
        enrolled: false,
      );
    } catch (_) {
      // Biometric cleanup should not block vault creation, import, or unlock.
    }
    if (!mounted || vaultId != _vaultFilePath) return;
    setState(() => _biometricEnabled = false);
  }

  Future<void> _enableBiometricForCurrentVault() async {
    final vaultId = _vaultFilePath;
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
    final authenticated = await _biometricAuthService.authenticateForUnlock();
    if (!authenticated || !mounted || _vaultFilePath != vaultId) return;
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
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
    await _biometricCredentialStore.saveMasterPassword(
      vaultId: vaultId,
      password: password,
    );
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
    setState(() => _biometricEnabled = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Biometric unlock disabled.')));
  }

  Future<void> _refreshBiometricStateForActiveVault() async {
    final vaultId = _vaultFilePath;
    final hasSavedCredential =
        (await _biometricCredentialStore.readMasterPassword(
          vaultId: vaultId,
        ))?.isNotEmpty ==
        true;
    var enrolled = await _biometricEnrollmentStore.isEnrolledForVault(vaultId);
    if (!enrolled && hasSavedCredential) {
      await _biometricEnrollmentStore.setEnrolledForVault(
        vaultId: vaultId,
        enrolled: true,
      );
      enrolled = true;
    }
    final canUseBiometrics = await _biometricAuthService.canUseBiometrics();
    if (!mounted || _vaultFilePath != vaultId) return;
    setState(() {
      _biometricEnabled = enrolled && hasSavedCredential && canUseBiometrics;
    });
  }

  Future<void> _confirmAndEnableBiometricForCurrentVault() async {
    if (!mounted) return;
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

  Future<bool> _showMandatoryMasterPasswordReset(String recoveryPhrase) async {
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

      final vaultId = _vaultFilePath;
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
    return OnboardingScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: ListView(
          children: [
            Text(
              AppStrings.step1Of2,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.chooseGuardian,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.guardianHelper,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
                color: const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.selectedGuardian.displayName} details',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.selectedGuardian.detail,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Argon2id + XChaCha20-Poly1305\nProfile: ${widget.selectedGuardian.id}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 12),
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
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                AppStrings.masterPasswordGuidance,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF92400E),
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

    return OnboardingScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: ListView(
          children: [
            Text(
              AppStrings.step2Of2,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.recoveryPhrase,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.recoveryOffline,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF18181B)),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 16, color: Colors.white),
                      ),
                      TextButton.icon(
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
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          '${index + 1}. $word',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.recoveryWarning,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.recoverySavedInVault,
              style: Theme.of(context).textTheme.bodyMedium,
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

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({
    super.key,
    required this.passwordController,
    required this.biometricEnabled,
    required this.onUnlock,
    required this.onBiometricUnlock,
    required this.onRecover,
    required this.onSelectDifferentVault,
    required this.onOpenEncryptedSecret,
    required this.onCreateVault,
  });

  final TextEditingController passwordController;
  final bool biometricEnabled;
  final Future<void> Function() onUnlock;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = colorScheme.primary;

    return OnboardingScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 52).clamp(520.0, 720.0),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    Image.asset(
                      'assets/branding/nija_mark.png',
                      width: 72,
                      height: 72,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.appName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'yourself, secure.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Icon(
                      Icons.lock_outline,
                      color: colorScheme.onSurfaceVariant,
                      size: 28,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      AppStrings.unlockHelper,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: widget.passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _unlockIfReady(),
                      decoration: InputDecoration(
                        labelText: AppStrings.masterPassword,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
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
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _unlockIfReady,
                        child: Text(AppStrings.unlock),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.biometricEnabled)
                      TextButton.icon(
                        onPressed: widget.onBiometricUnlock,
                        icon: Icon(Icons.fingerprint, color: accent),
                        label: Text(AppStrings.useBiometricUnlock),
                      ),
                    if (!widget.biometricEnabled)
                      Text(
                        AppStrings.unlockVault,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        TextButton(
                          onPressed: widget.onRecover,
                          child: const Text('Recover with phrase'),
                        ),
                        TextButton(
                          onPressed: widget.onSelectDifferentVault,
                          child: Text(AppStrings.selectDifferentVault),
                        ),
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
                    const SizedBox(height: 34),
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        '100% local. 100% yours.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
    final filtered = widget.plan.entries.where(_matchesFilter).toList();
    final unresolved = widget.plan.entries.where((entry) {
      final selected = _selections[entry.key];
      return entry.needsResolution && selected == null;
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: const Color(0xFF111827),
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
                    color: const Color(0xFF4B5563),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.plan.conflictCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${_trueConflictCount()} conflicts, ${_deletionReviewCount()} deletions, ${widget.plan.identicalCount} identical, ${_autoMergeCount()} automatic.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
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
                            foregroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(color: Color(0xFF4F46E5)),
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
                            foregroundColor: Colors.white,
                            backgroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(color: Color(0xFF4F46E5)),
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
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
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
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF374151),
          fontWeight: FontWeight.w700,
        ),
        selectedColor: const Color(0xFF4F46E5),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onSelected: (_) => setState(() => _filter = value),
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
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
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
        ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
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
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${entry.type} • ${_statusLabel(entry.status)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
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
                    color: const Color(0xFF4B5563),
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
              if (entry.current != null)
                _MergeChoiceRow(
                  title: 'Current Vault',
                  subtitle: _metadataLine(entry.current!),
                  selected: selected == VaultMergeSource.current,
                  onTap: () => onSelected(VaultMergeSource.current),
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
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(4, 10, 2, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'View differences',
                          style: TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Color(0xFF4B5563),
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF4F46E5) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF9CA3AF),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 15)
                  : null,
            ),
          ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
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
                    style: const TextStyle(
                      color: Color(0xFF4F46E5),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF4F46E5),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.remove_circle_outline, color: Color(0xFF9CA3AF)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Not present in this vault version.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
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
                color: const Color(0xFFE0E7FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_outline, color: Color(0xFF4F46E5)),
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
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
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
          const Text('No fields', style: TextStyle(color: Color(0xFF6B7280)))
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    if (index > 0) const Divider(height: 1),
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
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (sensitive) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.visibility_outlined,
                                        size: 13,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  value.isEmpty ? 'Empty' : value,
                                  style: TextStyle(
                                    color: value.isEmpty
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF111827),
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
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111827),
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
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: SelectableText(
            body.isEmpty ? 'Empty note' : body,
            style: TextStyle(
              color: body.isEmpty
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF111827),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
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
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF18181B) : const Color(0xFFE4E4E7),
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
            if (selected) const Icon(Icons.check_circle, size: 20),
          ],
        ),
      ),
    );
  }
}
