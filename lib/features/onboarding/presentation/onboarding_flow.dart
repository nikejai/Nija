import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.languageMode,
    required this.onLanguageModeChanged,
    this.vaultService,
    this.vaultFilePath,
  });

  final String languageMode;
  final ValueChanged<String> onLanguageModeChanged;
  final VaultService? vaultService;
  final String? vaultFilePath;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with WidgetsBindingObserver {
  static const _vaultOpTimeout = Duration(seconds: 20);
  static const _unlockBackExitWindow = Duration(seconds: 2);
  static const _pausedLockDelay = Duration(seconds: 2);
  static const _prefsDeviceIdKey = 'nija_device_id_v1';
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
  int _busyRunId = 0;
  final _vaultReferenceCache = VaultReferenceCache();
  final VaultPortabilityAdapter _vaultPortability =
      VaultPortabilityAdapterImpl();
  final SecretSharePortabilityAdapter _secretSharePortability =
      SecretSharePortabilityAdapterImpl();
  final _secretIntentBridge = SecretIntentBridge();
  final _encryptedShareCodec = EncryptedShareCodec();
  final _vaultMergeHelper = const VaultMergeHelper();
  final _biometricAuthService = BiometricAuthService();
  final _biometricCredentialStore = BiometricCredentialStore();
  final _biometricEnrollmentStore = BiometricEnrollmentStore();
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

  @override
  void initState() {
    super.initState();
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
    _passwordController.dispose();
    _vaultNameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _backgroundLockTimer?.cancel();
      unawaited(_consumePendingSecretIntent());
      return;
    }
    if (state == AppLifecycleState.detached && _step == OnboardingStep.app) {
      _backgroundLockTimer?.cancel();
      _clearSensitiveSessionState();
      setState(() => _step = OnboardingStep.unlock);
      return;
    }
    if (state == AppLifecycleState.paused && _step == OnboardingStep.app) {
      _backgroundLockTimer?.cancel();
      _backgroundLockTimer = Timer(_pausedLockDelay, () {
        if (!mounted || _step != OnboardingStep.app) return;
        _clearSensitiveSessionState();
        setState(() => _step = OnboardingStep.unlock);
      });
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
        biometricEnabled: _biometricEnabled,
        onBiometricChanged: _onBiometricPreferenceChanged,
        onPersistVaultData: _persistVaultData,
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
        onLockNow: () {
          _clearSensitiveSessionState();
          setState(() => _step = OnboardingStep.unlock);
        },
      ),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleRootPopInvoked());
      },
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
    );
  }

  Future<bool> _handleRootBackPress() async {
    if (_step == OnboardingStep.app) {
      _clearSensitiveSessionState();
      if (mounted) {
        setState(() => _step = OnboardingStep.unlock);
      }
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
    final allowPop = await _handleRootBackPress();
    if (!allowPop || !mounted) return;
    unawaited(Navigator.of(context).maybePop());
  }

  void _handleUnlock() {
    setState(() => _step = OnboardingStep.app);
    unawaited(_markVaultAsOpened(_vaultFilePath));

    unawaited(_maybePromptToEnableBiometrics());
  }

  Future<void> _maybePromptToEnableBiometrics() async {
    if (_biometricEnabled) return;
    final enrolledForVault = await _biometricEnrollmentStore.isEnrolledForVault(
      _vaultFilePath,
    );
    if (enrolledForVault) return;
    final hasSavedCredential =
        (await _biometricCredentialStore.readMasterPassword(
          vaultId: _vaultFilePath,
        ))?.isNotEmpty ==
        true;
    if (hasSavedCredential) {
      await _biometricEnrollmentStore.setEnrolledForVault(
        vaultId: _vaultFilePath,
        enrolled: true,
      );
      if (mounted && !_biometricEnabled) {
        setState(() => _biometricEnabled = true);
      }
      return;
    }

    if (_biometricPromptShown) return;
    _biometricPromptShown = true;

    final canUseBiometrics = await _biometricAuthService.canUseBiometrics();
    if (!canUseBiometrics) return;

    if (!mounted || _step != OnboardingStep.app) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
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

      if (shouldEnable == true && mounted) {
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

    final selected = await showModalBottomSheet<VaultReference>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (selected != null) {
      setState(() {
        _vaultFilePath = selected.id;
        _activeVaultName = selected.label;
        _step = OnboardingStep.unlock;
      });
      await _refreshBiometricStateForActiveVault();
      return;
    }
    await _importVaultFromLocal(continueToUnlock: true);
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
      final vaultName = _vaultNameController.text.trim();
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
    final savedPassword = await _biometricCredentialStore.readMasterPassword(
      vaultId: _vaultFilePath,
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
    if (!authenticated) return;
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
    final imported = await _secretIntentBridge.consumePendingSecret();
    if (imported == null || !mounted) return;
    await _openImportedEncryptedSecret(imported);
  }

  Future<void> _openImportedEncryptedSecret(ImportedSecretFile imported) async {
    final password = await _promptSecretPassword();
    if (password == null || password.trim().isEmpty || !mounted) return;
    try {
      final decoded = await _encryptedShareCodec.decode(
        encoded: imported.content,
        password: password.trim(),
      );
      if (!mounted) return;
      final fields = _parseEncryptedSecretFields(decoded.plainText);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImportFailed)),
      );
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
    final authenticated = await _ensureAuthenticatedVaultSessionForAction(
      actionLabel: 'Import secret',
    );
    if (!authenticated) {
      return;
    }
    final applied = _applyImportedSecret(payload);
    if (!applied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImportFailed)),
      );
      return;
    }
    try {
      await _persistVaultData(
        items: _vaultItems,
        notes: _vaultNotes,
        customTypeDefinitions: _customTypeDefinitions,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.encryptedSecretImported)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to import secret into vault.')),
      );
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

  bool _applyImportedSecret(DecryptedSharePayload payload) {
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

  void _startBusy(String message) {
    if (!mounted) return;
    _busyWatchdog?.cancel();
    final runId = ++_busyRunId;
    setState(() {
      _isBusy = true;
      _busyProgress = 0.0;
      _busyMessage = message;
    });
    _busyWatchdog = Timer(const Duration(seconds: 25), () {
      if (!mounted || !_isBusy || runId != _busyRunId) return;
      _stopBusy();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Operation took too long. Please try again.'),
        ),
      );
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

  void _stopBusy() {
    if (!mounted) return;
    _busyWatchdog?.cancel();
    setState(() {
      _isBusy = false;
      _busyProgress = 0;
      _busyMessage = '';
    });
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
    final known = await _vaultReferenceCache.readAll();
    if (!mounted) return;
    setState(() {
      _knownVaults = known;
    });
  }

  Future<void> _restoreKnownVaultSession() async {
    if (!_enableVaultReferenceCache) return;
    final known = await _vaultReferenceCache.readAll();
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
    _vaultNameController.text = _draftVaultId;
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
    final approved = await _requestFileAccessConsent(
      title: 'Allow vault import',
      message:
          'Nija needs temporary file access to let you choose an encrypted vault file from your device. '
          'We only access the file you select.',
    );
    if (!approved) return;
    try {
      final imported = await _vaultPortability.importVaultFromLocal();
      if (imported == null) return;
      await _vaultService.writeRawVaultFile(
        filePath: imported.storageId,
        rawContent: imported.content,
      );
      var credential = _passwordController.text.trim();
      if (credential.isEmpty) {
        final prompted = await _promptImportVaultCredential();
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
              'The selected file did not unlock with the active vault password. Enter the password that was valid when this file was exported.',
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
      final importedLabel = result.status == ImportStatus.conflictCreated
          ? 'Vault conflict copy'
          : await _resolveVaultLabel(activeId);
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
    } catch (error, stackTrace) {
      _logOperationError('importVaultFromLocal', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.vaultImportFailed)));
    }
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
        initialName: _displayNameForVault(_vaultFilePath),
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
    try {
      final rawContent = await _vaultService.readRawVaultFile(
        filePath: _vaultFilePath,
      );
      final decoded = Map<String, dynamic>.from(jsonDecode(rawContent) as Map);
      final vaultId = decoded['vaultId']?.toString().trim() ?? '';
      if (vaultId.isEmpty) {
        throw StateError('Vault metadata is missing vaultId');
      }
      final now = DateTime.now();
      final stamp =
          '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final baseName = _displayNameForVault(
        _vaultFilePath,
      ).replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final suggestedName = 'backup_${stamp}_$baseName';
      final shouldContinue = await _resolveCloudVersionBeforeBackup(
        vaultId: vaultId,
      );
      if (!shouldContinue) return;
      final finalContent = await _vaultService.readRawVaultFile(
        filePath: _vaultFilePath,
      );
      final backedUp = await _vaultPortability.backupVaultToCloud(
        vaultId: vaultId,
        suggestedName: suggestedName,
        content: finalContent,
      );
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
      _logOperationError('backupCurrentVaultToCloud', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to prepare cloud backup. ${_errorHint(error)}'),
        ),
      );
    }
  }

  Future<void> _restoreCurrentVaultFromCloud() async {
    try {
      final rawContent = await _vaultService.readRawVaultFile(
        filePath: _vaultFilePath,
      );
      final decoded = Map<String, dynamic>.from(jsonDecode(rawContent) as Map);
      final vaultId = decoded['vaultId']?.toString().trim() ?? '';
      if (vaultId.isEmpty) {
        throw StateError('Vault metadata is missing vaultId');
      }
      final backup = await _vaultPortability.readCloudBackup(vaultId: vaultId);
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
      _logOperationError('restoreCurrentVaultFromCloud', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore cloud backup. ${_errorHint(error)}'),
        ),
      );
    }
  }

  Future<bool> _resolveCloudVersionBeforeBackup({
    required String vaultId,
  }) async {
    final backup = await _vaultPortability.readCloudBackup(vaultId: vaultId);
    if (backup == null) return true;
    final result = await _importCloudBackupForMerge(
      backup: backup,
      askBackupAfterMerge: true,
    );
    return result != _CloudMergeOutcome.cancelled;
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
      final raw = await _vaultService.readRawVaultFile(
        filePath: _vaultFilePath,
      );
      final size = utf8.encode(raw).length;
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
    await _biometricCredentialStore.removeMasterPassword(vaultId: vaultId);
    await _biometricEnrollmentStore.setEnrolledForVault(
      vaultId: vaultId,
      enrolled: false,
    );
    if (!mounted || vaultId != _vaultFilePath) return;
    setState(() => _biometricEnabled = false);
  }

  Future<void> _enableBiometricForCurrentVault() async {
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
    if (!authenticated) return;
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
      vaultId: _vaultFilePath,
      password: password,
    );
    await _biometricEnrollmentStore.setEnrolledForVault(
      vaultId: _vaultFilePath,
      enrolled: true,
    );
    if (!mounted) return;
    setState(() => _biometricEnabled = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Biometric unlock enabled.')));
  }

  Future<void> _disableBiometricForCurrentVault() async {
    await _biometricCredentialStore.removeMasterPassword(
      vaultId: _vaultFilePath,
    );
    await _biometricEnrollmentStore.setEnrolledForVault(
      vaultId: _vaultFilePath,
      enrolled: false,
    );
    if (!mounted) return;
    setState(() => _biometricEnabled = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Biometric unlock disabled.')));
  }

  Future<void> _refreshBiometricStateForActiveVault() async {
    final hasSavedCredential =
        (await _biometricCredentialStore.readMasterPassword(
          vaultId: _vaultFilePath,
        ))?.isNotEmpty ==
        true;
    var enrolled = await _biometricEnrollmentStore.isEnrolledForVault(
      _vaultFilePath,
    );
    if (!enrolled && hasSavedCredential) {
      await _biometricEnrollmentStore.setEnrolledForVault(
        vaultId: _vaultFilePath,
        enrolled: true,
      );
      enrolled = true;
    }
    final canUseBiometrics = await _biometricAuthService.canUseBiometrics();
    if (!mounted) return;
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

      _startBusy('Resetting master password...');
      try {
        await _vaultService
            .resetMasterPasswordAfterRecovery(
              filePath: _vaultFilePath,
              recoveryPhrase: recoveryPhrase,
              newPassword: newPasswordController.text.trim(),
              onProgress: _updateBusy,
            )
            .timeout(_vaultOpTimeout);
        _passwordController.text = newPasswordController.text.trim();
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
    _startBusy('Rotating master password...');
    try {
      await _vaultService
          .rotateMasterPassword(
            filePath: _vaultFilePath,
            currentPassword: currentPassword,
            newPassword: newPassword,
            onProgress: _updateBusy,
          )
          .timeout(_vaultOpTimeout);
      if (!mounted) return;
      _passwordController.text = newPassword;
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
    final vaultName = widget.vaultNameController.text.trim();
    final password = widget.passwordController.text;
    final confirm = _confirmPasswordController.text;
    final hasVaultName = vaultName.isNotEmpty;
    final hasPassword = password.trim().isNotEmpty;
    final hasConfirm = confirm.trim().isNotEmpty;
    return hasVaultName && hasPassword && hasConfirm && password == confirm;
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
              controller: widget.vaultNameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: AppStrings.vaultName,
                helperText: widget.defaultVaultId.isEmpty
                    ? null
                    : 'Default: ${widget.defaultVaultId}',
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

class UnlockScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: ListView(
          children: [
            Text(
              AppStrings.unlockVault,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.unlockHelper,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: AppStrings.masterPassword),
            ),
            const SizedBox(height: 24),
            if (biometricEnabled) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onBiometricUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(AppStrings.useBiometricUnlock),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (passwordController.text.trim().isNotEmpty) {
                    await onUnlock();
                  }
                },
                child: Text(AppStrings.unlock),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onRecover,
                child: const Text('Recover with phrase'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onSelectDifferentVault,
                child: Text(AppStrings.selectDifferentVault),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onOpenEncryptedSecret,
                child: Text(AppStrings.openEncryptedSecret),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onCreateVault,
                child: Text(AppStrings.createVault),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Vault locks automatically when the app goes to background.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
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
