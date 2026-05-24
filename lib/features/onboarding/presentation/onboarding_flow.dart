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
import '../../../infrastructure/adapters/vault_reference_cache.dart';
import '../../../infrastructure/adapters/web_vault_storage_adapter.dart';
import '../../vault/presentation/vault_app_shell.dart';
import 'onboarding_scaffold.dart';
import 'welcome_screen.dart';

enum OnboardingStep { welcome, setup, recovery, created, unlock, app }

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
        onRestoreFromCloud: () =>
            _importVaultFromLocal(continueToUnlock: false),
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
      final credential = await _promptImportVaultCredential();
      if (credential == null || credential.isEmpty) return;
      var result = await _vaultService.importNijaFile(
        filePath: imported.storageId,
        unlockCredential: credential,
      );
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
      final activeId = result.conflictVaultId ?? result.vaultId;
      final importedLabel = result.status == ImportStatus.conflictCreated
          ? 'Vault conflict copy'
          : await _resolveVaultLabel(activeId);
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
      final backedUp = await _vaultPortability.backupVaultToCloud(
        vaultId: vaultId,
        suggestedName: suggestedName,
        content: rawContent,
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

  Future<String?> _promptImportVaultCredential() async {
    if (_passwordController.text.trim().isNotEmpty) {
      return _passwordController.text.trim();
    }
    final controller = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setLocalState) {
            final canContinue = controller.text.trim().isNotEmpty;
            return AlertDialog(
              title: const Text('Unlock imported vault'),
              content: TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                onChanged: (_) => setLocalState(() {}),
                decoration: InputDecoration(
                  labelText: AppStrings.masterPassword,
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
