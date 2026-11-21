class AppStrings {
  AppStrings._();

  static String _languageCode = 'en';

  static void setLanguageCode(String? code) {
    _languageCode = (code == 'es') ? 'es' : 'en';
  }

  static String _t(String key) =>
      _localized[_languageCode]?[key] ?? _localized['en']![key]!;

  static String get appName => _t('appName');
  static String get appNameBranding => _t('appNameBranding');
  static String get tagline => _t('tagline');

  static String get welcomeLabel => _t('welcomeLabel');
  static String get welcomeTitle => _t('welcomeTitle');
  static String get welcomeDescription => _t('welcomeDescription');
  static String get welcomeTagLocalFirst => _t('welcomeTagLocalFirst');
  static String get welcomeTagEncrypted => _t('welcomeTagEncrypted');
  static String get welcomeTagPortable => _t('welcomeTagPortable');
  static String get welcomeTagNoAccount => _t('welcomeTagNoAccount');
  static String get welcomeTypePasswords => _t('welcomeTypePasswords');
  static String get welcomeTypePasswordsHint => _t('welcomeTypePasswordsHint');
  static String get welcomeTypeIdentity => _t('welcomeTypeIdentity');
  static String get welcomeTypeIdentityHint => _t('welcomeTypeIdentityHint');
  static String get welcomeTypeDocuments => _t('welcomeTypeDocuments');
  static String get welcomeTypeDocumentsHint => _t('welcomeTypeDocumentsHint');
  static String get welcomeTypeNotes => _t('welcomeTypeNotes');
  static String get welcomeTypeNotesHint => _t('welcomeTypeNotesHint');
  static String get welcomeVaultFileTitle => _t('welcomeVaultFileTitle');
  static String get welcomeFlowDevice => _t('welcomeFlowDevice');
  static String get welcomeFlowDeviceHint => _t('welcomeFlowDeviceHint');
  static String get welcomeFlowVault => _t('welcomeFlowVault');
  static String get welcomeFlowVaultHint => _t('welcomeFlowVaultHint');
  static String get welcomeFlowBackup => _t('welcomeFlowBackup');
  static String get welcomeFlowBackupHint => _t('welcomeFlowBackupHint');
  static String get entryAboutNija => _t('entryAboutNija');

  static String get createVault => _t('createVault');
  static String get openExistingVault => _t('openExistingVault');
  static String get entryTitle => _t('entryTitle');
  static String get entryDescription => _t('entryDescription');
  static String get webStorageNoticeTitle => _t('webStorageNoticeTitle');
  static String get webStorageNoticeBody => _t('webStorageNoticeBody');
  static String get selectKnownVault => _t('selectKnownVault');
  static String get selectKnownVaultHint => _t('selectKnownVaultHint');
  static String get openVaultFile => _t('openVaultFile');
  static String get openVaultFileHint => _t('openVaultFileHint');
  static String get createVaultHint => _t('createVaultHint');
  static String get importData => _t('importData');
  static String get importDataHint => _t('importDataHint');
  static String get exploreDemo => _t('exploreDemo');
  static String get exploreDemoHint => _t('exploreDemoHint');
  static String get exploreDemoWriteBlocked => _t('exploreDemoWriteBlocked');
  static String get exploreDemoActiveNotice => _t('exploreDemoActiveNotice');
  static String get exitExploreDemo => _t('exitExploreDemo');
  static String get restoreFromStorage => _t('restoreFromStorage');
  static String get knownVaults => _t('knownVaults');
  static String get chooseWhatToOpen => _t('chooseWhatToOpen');
  static String get knownVaultsDescription => _t('knownVaultsDescription');
  static String get selectDifferentVaultFile => _t('selectDifferentVaultFile');
  static String get selectVault => _t('selectVault');
  static String get localVaultReference => _t('localVaultReference');
  static String get webVaultPrivateStorage => _t('webVaultPrivateStorage');
  static String get appVaultPrivateStorage => _t('appVaultPrivateStorage');
  static String get selectedVaultFile => _t('selectedVaultFile');
  static String get lastOpened => _t('lastOpened');
  static String get neverOpened => _t('neverOpened');
  static String get noExistingVaultFound => _t('noExistingVaultFound');
  static String get wrongVaultPassword => _t('wrongVaultPassword');
  static String get selectVaultToOpen => _t('selectVaultToOpen');
  static String get noSavedVaultLocations => _t('noSavedVaultLocations');
  static String get importVaultToContinue => _t('importVaultToContinue');
  static String get importVaultFromDevice => _t('importVaultFromDevice');
  static String get importVaultFromCloud => _t('importVaultFromCloud');
  static String get cloudVaultsSection => _t('cloudVaultsSection');
  static String get cloudVaultsDescription => _t('cloudVaultsDescription');
  static String get googleDriveBackup => _t('googleDriveBackup');
  static String get lastUpdated => _t('lastUpdated');
  static String get vaultImportedSuccess => _t('vaultImportedSuccess');
  static String get vaultImportFailed => _t('vaultImportFailed');
  static String get vaultExportedSuccess => _t('vaultExportedSuccess');
  static String get vaultExportFailed => _t('vaultExportFailed');
  static String get vaultExportCancelled => _t('vaultExportCancelled');
  static String get vaultLimitReached => _t('vaultLimitReached');

  static String get valueLocalFirst => _t('valueLocalFirst');
  static String get valueZeroKnowledge => _t('valueZeroKnowledge');
  static String get valuePortableFile => _t('valuePortableFile');

  static String get step1Of2 => _t('step1Of2');
  static String get step2Of2 => _t('step2Of2');
  static String get chooseGuardian => _t('chooseGuardian');
  static String get guardianHelper => _t('guardianHelper');
  static String get masterPassword => _t('masterPassword');
  static String get confirmPassword => _t('confirmPassword');
  static String get createEncryptedVault => _t('createEncryptedVault');
  static String get masterPasswordGuidance => _t('masterPasswordGuidance');

  static String get recoveryPhrase => _t('recoveryPhrase');
  static String get recoveryOffline => _t('recoveryOffline');
  static String get recoveryWarning => _t('recoveryWarning');
  static String get recoverySavedInVault => _t('recoverySavedInVault');
  static String get savedMyPhrase => _t('savedMyPhrase');
  static String get printRecoverySheet => _t('printRecoverySheet');
  static String get copyRecoveryPhrase => _t('copyRecoveryPhrase');
  static String get recoveryCopied => _t('recoveryCopied');
  static String get printRecoveryTitle => _t('printRecoveryTitle');
  static String get printRecoveryHint => _t('printRecoveryHint');

  static String get vaultCreated => _t('vaultCreated');
  static String get vaultCreatedMessage => _t('vaultCreatedMessage');
  static String get continueToUnlock => _t('continueToUnlock');
  static String get chooseVaultLocation => _t('chooseVaultLocation');

  static String get unlockVault => _t('unlockVault');
  static String get unlockHelper => _t('unlockHelper');
  static String get unlock => _t('unlock');
  static String get webLoginWelcomeBack => _t('webLoginWelcomeBack');
  static String get webLoginSubtitle => _t('webLoginSubtitle');
  static String get webPrivateByDefault => _t('webPrivateByDefault');
  static String get webYourVaultYourRules => _t('webYourVaultYourRules');
  static String get webVaultIntro => _t('webVaultIntro');
  static String get webNoNijaAccount => _t('webNoNijaAccount');
  static String get webLocalMode => _t('webLocalMode');
  static String get webVaultStartsHere => _t('webVaultStartsHere');
  static String get webVaultStartsHereSubtitle =>
      _t('webVaultStartsHereSubtitle');
  static String get webOpenVault => _t('webOpenVault');
  static String get webCreateNewVault => _t('webCreateNewVault');
  static String get webRecentVaults => _t('webRecentVaults');
  static String get webRecentVaultsHint => _t('webRecentVaultsHint');
  static String get webRestoreCloudStorage => _t('webRestoreCloudStorage');
  static String get webHideCloudStorage => _t('webHideCloudStorage');
  static String get webStorageAccessOnly => _t('webStorageAccessOnly');
  static String get webLastOpened => _t('webLastOpened');
  static String get webYourDataStaysYours => _t('webYourDataStaysYours');
  static String get webOfflineReady => _t('webOfflineReady');
  static String get webEncryptedVaults => _t('webEncryptedVaults');
  static String get webNoTracking => _t('webNoTracking');
  static String get webConnectStorage => _t('webConnectStorage');
  static String get webConnectStorageMessage => _t('webConnectStorageMessage');
  static String get webKnownVaultsAppearHere => _t('webKnownVaultsAppearHere');
  static String get webPersonalVault => _t('webPersonalVault');
  static String get webRailPrivateArchive => _t('webRailPrivateArchive');
  static String get webStatusLocalNoAccount => _t('webStatusLocalNoAccount');
  static String get webEntryIndex => _t('webEntryIndex');
  static String get webPrivateArchiveTitle => _t('webPrivateArchiveTitle');
  static String get webArchiveIntro => _t('webArchiveIntro');
  static String get webStoredLocallyDefault => _t('webStoredLocallyDefault');
  static String get webEncryptedBeforeLeaves => _t('webEncryptedBeforeLeaves');
  static String get webVaultAccess => _t('webVaultAccess');
  static String get webWhatWouldYouLike => _t('webWhatWouldYouLike');
  static String get webOpenVaultHint => _t('webOpenVaultHint');
  static String get webCreateVaultHint => _t('webCreateVaultHint');
  static String get webContinueRecent => _t('webContinueRecent');
  static String get webContinueRecentHint => _t('webContinueRecentHint');
  static String get webImportData => _t('webImportData');
  static String get webImportDataHint => _t('webImportDataHint');
  static String get webPersonalVaultDetail => _t('webPersonalVaultDetail');
  static String get webDocumentsVault => _t('webDocumentsVault');
  static String get webDocumentsVaultDetail => _t('webDocumentsVaultDetail');
  static String get webPrivateByDesignFooter => _t('webPrivateByDesignFooter');
  static String get webOfflineEncryptedNoTracking =>
      _t('webOfflineEncryptedNoTracking');
  static String get webNewVault => _t('webNewVault');
  static String get webCreateSomethingPrivate =>
      _t('webCreateSomethingPrivate');
  static String get webCreateModalBody => _t('webCreateModalBody');
  static String get webStartEmpty => _t('webStartEmpty');
  static String get webStartEmptyHint => _t('webStartEmptyHint');
  static String get webStartFromImport => _t('webStartFromImport');
  static String get webStartFromImportHint => _t('webStartFromImportHint');
  static String get webExternalStorage => _t('webExternalStorage');
  static String get webOpenProvider => _t('webOpenProvider');
  static String get webUnlockAccess => _t('webUnlockAccess');
  static String get webUnlockQuestion => _t('webUnlockQuestion');
  static String get webUnlockHint => _t('webUnlockHint');
  static String get webRecoverWithPhrase => _t('webRecoverWithPhrase');
  static String get webLocalYours => _t('webLocalYours');
  static String get pwaInstallAddToComputer => _t('pwaInstallAddToComputer');
  static String get pwaInstallAddToHomeScreen =>
      _t('pwaInstallAddToHomeScreen');
  static String get pwaInstallDownloadApp => _t('pwaInstallDownloadApp');
  static String get pwaInstallSignCompact => _t('pwaInstallSignCompact');
  static String get pwaInstallComputerHint => _t('pwaInstallComputerHint');
  static String get pwaInstallHomeScreenHint => _t('pwaInstallHomeScreenHint');
  static String get pwaInstallAccepted => _t('pwaInstallAccepted');
  static String get pwaInstallDismissed => _t('pwaInstallDismissed');
  static String get pwaInstallUnavailable => _t('pwaInstallUnavailable');
  static String get pwaInstallIosTitle => _t('pwaInstallIosTitle');
  static String get pwaInstallDesktopSafariTitle =>
      _t('pwaInstallDesktopSafariTitle');
  static String get pwaInstallStepsIntro => _t('pwaInstallStepsIntro');
  static String get pwaInstallStepsDone => _t('pwaInstallStepsDone');
  static List<String> get pwaInstallIosSteps => [
    _t('pwaInstallIosStep1'),
    _t('pwaInstallIosStep2'),
    _t('pwaInstallIosStep3'),
  ];
  static List<String> get pwaInstallDesktopSafariSteps => [
    _t('pwaInstallDesktopSafariStep1'),
    _t('pwaInstallDesktopSafariStep2'),
    _t('pwaInstallDesktopSafariStep3'),
  ];
  static String get cancel => _t('cancel');
  static String get continueLabel => _t('continueLabel');
  static String get close => _t('close');
  static String get webLoginEmail => _t('webLoginEmail');
  static String get webLoginEmailHint => _t('webLoginEmailHint');
  static String get webLoginPasswordHint => _t('webLoginPasswordHint');
  static String get webForgotPassword => _t('webForgotPassword');
  static String get webOrContinueWith => _t('webOrContinueWith');
  static String get webContinueAsGuest => _t('webContinueAsGuest');
  static String get webLimitedAccess => _t('webLimitedAccess');
  static String get webDontHaveVault => _t('webDontHaveVault');
  static String get webCreateOne => _t('webCreateOne');
  static String get webDataBelongsToYou => _t('webDataBelongsToYou');
  static String get webStoreSecureIt => _t('webStoreSecureIt');
  static String get webAccessAnywhere => _t('webAccessAnywhere');
  static String get webEndToEndEncrypted => _t('webEndToEndEncrypted');
  static String get selectDifferentVault => _t('selectDifferentVault');
  static String get useBiometricUnlock => _t('useBiometricUnlock');
  static String get useFingerprintUnlock => _t('useFingerprintUnlock');
  static String get useFaceIdUnlock => _t('useFaceIdUnlock');
  static String get useDeviceLockUnlock => _t('useDeviceLockUnlock');
  static String get biometricAuthenticateReason =>
      _t('biometricAuthenticateReason');
  static String get biometricComingSoon => _t('biometricComingSoon');
  static String get unlockImportedVaultTitle => _t('unlockImportedVaultTitle');
  static String get openWithPassword => _t('openWithPassword');
  static String get webBiometricRequiresUpdatedBrowser =>
      _t('webBiometricRequiresUpdatedBrowser');
  static String get webBiometricLegacyCleared =>
      _t('webBiometricLegacyCleared');
  static String get webBiometricEnableFailed => _t('webBiometricEnableFailed');
  static String get webBiometricConfirmEnable =>
      _t('webBiometricConfirmEnable');
  static String get webBiometricUseSessionInstead =>
      _t('webBiometricUseSessionInstead');
  static String get webBiometricUnlockFailed => _t('webBiometricUnlockFailed');
  static String get webBiometricUnavailableTitle =>
      _t('webBiometricUnavailableTitle');
  static String get webBiometricUnavailableIntro =>
      _t('webBiometricUnavailableIntro');
  static List<String> get webBiometricUnavailableSteps => [
    _t('webBiometricUnavailableStep1'),
    _t('webBiometricUnavailableStep2'),
    _t('webBiometricUnavailableStep3'),
    _t('webBiometricUnavailableStep4'),
  ];
  static String get webBiometricPlatformUnavailableTitle =>
      _t('webBiometricPlatformUnavailableTitle');
  static String get webBiometricPlatformUnavailableIntro =>
      _t('webBiometricPlatformUnavailableIntro');
  static List<String> get webBiometricPlatformUnavailableSteps => [
    _t('webBiometricPlatformUnavailableStep1'),
    _t('webBiometricPlatformUnavailableStep2'),
    _t('webBiometricPlatformUnavailableStep3'),
    _t('webBiometricPlatformUnavailableStep4'),
  ];
  static String get webBiometricRegistrationFailedTitle =>
      _t('webBiometricRegistrationFailedTitle');
  static String get webBiometricRegistrationFailedIntro =>
      _t('webBiometricRegistrationFailedIntro');
  static List<String> get webBiometricRegistrationFailedSteps => [
    _t('webBiometricRegistrationFailedStep1'),
    _t('webBiometricRegistrationFailedStep2'),
    _t('webBiometricRegistrationFailedStep3'),
    _t('webBiometricRegistrationFailedStep4'),
  ];
  static String get webBiometricPasskeyConflictTitle =>
      _t('webBiometricPasskeyConflictTitle');
  static String get webBiometricPasskeyConflictIntro =>
      _t('webBiometricPasskeyConflictIntro');
  static List<String> get webBiometricPasskeyConflictSteps => [
    _t('webBiometricPasskeyConflictStep1'),
    _t('webBiometricPasskeyConflictStep2'),
    _t('webBiometricPasskeyConflictStep3'),
  ];
  static String get webBiometricEnableIntro => _t('webBiometricEnableIntro');
  static List<String> get webBiometricEnableSteps => [
    _t('webBiometricEnableStep1'),
    _t('webBiometricEnableStep2'),
    _t('webBiometricEnableStep3'),
  ];
  static String get webBiometricConfirmTouchId =>
      _t('webBiometricConfirmTouchId');
  static String get webBiometricUseSessionUnlockAction =>
      _t('webBiometricUseSessionUnlockAction');
  static String get webBiometricSessionUnlockAcknowledged =>
      _t('webBiometricSessionUnlockAcknowledged');
  static String get webSessionUnlockLabel => _t('webSessionUnlockLabel');
  static String get webSessionUnlockExpired => _t('webSessionUnlockExpired');
  static String get webSessionUnlockEnableTitle =>
      _t('webSessionUnlockEnableTitle');
  static String get webSessionUnlockEnableIntro =>
      _t('webSessionUnlockEnableIntro');
  static List<String> get webSessionUnlockEnableSteps => [
    _t('webSessionUnlockEnableStep1'),
    _t('webSessionUnlockEnableStep2'),
    _t('webSessionUnlockEnableStep3'),
    _t('webSessionUnlockEnableStep4'),
  ];
  static String get webSessionUnlockEnableConfirm =>
      _t('webSessionUnlockEnableConfirm');
  static String get webSessionUnlockEnabledMessage =>
      _t('webSessionUnlockEnabledMessage');
  static String get webSessionUnlockDisabledMessage =>
      _t('webSessionUnlockDisabledMessage');

  static String get vaultHome => _t('vaultHome');
  static String get homePlaceholder => _t('homePlaceholder');
  static String get openSettings => _t('openSettings');

  static String get settingsTitle => _t('settingsTitle');
  static String get securitySection => _t('securitySection');
  static String get enableBiometric => _t('enableBiometric');
  static String get biometricToggleHint => _t('biometricToggleHint');

  static String get enableBiometricPromptTitle =>
      _t('enableBiometricPromptTitle');
  static String get enableBiometricPromptMessage =>
      _t('enableBiometricPromptMessage');
  static String get notNow => _t('notNow');
  static String get enable => _t('enable');
  static String get disable => _t('disable');
  static String get biometricEnableConfirmTitle =>
      _t('biometricEnableConfirmTitle');
  static String get biometricEnableConfirmMessage =>
      _t('biometricEnableConfirmMessage');
  static String get biometricDisableConfirmTitle =>
      _t('biometricDisableConfirmTitle');
  static String get biometricDisableConfirmMessage =>
      _t('biometricDisableConfirmMessage');
  static String get tabVault => _t('tabVault');
  static String get tabFolders => _t('tabFolders');
  static String get tabNotes => _t('tabNotes');
  static String get tabTypes => _t('tabTypes');
  static String get tabSettings => _t('tabSettings');
  static String get search => _t('search');
  static String get searchNotes => _t('searchNotes');
  static String get settingsSubtitle => _t('settingsSubtitle');
  static String get language => _t('language');
  static String get systemDefault => _t('systemDefault');
  static String get lockVaultNow => _t('lockVaultNow');
  static String get typesSubtitle => _t('typesSubtitle');
  static String get notesSubtitle => _t('notesSubtitle');
  static String get createCustomType => _t('createCustomType');
  static String get yourCustomTypes => _t('yourCustomTypes');
  static String get noNotesFound => _t('noNotesFound');
  static String get noNotesFoundHint => _t('noNotesFoundHint');
  static String get noMatchingItems => _t('noMatchingItems');
  static String get noMatchingItemsHint => _t('noMatchingItemsHint');
  static String get noItemsYet => _t('noItemsYet');
  static String get noItemsYetHint => _t('noItemsYetHint');
  static String get secureNotes => _t('secureNotes');
  static String get pinned => _t('pinned');
  static String get pinnedFirst => _t('pinnedFirst');
  static String get languageUpdated => _t('languageUpdated');
  static String get settingsSecurity => _t('settingsSecurity');
  static String get settingsAppPin => _t('settingsAppPin');
  static String get settingsAppPinEnabledSubtitle =>
      _t('settingsAppPinEnabledSubtitle');
  static String get settingsAppPinDisabledSubtitle =>
      _t('settingsAppPinDisabledSubtitle');
  static String get setUpPin => _t('setUpPin');
  static String get changePin => _t('changePin');
  static String get unlockWithPin => _t('unlockWithPin');
  static String get appPinSetupTitle => _t('appPinSetupTitle');
  static String get appPinChangeTitle => _t('appPinChangeTitle');
  static String get appPinUnlockTitle => _t('appPinUnlockTitle');
  static String get appPinSetupMessage => _t('appPinSetupMessage');
  static String get appPinUnavailableMessage => _t('appPinUnavailableMessage');
  static String get appPinInvalidMessage => _t('appPinInvalidMessage');
  static String get appPinEnabledMessage => _t('appPinEnabledMessage');
  static String get appPinChangedMessage => _t('appPinChangedMessage');
  static String get appPinLabel => _t('appPinLabel');
  static String get appPinConfirmLabel => _t('appPinConfirmLabel');
  static String get appPinTooShortMessage => _t('appPinTooShortMessage');
  static String get appPinMismatchMessage => _t('appPinMismatchMessage');
  static String get settingsBiometricAvailableSubtitle =>
      _t('settingsBiometricAvailableSubtitle');
  static String get settingsBiometricUnavailableSubtitle =>
      _t('settingsBiometricUnavailableSubtitle');
  static String get settingsVaultBackup => _t('settingsVaultBackup');
  static String get settingsBiometricUnlock => _t('settingsBiometricUnlock');
  static String get settingsRecoveryPhrase => _t('settingsRecoveryPhrase');
  static String get settingsAutoLock => _t('settingsAutoLock');
  static String get settingsExportVault => _t('settingsExportVault');
  static String get settingsDangerZone => _t('settingsDangerZone');
  static String get settingsEntitlementChecking =>
      _t('settingsEntitlementChecking');
  static String get googlePlayAccountTitle => _t('googlePlayAccountTitle');
  static String get googlePlayAccountMessage => _t('googlePlayAccountMessage');
  static String get googlePlayAccountContinue =>
      _t('googlePlayAccountContinue');
  static String get googlePlayAccountRestore => _t('googlePlayAccountRestore');
  static String get googlePlayUnexpectedResponse =>
      _t('googlePlayUnexpectedResponse');
  static String get settingComingSoon => _t('settingComingSoon');
  static String get copySuccess => _t('copySuccess');
  static String get customTypeExists => _t('customTypeExists');
  static String get noteTags => _t('noteTags');
  static String get noteTagHint => _t('noteTagHint');
  static String get addTag => _t('addTag');
  static String get vaultName => _t('vaultName');
  static String get pin => _t('pin');
  static String get unpin => _t('unpin');
  static String get delete => _t('delete');
  static String get noteDeleted => _t('noteDeleted');
  static String get itemDeleted => _t('itemDeleted');
  static String get edit => _t('edit');
  static String get select => _t('select');
  static String get selected => _t('selected');
  static String get selectAll => _t('selectAll');
  static String get clearSelection => _t('clearSelection');
  static String get deleteSelected => _t('deleteSelected');
  static String get sharePlainText => _t('sharePlainText');
  static String get sharedTextCopied => _t('sharedTextCopied');
  static String get shareEncryptedFile => _t('shareEncryptedFile');
  static String get encryptedShareSuccess => _t('encryptedShareSuccess');
  static String get encryptedShareFailed => _t('encryptedShareFailed');
  static String get exportEncryptedFile => _t('exportEncryptedFile');
  static String get encryptedExportSuccess => _t('encryptedExportSuccess');
  static String get encryptedExportFailed => _t('encryptedExportFailed');
  static String get openEncryptedSecret => _t('openEncryptedSecret');
  static String get importEncryptedSecret => _t('importEncryptedSecret');
  static String get encryptedSecretPassword => _t('encryptedSecretPassword');
  static String get encryptedSecretImported => _t('encryptedSecretImported');
  static String get encryptedSecretImportFailed =>
      _t('encryptedSecretImportFailed');
  static String get lastAccessed => _t('lastAccessed');
  static String get entrySaved => _t('entrySaved');
  static String get entrySavedMessage => _t('entrySavedMessage');
  static String get done => _t('done');
  static String get randomPassword => _t('randomPassword');
  static String get passphrase => _t('passphrase');
  static String get regenerate => _t('regenerate');
  static String get capitalize => _t('capitalize');
  static String get includeNumber => _t('includeNumber');
  static String get copy => _t('copy');
  static String get passwordCopied => _t('passwordCopied');
  static String get copiedToClipboard => _t('copiedToClipboard');
  static String get visibleSecretCopied => _t('visibleSecretCopied');
  static String get copyFullSecretVisible => _t('copyFullSecretVisible');
  static String get importToVault => _t('importToVault');
  static String get noContent => _t('noContent');
  static String get encryptedFile => _t('encryptedFile');
  static String get importAll => _t('importAll');
  static String get imported => _t('imported');
  static String get importItem => _t('importItem');
  static String get secureNote => _t('secureNote');
  static String get unableToPreviewDocument => _t('unableToPreviewDocument');
  static String get unableToPreviewDocumentHint =>
      _t('unableToPreviewDocumentHint');
  static String get emptyDocument => _t('emptyDocument');
  static String get emptyDocumentHint => _t('emptyDocumentHint');
  static String get imagePreviewFailed => _t('imagePreviewFailed');
  static String get imagePreviewFailedHint => _t('imagePreviewFailedHint');
  static String openingDocument(String extension) =>
      _t('openingDocument').replaceAll('{extension}', extension);
  static String get openingDocumentHint => _t('openingDocumentHint');
  static String get noAppCanOpenFile => _t('noAppCanOpenFile');
  static String get favorite => _t('favorite');
  static String get documentAttached => _t('documentAttached');
  static String get unableToAttachDocument => _t('unableToAttachDocument');
  static String get documentUnavailable => _t('documentUnavailable');
  static String get useOpenDocumentToView => _t('useOpenDocumentToView');
  static String previewUnavailable(String extension) =>
      _t('previewUnavailable').replaceAll('{extension}', extension);
  static String get useOpenDocumentAnotherApp => _t('useOpenDocumentAnotherApp');
  static String get openDocument => _t('openDocument');
  static String get shareFile => _t('shareFile');
  static String get saveCopy => _t('saveCopy');
  static String get attachmentRemoved => _t('attachmentRemoved');
  static String get unableToProcessAttachment => _t('unableToProcessAttachment');
  static String get hide => _t('hide');
  static String get reveal => _t('reveal');
  static String get shareSecurely => _t('shareSecurely');
  static String get addDocument => _t('addDocument');
  static String get addIcon => _t('addIcon');
  static String get templateName => _t('templateName');
  static String get templateNameHint => _t('templateNameHint');
  static String get descriptionOptional => _t('descriptionOptional');
  static String get descriptionOptionalHint => _t('descriptionOptionalHint');
  static String get next => _t('next');
  static String get details => _t('details');
  static String get fieldKeyHint => _t('fieldKeyHint');
  static String get stringText => _t('stringText');
  static String get numberType => _t('numberType');
  static String get dateType => _t('dateType');
  static String get passwordSecretType => _t('passwordSecretType');
  static String get valueType => _t('valueType');
  static String get removeField => _t('removeField');
  static String get addField => _t('addField');
  static String get saveChanges => _t('saveChanges');
  static String get saveTemplate => _t('saveTemplate');
  static String get open => _t('open');
  static String get saveDownloadOptions => _t('saveDownloadOptions');
  static String get saveCopyDecrypted => _t('saveCopyDecrypted');
  static String get exportEncryptedNija => _t('exportEncryptedNija');
  static String get shareOptions => _t('shareOptions');
  static String get shareDecryptedFile => _t('shareDecryptedFile');
  static String get shareEncryptedNija => _t('shareEncryptedNija');
  static String get sampleDocumentMetadata => _t('sampleDocumentMetadata');
  static String get sampleDocumentMetadataHint =>
      _t('sampleDocumentMetadataHint');
  static String get useOpenWithToView => _t('useOpenWithToView');
  static String get useOpenWithAnotherApp => _t('useOpenWithAnotherApp');
  static String get unableToSaveDocumentCopy => _t('unableToSaveDocumentCopy');
  static String get enlargePreview => _t('enlargePreview');
  static String get exportEncrypted => _t('exportEncrypted');
  static String get closePreview => _t('closePreview');
  static String get unableToCompleteDocumentAction =>
      _t('unableToCompleteDocumentAction');
  static String useLabelToViewDocument(String label) =>
      _t('useLabelToViewDocument').replaceAll('{label}', label);
  static String get loadingPdf => _t('loadingPdf');
  static String get pdfPreviewFailed => _t('pdfPreviewFailed');
  static String get pdfPreviewFailedHint => _t('pdfPreviewFailedHint');
  static String newItemOfType(String type) =>
      _t('newItemOfType').replaceAll('{type}', type);
  static String get editItem => _t('editItem');
  static String get categoryLabel => _t('categoryLabel');
  static String get folderLabel => _t('folderLabel');
  static String get createNewFolder => _t('createNewFolder');
  static String get tagsLabel => _t('tagsLabel');
  static String get pressAddAfterEachTag => _t('pressAddAfterEachTag');
  static String get removeDocument => _t('removeDocument');
  static String get addPhoto => _t('addPhoto');
  static String get removePhoto => _t('removePhoto');
  static String get newItem => _t('newItem');
  static String get searchCategoryHint => _t('searchCategoryHint');
  static String get secureNotesAndMemos => _t('secureNotesAndMemos');
  static String get encryptedFilesUpTo25Mb => _t('encryptedFilesUpTo25Mb');
  static String get createYourOwnTemplate => _t('createYourOwnTemplate');
  static String get save => _t('save');
  static String get share => _t('share');
  static String get rotateMasterPassword => _t('rotateMasterPassword');
  static String get currentMasterPassword => _t('currentMasterPassword');
  static String get newMasterPassword => _t('newMasterPassword');
  static String get confirmNewMasterPassword => _t('confirmNewMasterPassword');
  static String get rotate => _t('rotate');
  static String get rotateRecoveryPhrase => _t('rotateRecoveryPhrase');
  static String get currentRecoveryPhrase => _t('currentRecoveryPhrase');
  static String get newRecoveryPhrase => _t('newRecoveryPhrase');
  static String get confirmRecoveryPhrase => _t('confirmRecoveryPhrase');
  static String get howVaultUnlockWorks => _t('howVaultUnlockWorks');
  static String get vaultFormat => _t('vaultFormat');
  static String get renameVault => _t('renameVault');
  static String get rename => _t('rename');
  static String get uploadDocument => _t('uploadDocument');
  static String get titleLabel => _t('titleLabel');
  static String get addTags => _t('addTags');
  static String get addItem => _t('addItem');
  static String get lockVault => _t('lockVault');
  static String get searchYourDataHint => _t('searchYourDataHint');
  static String get recent => _t('recent');
  static String get recentItems => _t('recentItems');
  static String get quickActions => _t('quickActions');
  static String get viewDemoPreview => _t('viewDemoPreview');
  static String get viewAll => _t('viewAll');
  static String get allItems => _t('allItems');
  static String get searchAllItemsHint => _t('searchAllItemsHint');
  static String get starredSecrets => _t('starredSecrets');
  static String get searchFavoritesHint => _t('searchFavoritesHint');
  static String get noFavoritesYet => _t('noFavoritesYet');
  static String get noFavoritesYetHint => _t('noFavoritesYetHint');
  static String get reset => _t('reset');
  static String get settingsAccount => _t('settingsAccount');
  static String get nijaUser => _t('nijaUser');
  static String get currentVersion => _t('currentVersion');
  static String get settingsSecurityTitle => _t('settingsSecurityTitle');
  static String get changeMasterPasswordSubtitle =>
      _t('changeMasterPasswordSubtitle');
  static String get lockNijaAutomatically => _t('lockNijaAutomatically');
  static String get migrateToBalancedVault => _t('migrateToBalancedVault');
  static String get securityAndEncryption => _t('securityAndEncryption');
  static String get securityAndEncryptionSubtitle =>
      _t('securityAndEncryptionSubtitle');
  static String get localBackup => _t('localBackup');
  static String get localBackupRow => _t('localBackupRow');
  static String get settingsMasterPassword => _t('settingsMasterPassword');
  static String moveItemsTo(int count) =>
      _t('moveItemsTo').replaceAll('{count}', '$count');
  static String movedItemsToFolder(int count, String folder) => _t(
    'movedItemsToFolder',
  ).replaceAll('{count}', '$count').replaceAll('{folder}', folder);
  static String copyItemsTo(int count) =>
      _t('copyItemsTo').replaceAll('{count}', '$count');
  static String copiedItemsToFolder(int count, String folder) => _t(
    'copiedItemsToFolder',
  ).replaceAll('{count}', '$count').replaceAll('{folder}', folder);
  static String deleteItemsQuestion(int count) =>
      _t('deleteItemsQuestion').replaceAll('{count}', '$count');
  static String deletedItemsCount(int count) =>
      _t('deletedItemsCount').replaceAll('{count}', '$count');
  static String moveCount(int count) =>
      _t('moveCount').replaceAll('{count}', '$count');
  static String copyCount(int count) =>
      _t('copyCount').replaceAll('{count}', '$count');
  static String deleteCount(int count) =>
      _t('deleteCount').replaceAll('{count}', '$count');
  static String get exitDemo => _t('exitDemo');
  static String get cancelSelection => _t('cancelSelection');
  static String get deselectAll => _t('deselectAll');
  static String get moveSelected => _t('moveSelected');
  static String get copySelected => _t('copySelected');
  static String get sortBy => _t('sortBy');
  static String get sortNameAsc => _t('sortNameAsc');
  static String get sortNameDesc => _t('sortNameDesc');
  static String get sortDateDesc => _t('sortDateDesc');
  static String get sortDateAsc => _t('sortDateAsc');
  static String get sortSizeDesc => _t('sortSizeDesc');
  static String get sortType => _t('sortType');
  static String get listView => _t('listView');
  static String get gridView => _t('gridView');
  static String get treeView => _t('treeView');
  static String get closeSearch => _t('closeSearch');
  static String get searchFoldersAndItems => _t('searchFoldersAndItems');
  static String get clearSearch => _t('clearSearch');
  static String get collapseSearch => _t('collapseSearch');
  static String get back => _t('back');
  static String get upToParentFolder => _t('upToParentFolder');
  static String get selectMultipleItems => _t('selectMultipleItems');
  static String get nameColumn => _t('nameColumn');
  static String get sizeColumn => _t('sizeColumn');
  static String get moveTo => _t('moveTo');
  static String get copyTo => _t('copyTo');
  static String get itemDetails => _t('itemDetails');
  static String get openDetails => _t('openDetails');
  static String get itemInfo => _t('itemInfo');
  static String get rootFolder => _t('rootFolder');
  static String get renameFolder => _t('renameFolder');
  static String deleteFolderQuestion(String name) =>
      _t('deleteFolderQuestion').replaceAll('{name}', name);
  static String get keepFiles => _t('keepFiles');
  static String get deleteAll => _t('deleteAll');
  static String get apply => _t('apply');
  static String moveNamedTo(String name) =>
      _t('moveNamedTo').replaceAll('{name}', name);
  static String movedNamedToFolder(String name, String folder) => _t(
    'movedNamedToFolder',
  ).replaceAll('{name}', name).replaceAll('{folder}', folder);
  static String copyNamedTo(String name) =>
      _t('copyNamedTo').replaceAll('{name}', name);
  static String copiedNamedToFolder(String name, String folder) => _t(
    'copiedNamedToFolder',
  ).replaceAll('{name}', name).replaceAll('{folder}', folder);
  static String get deleteItemConfirm => _t('deleteItemConfirm');
  static String get move => _t('move');
  static String get pleaseWaitForOperation => _t('pleaseWaitForOperation');
  static String get quitApplicationQuestion => _t('quitApplicationQuestion');
  static String get quitApplicationConfirm => _t('quitApplicationConfirm');
  static String get quit => _t('quit');
  static String get biometricUnlockEnabled => _t('biometricUnlockEnabled');
  static String failedToCreateVaultFile(String hint) =>
      _t('failedToCreateVaultFile').replaceAll('{hint}', hint);
  static String get unlockTimedOut => _t('unlockTimedOut');
  static String sharedTextSavedTo(String title) =>
      _t('sharedTextSavedTo').replaceAll('{title}', title);
  static String get failedToImportSecret => _t('failedToImportSecret');
  static String get noSavedVaultsFound => _t('noSavedVaultsFound');
  static String get recoveryPhraseOrderMismatch =>
      _t('recoveryPhraseOrderMismatch');
  static String get recoveryTimedOut => _t('recoveryTimedOut');
  static String get recoveryPhraseInvalid => _t('recoveryPhraseInvalid');
  static String get recoverVault => _t('recoverVault');
  static String get recoveryPhraseHint => _t('recoveryPhraseHint');
  static String get recover => _t('recover');
  static String get recoveryPhraseMustBe12Words =>
      _t('recoveryPhraseMustBe12Words');
  static String get googleSignInCancelled => _t('googleSignInCancelled');
  static String get recoverySuccessfulVaultOpened =>
      _t('recoverySuccessfulVaultOpened');
  static String get vaultMergeCancelled => _t('vaultMergeCancelled');
  static String get vaultMergedSuccessfully => _t('vaultMergedSuccessfully');
  static String failedToMergeVault(String hint) =>
      _t('failedToMergeVault').replaceAll('{hint}', hint);
  static String get allowVaultExport => _t('allowVaultExport');
  static String get cloudBackupCancelled => _t('cloudBackupCancelled');
  static String get cloudBackupCompleted => _t('cloudBackupCompleted');
  static String get unlockCloudBackup => _t('unlockCloudBackup');
  static String get cloudBackupRestored => _t('cloudBackupRestored');
  static String get backupMergedVaultQuestion =>
      _t('backupMergedVaultQuestion');
  static String get newFolder => _t('newFolder');
  static String get newFolderSubtitle => _t('newFolderSubtitle');
  static String get addItemSubtitle => _t('addItemSubtitle');
  static String get uploadFile => _t('uploadFile');
  static String get uploadFileSubtitle => _t('uploadFileSubtitle');
  static String get createNewFolderTitle => _t('createNewFolderTitle');
  static String get documentStorageUnavailable =>
      _t('documentStorageUnavailable');
  static String get failedToSaveDocument => _t('failedToSaveDocument');
  static String get migrateToBalancedQuestion =>
      _t('migrateToBalancedQuestion');
  static String get enterCurrentMasterPassword =>
      _t('enterCurrentMasterPassword');
  static String get migrateToBalanced => _t('migrateToBalanced');
  static String get vaultMigratedToBalanced => _t('vaultMigratedToBalanced');
  static String get demoPreviewAddItem => _t('demoPreviewAddItem');
  static String get failedToStoreAttachment => _t('failedToStoreAttachment');
  static String get themeSystem => _t('themeSystem');
  static String get themeLight => _t('themeLight');
  static String get themeDark => _t('themeDark');
  static String get cloudBackupUnavailable => _t('cloudBackupUnavailable');
  static String get securityModel => _t('securityModel');
  static String get yourResponsibility => _t('yourResponsibility');
  static String get localFirstStorage => _t('localFirstStorage');
  static String get sensitiveData => _t('sensitiveData');
  static String get changeTheme => _t('changeTheme');
  static String get skip => _t('skip');
  static String get debugInternalsUnavailable => _t('debugInternalsUnavailable');
  static String get unableToReadInternals => _t('unableToReadInternals');
  static String get refreshInternals => _t('refreshInternals');
  static String get automatedBackups => _t('automatedBackups');
  static String get backupTime => _t('backupTime');
  static String get localBackupSubtitle => _t('localBackupSubtitle');
  static String get backUpNow => _t('backUpNow');
  static String get cloudBackup => _t('cloudBackup');
  static String get browserBackupScope => _t('browserBackupScope');
  static String get backUpOverWifiOnly => _t('backUpOverWifiOnly');
  static String get avoidMobileDataUsage => _t('avoidMobileDataUsage');
  static String get lastBackup => _t('lastBackup');
  static String get backedUpVersion => _t('backedUpVersion');
  static String get restore => _t('restore');
  static String get storage => _t('storage');
  static String get vaultStorage => _t('vaultStorage');
  static String get data => _t('data');
  static String get webStorage => _t('webStorage');
  static String get importLabel => _t('importLabel');
  static String get exportLabel => _t('exportLabel');
  static String get exportDataToFile => _t('exportDataToFile');
  static String get encryptedExportSize => _t('encryptedExportSize');
  static String get preferences => _t('preferences');
  static String get theme => _t('theme');
  static String get chooseAppAppearance => _t('chooseAppAppearance');
  static String get categories => _t('categories');
  static String get about => _t('about');
  static String get aboutNija => _t('aboutNija');
  static String versionLabel(String version) =>
      _t('versionLabel').replaceAll('{version}', version);
  static String get debugInternals => _t('debugInternals');
  static String get showVaultInternalsTab => _t('showVaultInternalsTab');
  static String get privacyPolicy => _t('privacyPolicy');
  static String get readOurPrivacyPolicy => _t('readOurPrivacyPolicy');
  static String get termsOfUse => _t('termsOfUse');
  static String get readOurTermsAndConditions =>
      _t('readOurTermsAndConditions');
  static String get removeFromFavorites => _t('removeFromFavorites');
  static String get addToFavorites => _t('addToFavorites');
  static String get collapse => _t('collapse');
  static String get clearTitle => _t('clearTitle');
  static String get undo => _t('undo');
  static String get redo => _t('redo');
  static String get hidePhrase => _t('hidePhrase');
  static String get revealRecoveryPhrase => _t('revealRecoveryPhrase');
  static String get add => _t('add');
  static String get addTemplate => _t('addTemplate');
  static String get editTemplate => _t('editTemplate');
  static String get deleteTemplate => _t('deleteTemplate');
  static String get moveToTrashQuestion => _t('moveToTrashQuestion');
  static String get subfolderName => _t('subfolderName');
  static String get folderName => _t('folderName');
  static String get subfolderNameHint => _t('subfolderNameHint');
  static String get folderNameHint => _t('folderNameHint');
  static String get create => _t('create');
  static String createSubfolderInside(String name) =>
      _t('createSubfolderInside').replaceAll('{name}', name);
  static String get selectThisFolder => _t('selectThisFolder');
  static String get createFolder => _t('createFolder');
  static String get acceptAllFromCurrent => _t('acceptAllFromCurrent');
  static String get vaultMerge => _t('vaultMerge');
  static String get ok => _t('ok');
  static String get currentVault => _t('currentVault');
  static String get fileName => _t('fileName');
  static String get passwordForThisFile => _t('passwordForThisFile');
  static String get documentLabel => _t('documentLabel');
  static String get settings => _t('settings');

  static const Map<String, Map<String, String>> _localized = {
    'en': {
      'appName': 'Nija',
      'appNameBranding': 'निज',
      'tagline': 'Your private digital vault.',
      'welcomeLabel': 'Private information vault',
      'welcomeTitle': 'Your digital life, under your control.',
      'welcomeDescription':
          'Nija keeps the information you cannot afford to lose — passwords, identities, documents, cards and private notes — inside an encrypted vault you own.',
      'welcomeTagLocalFirst': 'Local-first',
      'welcomeTagEncrypted': 'Encrypted',
      'welcomeTagPortable': 'Portable',
      'welcomeTagNoAccount': 'No account required',
      'welcomeTypePasswords': 'Passwords',
      'welcomeTypePasswordsHint': 'Logins & secrets',
      'welcomeTypeIdentity': 'Identity',
      'welcomeTypeIdentityHint': 'Personal records',
      'welcomeTypeDocuments': 'Documents',
      'welcomeTypeDocumentsHint': 'Important files',
      'welcomeTypeNotes': 'Private notes',
      'welcomeTypeNotesHint': 'Sensitive information',
      'welcomeVaultFileTitle': 'Your vault is a file, not an account.',
      'welcomeFlowDevice': 'Your device',
      'welcomeFlowDeviceHint': 'Local-first',
      'welcomeFlowVault': 'Encrypted vault',
      'welcomeFlowVaultHint': 'You own it',
      'welcomeFlowBackup': 'Optional backup',
      'welcomeFlowBackupHint': 'Your choice',
      'entryAboutNija': 'About Nija',
      'createVault': 'Create vault',
      'openExistingVault': 'Open existing vault',
      'entryTitle': 'Your private vault',
      'entryDescription':
          'Your data stays local by default. Open a vault you already own or create a new encrypted vault.',
      'webStorageNoticeTitle': 'Web vault storage',
      'webStorageNoticeBody':
          'On the web, vault data is kept in private browser storage. Exported vault files are not updated automatically; export a fresh copy after important changes.',
      'selectKnownVault': 'Select a vault',
      'selectKnownVaultHint':
          'Choose from vaults already known on this device.',
      'openVaultFile': 'Open vault file',
      'openVaultFileHint': 'Choose an encrypted Nija vault file.',
      'createVaultHint': 'Start a fresh local vault.',
      'importData': 'Import data',
      'importDataHint': 'Import a vault file from this device.',
      'exploreDemo': 'Explore demo',
      'exploreDemoHint': 'Browse a sample vault without creating one.',
      'exploreDemoWriteBlocked': 'Create or unlock a vault to save changes.',
      'exploreDemoActiveNotice': 'Exploring sample vault. Nothing is saved.',
      'exitExploreDemo': 'Exit demo',
      'restoreFromStorage': 'Restore from cloud storage',
      'knownVaults': 'Known vaults',
      'chooseWhatToOpen': 'Choose what to open',
      'knownVaultsDescription':
          'These vaults are local references. Nija does not require an account.',
      'selectDifferentVaultFile': 'Select different vault file',
      'selectVault': 'Select vault',
      'localVaultReference': 'Local vault · This device',
      'webVaultPrivateStorage': 'Browser private storage',
      'appVaultPrivateStorage': 'App private storage',
      'selectedVaultFile': 'selected file',
      'lastOpened': 'Last opened',
      'neverOpened': 'Not opened yet',
      'noExistingVaultFound': 'No existing vault found. Create a vault first.',
      'wrongVaultPassword': 'Wrong vault password.',
      'selectVaultToOpen': 'Select vault to open',
      'noSavedVaultLocations': 'No saved vault locations yet.',
      'importVaultToContinue':
          'Import a vault file from your device to continue.',
      'importVaultFromDevice': 'Import vault from device',
      'importVaultFromCloud': 'Import vault from cloud',
      'cloudVaultsSection': 'Cloud backups',
      'cloudVaultsDescription':
          'Choose the Google Drive backup you want to restore.',
      'googleDriveBackup': 'Google Drive backup',
      'lastUpdated': 'Last updated',
      'vaultImportedSuccess': 'Vault imported successfully.',
      'vaultImportFailed': 'Failed to import vault file.',
      'vaultExportedSuccess': 'Vault exported successfully.',
      'vaultExportFailed': 'Failed to export vault.',
      'vaultExportCancelled': 'Vault export cancelled.',
      'vaultLimitReached':
          'Free Nija supports one vault. Upgrade storage on Android to use multiple vaults.',
      'valueLocalFirst': 'Local-first',
      'valueZeroKnowledge': 'Zero-knowledge',
      'valuePortableFile': 'Portable vault file',
      'step1Of2': 'Step 1 of 2',
      'step2Of2': 'Step 2 of 2',
      'chooseGuardian': 'Choose Guardian',
      'guardianHelper':
          'A Guardian is a simple name for your vault protection profile.',
      'masterPassword': 'Master password',
      'confirmPassword': 'Confirm password',
      'createEncryptedVault': 'Create encrypted vault',
      'masterPasswordGuidance':
          'Your security belongs to you. Choose a long, unique master password you can remember. We do not enforce password rules.',
      'recoveryPhrase': 'Recovery phrase',
      'recoveryOffline': 'Save this offline.',
      'recoveryWarning':
          'Write this down on paper and keep it somewhere safe. Never store it in screenshots or chats.',
      'recoverySavedInVault':
          'Your recovery phrase is also saved inside your encrypted vault.',
      'savedMyPhrase': 'I saved my phrase',
      'printRecoverySheet': 'Print recovery sheet',
      'copyRecoveryPhrase': 'Copy phrase',
      'recoveryCopied': 'Recovery phrase copied.',
      'printRecoveryTitle': 'Recovery sheet preview',
      'printRecoveryHint': 'Use this text for offline print/save.',
      'vaultCreated': 'Vault created',
      'vaultCreatedMessage':
          'Your encrypted vault file is ready. Only your master password can unlock it.',
      'continueToUnlock': 'Open vault',
      'chooseVaultLocation': 'Choose vault location',
      'unlockVault': 'Unlock vault',
      'unlockHelper': 'Protected by Owl Guardian',
      'unlock': 'Unlock',
      'webLoginWelcomeBack': 'Welcome back!',
      'webLoginSubtitle': 'Login to access your vault',
      'webPrivateByDefault': 'Private by default',
      'webYourVaultYourRules': 'Your vault.\nYour rules.',
      'webVaultIntro':
          'Open an existing encrypted vault or create a new one. No Nija account is required.',
      'webNoNijaAccount': 'No Nija account',
      'webLocalMode': 'Local mode',
      'webVaultStartsHere': 'Your vault starts here',
      'webVaultStartsHereSubtitle':
          'Open something you already own, or create a fresh encrypted vault on this device.',
      'webOpenVault': 'Open a vault',
      'webCreateNewVault': 'Create a new vault',
      'webRecentVaults': 'Recent vaults',
      'webRecentVaultsHint':
          'Continue from a vault already known on this device',
      'webRestoreCloudStorage': 'Restore from cloud storage',
      'webHideCloudStorage': 'Hide cloud storage',
      'webStorageAccessOnly':
          'Storage access only. Connecting a provider does not create a Nija account.',
      'webLastOpened': 'Last opened',
      'webYourDataStaysYours': 'Your data stays yours.',
      'webOfflineReady': 'Offline ready',
      'webEncryptedVaults': 'Encrypted vaults',
      'webNoTracking': 'No tracking',
      'webConnectStorage': 'Connect storage',
      'webConnectStorageMessage':
          'Nija will open the provider so you can choose an encrypted vault backup. Your vault password and decrypted contents stay on your device.',
      'webKnownVaultsAppearHere': 'Known vaults appear here',
      'webPersonalVault': 'Personal Vault',
      'webRailPrivateArchive': 'private archive',
      'webStatusLocalNoAccount': 'local mode · no account',
      'webEntryIndex': '01 / ENTRY',
      'webPrivateArchiveTitle': 'Your private\narchive.',
      'webArchiveIntro':
          'Nija is a vault you own, not an account you rent. Open an existing vault, create a new one, or restore an encrypted copy from storage you control.',
      'webStoredLocallyDefault': 'Stored locally by default',
      'webEncryptedBeforeLeaves': 'Encrypted before it leaves your device',
      'webVaultAccess': 'Vault access',
      'webWhatWouldYouLike': 'What would you like to do?',
      'webOpenVaultHint':
          'Choose an encrypted Nija vault file from this device.',
      'webCreateVaultHint': 'Start a fresh private vault stored locally.',
      'webContinueRecent': 'Continue recent',
      'webContinueRecentHint':
          'Reopen a vault Nija already knows on this device.',
      'webImportData': 'Import data',
      'webImportDataHint': 'Create a new vault from a supported export.',
      'webPersonalVaultDetail': 'Today · 4:32 PM · this device',
      'webDocumentsVault': 'Documents',
      'webDocumentsVaultDetail': 'Aug 9 · external file',
      'webPrivateByDesignFooter': 'Nija / private by design',
      'webOfflineEncryptedNoTracking':
          'offline ready · encrypted · no tracking',
      'webNewVault': 'New vault',
      'webCreateSomethingPrivate': 'Create something private',
      'webCreateModalBody':
          'Your vault is created on this device. You decide later if you want to export or back it up.',
      'webStartEmpty': 'Start empty',
      'webStartEmptyHint': 'Create a clean vault from scratch.',
      'webStartFromImport': 'Start from import',
      'webStartFromImportHint': 'Bring data from a supported export.',
      'webExternalStorage': 'External storage',
      'webOpenProvider': 'Open provider',
      'webUnlockAccess': 'Vault unlock',
      'webUnlockQuestion': 'Unlock your vault',
      'webUnlockHint':
          'Enter your master password to open the selected encrypted vault on this device.',
      'webRecoverWithPhrase': 'Recover with phrase',
      'webLocalYours': '100% local. 100% yours.',
      'pwaInstallAddToComputer': 'Add to computer',
      'pwaInstallAddToHomeScreen': 'Add to Home Screen',
      'pwaInstallDownloadApp': 'Download app',
      'pwaInstallSignCompact': 'Install',
      'pwaInstallComputerHint': 'Install Nija as a desktop app on this device.',
      'pwaInstallHomeScreenHint':
          'Install Nija on your home screen for quick access.',
      'pwaInstallAccepted': 'Nija was added to this device.',
      'pwaInstallDismissed': 'Install was cancelled.',
      'pwaInstallUnavailable':
          'Install is not available in this browser yet. Try Chrome or Edge, or use the browser menu.',
      'pwaInstallIosTitle': 'Add Nija to Home Screen',
      'pwaInstallDesktopSafariTitle': 'Add Nija to your Mac',
      'pwaInstallStepsIntro':
          'Follow these steps in Safari to install Nija like an app.',
      'pwaInstallStepsDone': 'Got it',
      'pwaInstallIosStep1':
          'Tap the Share button in Safari\u2019s toolbar (square with an arrow).',
      'pwaInstallIosStep2': 'Scroll down and tap Add to Home Screen.',
      'pwaInstallIosStep3': 'Tap Add in the top-right corner.',
      'pwaInstallDesktopSafariStep1': 'Click Share in Safari\u2019s toolbar.',
      'pwaInstallDesktopSafariStep2': 'Choose Add to Dock.',
      'pwaInstallDesktopSafariStep3':
          'Open Nija from your Dock for an app-like experience.',
      'cancel': 'Cancel',
      'continueLabel': 'Continue',
      'close': 'Close',
      'webLoginEmail': 'Email',
      'webLoginEmailHint': 'Optional local label',
      'webLoginPasswordHint': 'Enter your vault password',
      'webForgotPassword': 'Forgot password?',
      'webOrContinueWith': 'or continue with',
      'webContinueAsGuest': 'Continue as Guest',
      'webLimitedAccess':
          'Limited access. Data will be stored only on this device.',
      'webDontHaveVault': "Don't have a vault?",
      'webCreateOne': 'Create one',
      'webDataBelongsToYou': 'Your data belongs to you.',
      'webStoreSecureIt': 'Store it. Secure it. Access it anywhere.',
      'webAccessAnywhere': 'Access anywhere',
      'webEndToEndEncrypted': 'End-to-end encrypted',
      'selectDifferentVault': 'Select different vault',
      'useBiometricUnlock': 'Use biometrics',
      'useFingerprintUnlock': 'Use fingerprint',
      'useFaceIdUnlock': 'Use Face ID',
      'useDeviceLockUnlock': 'Use device lock',
      'biometricAuthenticateReason': 'Authenticate to unlock your vault',
      'biometricComingSoon': 'Biometric unlock integration coming soon.',
      'webBiometricRequiresUpdatedBrowser':
          'Update your browser to enable secure WebAuthn device unlock on web.',
      'unlockImportedVaultTitle': 'Unlock imported vault',
      'openWithPassword': 'Open with password',
      'webBiometricLegacyCleared':
          'Previous web unlock data was removed. Enable device unlock again after updating your browser.',
      'webBiometricEnableFailed':
          'Could not enable device unlock. Confirm with Touch ID or Windows Hello, then try again.',
      'webBiometricConfirmEnable':
          'Tap confirm to register this device. You may be asked twice: once to create the unlock key, then once to verify it.',
      'webBiometricUseSessionInstead':
          'Secure device unlock is not available in this browser yet. Use your master password until WebAuthn PRF is available.',
      'webBiometricUnavailableTitle': 'Device unlock unavailable',
      'webBiometricUnavailableIntro':
          'This browser or device cannot use secure WebAuthn PRF unlock yet. Use your master password until secure device unlock is available.',
      'webBiometricUnavailableStep1':
          'Use a browser and device that support WebAuthn PRF with user verification.',
      'webBiometricUnavailableStep2':
          'Open Nija over https:// or localhost (not an insecure http:// address).',
      'webBiometricUnavailableStep3':
          'Reload the page after changing browser or address.',
      'webBiometricUnavailableStep4':
          'After the vault locks, unlock it with your master password.',
      'webBiometricPlatformUnavailableTitle': 'Touch ID not ready',
      'webBiometricPlatformUnavailableIntro':
          'Your browser supports device unlock, but Touch ID or Windows Hello is not available yet on this device.',
      'webBiometricPlatformUnavailableStep1':
          'In System Settings, confirm Touch ID is set up and at least one fingerprint is enrolled.',
      'webBiometricPlatformUnavailableStep2':
          'In Chrome, check Settings → Privacy and security → Site settings → Additional permissions → Passkeys.',
      'webBiometricPlatformUnavailableStep3':
          'Reload Nija on the same address (localhost or 127.0.0.1 — do not switch between them).',
      'webBiometricPlatformUnavailableStep4':
          'Try enabling device unlock again from Settings, or use your master password after locking.',
      'webBiometricRegistrationFailedTitle': 'Device unlock setup failed',
      'webBiometricRegistrationFailedIntro':
          'Your browser is up to date, but secure device unlock could not finish. This is usually Touch ID approval, missing PRF support, or an old passkey blocking setup.',
      'webBiometricRegistrationFailedStep1':
          'Tap Confirm with Touch ID and approve every system prompt.',
      'webBiometricRegistrationFailedStep2':
          'In Chrome, open Settings → Password Manager and remove passkeys saved for localhost / Nija.',
      'webBiometricRegistrationFailedStep3':
          'Reload Nija and enable device unlock again from Settings.',
      'webBiometricRegistrationFailedStep4':
          'If it still fails, use your master password after locking.',
      'webBiometricPasskeyConflictTitle': 'Clear old passkey first',
      'webBiometricPasskeyConflictIntro':
          'A previous unlock setup for this vault is still saved in your browser.',
      'webBiometricPasskeyConflictStep1':
          'Open browser settings and remove passkeys for localhost / Nija.',
      'webBiometricPasskeyConflictStep2':
          'Return here and enable device unlock again.',
      'webBiometricPasskeyConflictStep3':
          'If device unlock still fails, use your master password after locking.',
      'webBiometricEnableIntro':
          'Register this browser with secure WebAuthn device lock. Your master password is wrapped by a biometric-derived key and is never stored in plain text.',
      'webBiometricEnableStep1':
          'Tap confirm below to start device verification.',
      'webBiometricEnableStep2':
          'Approve the Touch ID or Windows Hello prompt(s) that create and verify the secure unlock key.',
      'webBiometricEnableStep3':
          'After setup, use device lock on the unlock screen instead of retyping your password.',
      'webBiometricConfirmTouchId': 'Confirm with Touch ID',
      'webBiometricUseSessionUnlockAction': 'Use session unlock',
      'webBiometricSessionUnlockAcknowledged':
          'After locking, unlock with your master password.',
      'webBiometricUnlockFailed':
          'Device unlock failed. Use your master password.',
      'webSessionUnlockLabel': 'Continue this session',
      'webSessionUnlockExpired':
          'This browser session expired. Enter your master password again.',
      'webSessionUnlockEnableTitle': 'Enable session unlock?',
      'webSessionUnlockEnableIntro':
          'Skip retyping your password after the vault locks in this tab. This is less secure than device unlock and is cleared when you hide the tab.',
      'webSessionUnlockEnableStep1':
          'Your password stays in this tab\'s memory only — never written to disk.',
      'webSessionUnlockEnableStep2':
          'After locking, tap Continue this session on the unlock screen.',
      'webSessionUnlockEnableStep3':
          'Session unlock clears when you hide the tab or close the browser.',
      'webSessionUnlockEnableStep4':
          'Lock the vault before leaving your device unattended.',
      'webSessionUnlockEnableConfirm': 'Enable session unlock',
      'webSessionUnlockEnabledMessage': 'Session unlock enabled for this tab.',
      'webSessionUnlockDisabledMessage': 'Session unlock disabled.',
      'vaultHome': 'Vault home',
      'homePlaceholder': 'Vault dashboard is the next implementation step.',
      'openSettings': 'Open settings',
      'settingsTitle': 'Settings',
      'securitySection': 'Security',
      'enableBiometric': 'Enable biometric unlock',
      'biometricToggleHint':
          'Use Face ID/Fingerprint as a convenience unlock method.',
      'enableBiometricPromptTitle': 'Enable biometric unlock?',
      'enableBiometricPromptMessage':
          'Use device biometrics for faster unlock. Master password stays primary.',
      'notNow': 'Not now',
      'enable': 'Enable',
      'disable': 'Disable',
      'biometricEnableConfirmTitle': 'Enable biometric unlock?',
      'biometricEnableConfirmMessage':
          'Enable biometrics for this vault on this device?',
      'biometricDisableConfirmTitle': 'Disable biometric unlock?',
      'biometricDisableConfirmMessage':
          'Disable biometrics for this vault on this device?',
      'tabVault': 'Home',
      'tabFolders': 'Folders',
      'tabNotes': 'Favorites',
      'tabTypes': 'All Items',
      'tabSettings': 'Settings',
      'search': 'Search',
      'searchNotes': 'Search notes',
      'settingsSubtitle': 'Vault preferences',
      'language': 'Language',
      'systemDefault': 'System default',
      'lockVaultNow': 'Lock vault now',
      'typesSubtitle': 'Vault organization',
      'notesSubtitle': 'Encrypted writing',
      'createCustomType': 'Create custom type',
      'yourCustomTypes': 'Your custom types',
      'noNotesFound': 'No notes found',
      'noNotesFoundHint': 'Try another search or create a new secure note.',
      'noMatchingItems': 'No matching items',
      'noMatchingItemsHint': 'Try a different search or add a new item.',
      'noItemsYet': 'No items yet',
      'noItemsYetHint': 'Create an entry for this type to see it here.',
      'secureNotes': 'Secure Notes',
      'pinned': 'Favorites',
      'pinnedFirst': 'Favorites first',
      'languageUpdated': 'Language updated.',
      'settingsSecurity': 'Security',
      'settingsAppPin': 'App PIN',
      'settingsAppPinEnabledSubtitle':
          'Change the PIN used for quick unlock on this device',
      'settingsAppPinDisabledSubtitle':
          'Set a local PIN for quick unlock when biometrics are unavailable',
      'setUpPin': 'Set up',
      'changePin': 'Change',
      'unlockWithPin': 'Unlock with PIN',
      'appPinSetupTitle': 'Set up app PIN',
      'appPinChangeTitle': 'Change app PIN',
      'appPinUnlockTitle': 'Enter app PIN',
      'appPinSetupMessage':
          'Use a 6 digit or longer PIN for quicker unlock on this device. Your master password stays encrypted by this PIN.',
      'appPinUnavailableMessage':
          'Unlock with master password first, then set up app PIN.',
      'appPinInvalidMessage': 'PIN could not unlock this vault.',
      'appPinEnabledMessage': 'App PIN enabled.',
      'appPinChangedMessage': 'App PIN changed.',
      'appPinLabel': 'PIN',
      'appPinConfirmLabel': 'Confirm PIN',
      'appPinTooShortMessage': 'Use at least 6 digits.',
      'appPinMismatchMessage': 'PINs do not match.',
      'settingsBiometricAvailableSubtitle': 'Unlock using fingerprint or face',
      'settingsBiometricUnavailableSubtitle':
          'Secure device unlock is unavailable on this device',
      'settingsVaultBackup': 'Vault Backup',
      'settingsBiometricUnlock': 'Biometric Unlock',
      'settingsRecoveryPhrase': 'Recovery Phrase',
      'settingsAutoLock': 'Auto Lock',
      'settingsExportVault': 'Export Vault',
      'settingsDangerZone': 'Danger Zone',
      'settingsEntitlementChecking': 'Checking Google Play purchase...',
      'googlePlayAccountTitle': 'Use the right Play account',
      'googlePlayAccountMessage':
          'Google Play controls which account is used for purchases and restore. To use a different account, switch accounts in the Play Store app first, then return to Nija.',
      'googlePlayAccountContinue': 'Continue',
      'googlePlayAccountRestore': 'Restore purchase',
      'googlePlayUnexpectedResponse':
          'Google Play returned an unexpected response. Update Google Play Store and Play services, install or update Nija from Google Play, then retry.',
      'settingComingSoon': 'Settings coming soon.',
      'copySuccess': 'Copied. Clipboard will auto-clear soon.',
      'customTypeExists': 'Custom type with this name already exists.',
      'noteTags': 'Tags',
      'noteTagHint': 'Add a tag',
      'addTag': 'Add tag',
      'vaultName': 'Vault name',
      'pin': 'Favorite',
      'unpin': 'Unfavorite',
      'delete': 'Delete',
      'noteDeleted': 'Note deleted.',
      'itemDeleted': 'Item deleted.',
      'edit': 'Edit',
      'select': 'Select',
      'selected': 'selected',
      'selectAll': 'Select all',
      'clearSelection': 'Clear',
      'deleteSelected': 'Delete selected',
      'sharePlainText': 'Share plain text',
      'sharedTextCopied': 'Share text copied to clipboard.',
      'shareEncryptedFile': 'Share encrypted file',
      'encryptedShareSuccess': 'Encrypted file prepared for sharing.',
      'encryptedShareFailed': 'Failed to share encrypted file.',
      'exportEncryptedFile': 'Export encrypted file',
      'encryptedExportSuccess': 'Encrypted file exported.',
      'encryptedExportFailed': 'Failed to export encrypted file.',
      'openEncryptedSecret': 'Open encrypted secret',
      'importEncryptedSecret': 'Import encrypted secret',
      'encryptedSecretPassword': 'Password for encrypted file',
      'encryptedSecretImported': 'Encrypted secret imported.',
      'encryptedSecretImportFailed':
          'Could not import encrypted secret. Check password/file.',
      'lastAccessed': 'Last accessed',
      'entrySaved': 'Entry saved',
      'entrySavedMessage': 'Your new entry has been saved successfully.',
      'done': 'Done',
      'randomPassword': 'Random Password',
      'passphrase': 'Passphrase',
      'regenerate': 'Regenerate',
      'capitalize': 'Capitalize',
      'includeNumber': 'Include Number',
      'copy': 'Copy',
      'passwordCopied': 'Password copied to clipboard',
      'copiedToClipboard': 'Copied to clipboard',
      'visibleSecretCopied': 'Visible secret copied',
      'copyFullSecretVisible': 'Copy full secret (visible)',
      'importToVault': 'Import to vault',
      'noContent': 'No content',
      'encryptedFile': 'Encrypted file',
      'importAll': 'Import all',
      'imported': 'Imported',
      'importItem': 'Import item',
      'secureNote': 'Secure Note',
      'unableToPreviewDocument': 'Unable to preview document',
      'unableToPreviewDocumentHint':
          'The encrypted file does not contain readable document data.',
      'emptyDocument': 'Empty document',
      'emptyDocumentHint': 'There is no content to preview.',
      'imagePreviewFailed': 'Image preview failed',
      'imagePreviewFailedHint':
          'Tap to choose an app that can open this file.',
      'openingDocument': 'Opening {extension} document',
      'openingDocumentHint': 'Tap to choose an app that can preview this file.',
      'noAppCanOpenFile': 'No app can open this file.',
      'favorite': 'Favorite',
      'documentAttached': 'Document attached.',
      'unableToAttachDocument': 'Unable to attach document.',
      'documentUnavailable': 'Document unavailable.',
      'useOpenDocumentToView': 'Use Open document to view this file.',
      'previewUnavailable': '{extension} preview unavailable',
      'useOpenDocumentAnotherApp':
          'Use Open document to view this file in another app.',
      'openDocument': 'Open document',
      'shareFile': 'Share file',
      'saveCopy': 'Save copy',
      'attachmentRemoved': 'Attachment removed.',
      'unableToProcessAttachment': 'Unable to process attachment.',
      'hide': 'Hide',
      'reveal': 'Reveal',
      'shareSecurely': 'Share securely',
      'addDocument': 'Add document',
      'addIcon': 'Add Icon',
      'templateName': 'Template Name',
      'templateNameHint': 'e.g. Car Details',
      'descriptionOptional': 'Description (optional)',
      'descriptionOptionalHint': 'Add a short description',
      'next': 'Next',
      'details': 'Details',
      'fieldKeyHint': 'Field key (example: Expiry date)',
      'stringText': 'String text',
      'numberType': 'Number',
      'dateType': 'Date',
      'passwordSecretType': 'Password / secret',
      'valueType': 'Value type',
      'removeField': 'Remove field',
      'addField': 'Add field',
      'saveChanges': 'Save changes',
      'saveTemplate': 'Save template',
      'open': 'Open',
      'saveDownloadOptions': 'Save / Download options',
      'saveCopyDecrypted': 'Save copy (decrypted)',
      'exportEncryptedNija': 'Export encrypted (.nija)',
      'shareOptions': 'Share options',
      'shareDecryptedFile': 'Share decrypted file',
      'shareEncryptedNija': 'Share encrypted (.nija)',
      'sampleDocumentMetadata': 'Sample document metadata',
      'sampleDocumentMetadataHint':
          'Create a vault to store and preview real files.',
      'useOpenWithToView': 'Use Open with... to view this document.',
      'useOpenWithAnotherApp':
          'Use Open with... to view this document in another app.',
      'unableToSaveDocumentCopy': 'Unable to save document copy.',
      'enlargePreview': 'Enlarge preview',
      'exportEncrypted': 'Export encrypted',
      'closePreview': 'Close preview',
      'unableToCompleteDocumentAction': 'Unable to complete document action.',
      'useLabelToViewDocument': 'Use {label} to view this document.',
      'loadingPdf': 'Loading PDF...',
      'pdfPreviewFailed': 'PDF preview failed',
      'pdfPreviewFailedHint': 'Use Open with app to view this document.',
      'newItemOfType': 'New {type}',
      'editItem': 'Edit item',
      'categoryLabel': 'Category',
      'folderLabel': 'Folder',
      'createNewFolder': 'Create new folder',
      'tagsLabel': 'Tags',
      'pressAddAfterEachTag': 'Press add after each tag',
      'removeDocument': 'Remove document',
      'addPhoto': 'Add photo',
      'removePhoto': 'Remove photo',
      'newItem': 'New Item',
      'searchCategoryHint': 'Search category...',
      'secureNotesAndMemos': 'Secure notes and memos',
      'encryptedFilesUpTo25Mb': 'Encrypted files up to 25 MB',
      'createYourOwnTemplate': 'Create your own template',
      'save': 'Save',
      'share': 'Share',
      'rotateMasterPassword': 'Rotate master password',
      'currentMasterPassword': 'Current master password',
      'newMasterPassword': 'New master password',
      'confirmNewMasterPassword': 'Confirm new master password',
      'rotate': 'Rotate',
      'rotateRecoveryPhrase': 'Rotate recovery phrase',
      'currentRecoveryPhrase': 'Current recovery phrase',
      'newRecoveryPhrase': 'New recovery phrase',
      'confirmRecoveryPhrase': 'Confirm recovery phrase',
      'howVaultUnlockWorks': 'How vault unlock works',
      'vaultFormat': 'Vault format',
      'renameVault': 'Rename vault',
      'rename': 'Rename',
      'uploadDocument': 'Upload Document',
      'titleLabel': 'Title',
      'addTags': 'Add tags',
      'addItem': 'Add Item',
      'lockVault': 'Lock vault',
      'searchYourDataHint': 'Search your data...',
      'recent': 'Recent',
      'recentItems': 'Recent Items',
      'quickActions': 'Quick Actions',
      'viewDemoPreview': 'View demo preview',
      'viewAll': 'View all',
      'allItems': 'All Items',
      'searchAllItemsHint': 'Search all items...',
      'starredSecrets': 'Starred secrets',
      'searchFavoritesHint': 'Search favorites...',
      'noFavoritesYet': 'No favorites yet',
      'noFavoritesYetHint': 'Star items from quick actions to see them here.',
      'reset': 'Reset',
      'settingsAccount': 'Account',
      'nijaUser': 'Nija User',
      'currentVersion': 'Current version',
      'settingsSecurityTitle': 'Security',
      'changeMasterPasswordSubtitle': 'Change your master password',
      'lockNijaAutomatically': 'Lock Nija automatically',
      'migrateToBalancedVault': 'Migrate to Balanced Vault',
      'securityAndEncryption': 'Security & Encryption',
      'securityAndEncryptionSubtitle':
          'View encryption details and key info',
      'localBackup': 'Local Backup',
      'localBackupRow': 'Local backup',
      'settingsMasterPassword': 'Master Password',
      'moveItemsTo': 'Move {count} items to...',
      'movedItemsToFolder': 'Moved {count} items to "{folder}".',
      'copyItemsTo': 'Copy {count} items to...',
      'copiedItemsToFolder': 'Copied {count} items to "{folder}".',
      'deleteItemsQuestion': 'Delete {count} items?',
      'deletedItemsCount': 'Deleted {count} items.',
      'moveCount': 'Move ({count})',
      'copyCount': 'Copy ({count})',
      'deleteCount': 'Delete ({count})',
      'exitDemo': 'Exit Demo',
      'cancelSelection': 'Cancel selection',
      'deselectAll': 'Deselect All',
      'moveSelected': 'Move selected',
      'copySelected': 'Copy selected',
      'sortBy': 'Sort by',
      'sortNameAsc': 'Name (A to Z)',
      'sortNameDesc': 'Name (Z to A)',
      'sortDateDesc': 'Date (Newest first)',
      'sortDateAsc': 'Date (Oldest first)',
      'sortSizeDesc': 'Size (Largest first)',
      'sortType': 'Type',
      'listView': 'List view',
      'gridView': 'Grid view',
      'treeView': 'Tree view',
      'closeSearch': 'Close search',
      'searchFoldersAndItems': 'Search folders and items',
      'clearSearch': 'Clear search',
      'collapseSearch': 'Collapse search',
      'back': 'Back',
      'upToParentFolder': 'Up to parent folder',
      'selectMultipleItems': 'Select multiple items',
      'nameColumn': 'Name',
      'sizeColumn': 'Size',
      'moveTo': 'Move to...',
      'copyTo': 'Copy to...',
      'itemDetails': 'Item details',
      'openDetails': 'Open Details',
      'itemInfo': 'Item Info',
      'rootFolder': 'Root',
      'renameFolder': 'Rename Folder',
      'deleteFolderQuestion': 'Delete "{name}"?',
      'keepFiles': 'Keep Files',
      'deleteAll': 'Delete All',
      'apply': 'Apply',
      'moveNamedTo': 'Move "{name}" to...',
      'movedNamedToFolder': 'Moved "{name}" to "{folder}".',
      'copyNamedTo': 'Copy "{name}" to...',
      'copiedNamedToFolder': 'Copied "{name}" to "{folder}".',
      'deleteItemConfirm': 'Are you sure you want to delete this encrypted item?',
      'move': 'Move',
      'pleaseWaitForOperation': 'Please wait for the operation to finish.',
      'quitApplicationQuestion': 'Quit Application?',
      'quitApplicationConfirm': 'Are you sure you want to quit the app?',
      'quit': 'Quit',
      'biometricUnlockEnabled': 'Biometric unlock enabled.',
      'failedToCreateVaultFile': 'Failed to create vault file. {hint}',
      'unlockTimedOut': 'Unlock timed out. Please try again.',
      'sharedTextSavedTo': 'Shared text saved to {title}',
      'failedToImportSecret': 'Failed to import secret into vault.',
      'noSavedVaultsFound': 'No saved vaults found to unlock.',
      'recoveryPhraseOrderMismatch': 'Recovery phrase order does not match.',
      'recoveryTimedOut': 'Recovery timed out. Please try again.',
      'recoveryPhraseInvalid': 'Recovery phrase is invalid.',
      'recoverVault': 'Recover vault',
      'recoveryPhraseHint': '12 words separated by spaces',
      'recover': 'Recover',
      'recoveryPhraseMustBe12Words':
          'Recovery phrase must be exactly 12 words.',
      'googleSignInCancelled': 'Google account sign-in cancelled.',
      'recoverySuccessfulVaultOpened': 'Recovery successful. Vault opened.',
      'vaultMergeCancelled': 'Vault merge cancelled.',
      'vaultMergedSuccessfully': 'Vault merged successfully.',
      'failedToMergeVault': 'Failed to merge vault. {hint}',
      'allowVaultExport': 'Allow vault export',
      'cloudBackupCancelled': 'Cloud backup cancelled.',
      'cloudBackupCompleted': 'Cloud backup completed.',
      'unlockCloudBackup': 'Unlock cloud backup',
      'cloudBackupRestored': 'Cloud backup restored.',
      'backupMergedVaultQuestion': 'Backup merged vault?',
      'newFolder': 'New Folder',
      'newFolderSubtitle': 'Create a folder to organize items',
      'addItemSubtitle': 'Add password, note, card, or credential',
      'uploadFile': 'Upload File',
      'uploadFileSubtitle': 'Upload an encrypted document or attachment',
      'createNewFolderTitle': 'Create New Folder',
      'documentStorageUnavailable':
          'Document storage unavailable in this session.',
      'failedToSaveDocument': 'Failed to save document.',
      'migrateToBalancedQuestion': 'Migrate to Balanced Vault?',
      'enterCurrentMasterPassword': 'Enter current master password',
      'migrateToBalanced': 'Migrate to Balanced',
      'vaultMigratedToBalanced':
          'Vault successfully migrated to Balanced profile (Owl).',
      'demoPreviewAddItem': 'This is a demo preview. Add an item to start.',
      'failedToStoreAttachment': 'Failed to store attachment. Please retry.',
      'themeSystem': 'System',
      'themeLight': 'Light',
      'themeDark': 'Dark',
      'cloudBackupUnavailable': 'Cloud backup is currently unavailable.',
      'securityModel': 'Security model',
      'yourResponsibility': 'Your responsibility',
      'localFirstStorage': 'Local-first storage',
      'sensitiveData': 'Sensitive data',
      'changeTheme': 'Change theme',
      'skip': 'Skip',
      'debugInternalsUnavailable': 'Debug internals unavailable',
      'unableToReadInternals': 'Unable to read internals',
      'refreshInternals': 'Refresh internals',
      'automatedBackups': 'Automated backups',
      'backupTime': 'Backup time',
      'localBackupSubtitle': '2 rolling snapshots · Free version',
      'backUpNow': 'Back up now',
      'cloudBackup': 'Cloud Backup',
      'browserBackupScope': 'Browser backup scope',
      'backUpOverWifiOnly': 'Back up over Wi-Fi only',
      'avoidMobileDataUsage': 'Avoid mobile data usage',
      'lastBackup': 'Last backup',
      'backedUpVersion': 'Backed up version',
      'restore': 'Restore',
      'storage': 'Storage',
      'vaultStorage': 'Vault storage',
      'data': 'Data',
      'webStorage': 'Web storage',
      'importLabel': 'Import',
      'exportLabel': 'Export',
      'exportDataToFile': 'Export data to a file',
      'encryptedExportSize': 'Encrypted export size',
      'preferences': 'Preferences',
      'theme': 'Theme',
      'chooseAppAppearance': 'Choose app appearance',
      'categories': 'Categories',
      'about': 'About',
      'aboutNija': 'About Nija',
      'versionLabel': 'Version {version}',
      'debugInternals': 'Debug internals',
      'showVaultInternalsTab': 'Show vault internals tab',
      'privacyPolicy': 'Privacy Policy',
      'readOurPrivacyPolicy': 'Read our privacy policy',
      'termsOfUse': 'Terms of Use',
      'readOurTermsAndConditions': 'Read our terms and conditions',
      'removeFromFavorites': 'Remove from favorites',
      'addToFavorites': 'Add to favorites',
      'collapse': 'Collapse',
      'clearTitle': 'Clear title',
      'undo': 'Undo',
      'redo': 'Redo',
      'hidePhrase': 'Hide phrase',
      'revealRecoveryPhrase': 'Reveal Recovery Phrase',
      'add': 'Add',
      'addTemplate': 'Add template',
      'editTemplate': 'Edit template',
      'deleteTemplate': 'Delete template',
      'moveToTrashQuestion': 'Move to Trash?',
      'subfolderName': 'Subfolder Name',
      'folderName': 'Folder Name',
      'subfolderNameHint': 'e.g. Q1, Receipts, Invoices',
      'folderNameHint': 'e.g. Work, Taxes, Identity',
      'create': 'Create',
      'createSubfolderInside': 'Create subfolder inside "{name}"',
      'selectThisFolder': 'Select this folder',
      'createFolder': 'Create folder',
      'acceptAllFromCurrent': 'Accept all from current',
      'vaultMerge': 'Vault merge',
      'ok': 'OK',
      'currentVault': 'Current vault',
      'fileName': 'File name',
      'passwordForThisFile': 'Password for this file',
      'documentLabel': 'Document',
      'settings': 'Settings',
    },
    'es': {
      'appName': 'Nija',
      'appNameBranding': 'निज',
      'tagline': 'Tu bóveda digital privada.',
      'welcomeLabel': 'Bóveda de información privada',
      'welcomeTitle': 'Tu vida digital, bajo tu control.',
      'welcomeDescription':
          'Nija guarda la información que no puedes permitirte perder — contraseñas, identidades, documentos, tarjetas y notas privadas — dentro de una bóveda cifrada que te pertenece.',
      'welcomeTagLocalFirst': 'Local primero',
      'welcomeTagEncrypted': 'Cifrado',
      'welcomeTagPortable': 'Portátil',
      'welcomeTagNoAccount': 'Sin cuenta',
      'welcomeTypePasswords': 'Contraseñas',
      'welcomeTypePasswordsHint': 'Accesos y secretos',
      'welcomeTypeIdentity': 'Identidad',
      'welcomeTypeIdentityHint': 'Registros personales',
      'welcomeTypeDocuments': 'Documentos',
      'welcomeTypeDocumentsHint': 'Archivos importantes',
      'welcomeTypeNotes': 'Notas privadas',
      'welcomeTypeNotesHint': 'Información sensible',
      'welcomeVaultFileTitle': 'Tu bóveda es un archivo, no una cuenta.',
      'welcomeFlowDevice': 'Tu dispositivo',
      'welcomeFlowDeviceHint': 'Local primero',
      'welcomeFlowVault': 'Bóveda cifrada',
      'welcomeFlowVaultHint': 'Te pertenece',
      'welcomeFlowBackup': 'Copia opcional',
      'welcomeFlowBackupHint': 'Tu elección',
      'entryAboutNija': 'Acerca de Nija',
      'createVault': 'Crear bóveda',
      'openExistingVault': 'Abrir bóveda existente',
      'entryTitle': 'Tu bóveda privada',
      'entryDescription':
          'Tus datos permanecen locales de forma predeterminada. Abre una bóveda que ya tengas o crea una nueva bóveda cifrada.',
      'webStorageNoticeTitle': 'Almacenamiento web de bóveda',
      'webStorageNoticeBody':
          'En la web, los datos de la bóveda se guardan en almacenamiento privado del navegador. Los archivos exportados no se actualizan automáticamente; exporta una copia nueva después de cambios importantes.',
      'selectKnownVault': 'Seleccionar una bóveda',
      'selectKnownVaultHint':
          'Elige entre las bóvedas conocidas en este dispositivo.',
      'openVaultFile': 'Abrir archivo de bóveda',
      'openVaultFileHint': 'Elige un archivo de bóveda Nija cifrado.',
      'createVaultHint': 'Inicia una nueva bóveda local.',
      'importData': 'Importar datos',
      'importDataHint': 'Importa un archivo de bóveda desde este dispositivo.',
      'exploreDemo': 'Explorar demo',
      'exploreDemoHint': 'Explora una bóveda de ejemplo sin crear una.',
      'exploreDemoWriteBlocked':
          'Crea o desbloquea una bóveda para guardar cambios.',
      'exploreDemoActiveNotice':
          'Explorando bóveda de ejemplo. No se guarda nada.',
      'exitExploreDemo': 'Salir del demo',
      'restoreFromStorage': 'Restaurar desde almacenamiento en la nube',
      'knownVaults': 'Bóvedas conocidas',
      'chooseWhatToOpen': 'Elige qué abrir',
      'knownVaultsDescription':
          'Estas bóvedas son referencias locales. Nija no requiere una cuenta.',
      'selectDifferentVaultFile': 'Seleccionar otro archivo de bóveda',
      'selectVault': 'Seleccionar bóveda',
      'localVaultReference': 'Bóveda local · Este dispositivo',
      'webVaultPrivateStorage': 'Almacenamiento privado del navegador',
      'appVaultPrivateStorage': 'Almacenamiento privado de la app',
      'selectedVaultFile': 'archivo seleccionado',
      'lastOpened': 'Última apertura',
      'neverOpened': 'Aún no se abrió',
      'noExistingVaultFound':
          'No se encontró una bóveda existente. Crea una bóveda primero.',
      'wrongVaultPassword': 'Contraseña de bóveda incorrecta.',
      'selectVaultToOpen': 'Selecciona una bóveda para abrir',
      'noSavedVaultLocations': 'Aún no hay ubicaciones de bóveda guardadas.',
      'importVaultToContinue':
          'Importa un archivo de bóveda desde tu dispositivo para continuar.',
      'importVaultFromDevice': 'Importar bóveda del dispositivo',
      'importVaultFromCloud': 'Importar bóveda desde la nube',
      'cloudVaultsSection': 'Copias en la nube',
      'cloudVaultsDescription':
          'Elige la copia de Google Drive que quieres restaurar.',
      'googleDriveBackup': 'Copia de Google Drive',
      'lastUpdated': 'Última actualización',
      'vaultImportedSuccess': 'Bóveda importada correctamente.',
      'vaultImportFailed': 'No se pudo importar el archivo de bóveda.',
      'vaultExportedSuccess': 'Bóveda exportada correctamente.',
      'vaultExportFailed': 'No se pudo exportar la bóveda.',
      'vaultExportCancelled': 'Exportación de bóveda cancelada.',
      'vaultLimitReached':
          'Nija gratis admite una bóveda. Actualiza el almacenamiento en Android para usar varias bóvedas.',
      'valueLocalFirst': 'Primero local',
      'valueZeroKnowledge': 'Conocimiento cero',
      'valuePortableFile': 'Archivo de bóveda portátil',
      'step1Of2': 'Paso 1 de 2',
      'step2Of2': 'Paso 2 de 2',
      'chooseGuardian': 'Elegir guardián',
      'guardianHelper':
          'Un Guardián es un nombre simple para tu perfil de protección.',
      'masterPassword': 'Contraseña maestra',
      'confirmPassword': 'Confirmar contraseña',
      'createEncryptedVault': 'Crear bóveda cifrada',
      'masterPasswordGuidance':
          'Tu seguridad te pertenece. Elige una contraseña maestra larga y única que puedas recordar. No imponemos reglas de contraseña.',
      'recoveryPhrase': 'Frase de recuperación',
      'recoveryOffline': 'Guárdala sin conexión.',
      'recoveryWarning':
          'Anótala en papel y guárdala en un lugar seguro. Nunca la guardes en capturas o chats.',
      'recoverySavedInVault':
          'Tu frase de recuperación también se guarda dentro de tu bóveda cifrada.',
      'savedMyPhrase': 'Ya guardé mi frase',
      'printRecoverySheet': 'Imprimir hoja de recuperación',
      'copyRecoveryPhrase': 'Copiar frase',
      'recoveryCopied': 'Frase de recuperación copiada.',
      'printRecoveryTitle': 'Vista previa de recuperación',
      'printRecoveryHint': 'Usa este texto para imprimir/guardar sin conexión.',
      'vaultCreated': 'Bóveda creada',
      'vaultCreatedMessage':
          'Tu archivo de bóveda cifrada está listo. Solo tu contraseña maestra puede abrirlo.',
      'continueToUnlock': 'Abrir bóveda',
      'chooseVaultLocation': 'Elegir ubicación de la bóveda',
      'unlockVault': 'Desbloquear bóveda',
      'unlockHelper': 'Protegida por Owl Guardian',
      'unlock': 'Desbloquear',
      'selectDifferentVault': 'Seleccionar otra bóveda',
      'useBiometricUnlock': 'Usar biometría',
      'useFingerprintUnlock': 'Usar huella',
      'useFaceIdUnlock': 'Usar Face ID',
      'useDeviceLockUnlock': 'Usar bloqueo del dispositivo',
      'biometricAuthenticateReason': 'Autentícate para desbloquear tu bóveda',
      'biometricComingSoon':
          'La integración biométrica estará disponible pronto.',
      'vaultHome': 'Inicio de la bóveda',
      'homePlaceholder':
          'El panel de la bóveda es el siguiente paso de implementación.',
      'openSettings': 'Abrir configuración',
      'settingsTitle': 'Configuración',
      'securitySection': 'Seguridad',
      'enableBiometric': 'Activar desbloqueo biométrico',
      'biometricToggleHint':
          'Usa Face ID/Huella como método de desbloqueo rápido.',
      'enableBiometricPromptTitle': '¿Activar desbloqueo biométrico?',
      'enableBiometricPromptMessage':
          'Usa la biometría del dispositivo para desbloquear más rápido. La contraseña maestra sigue siendo principal.',
      'notNow': 'Ahora no',
      'enable': 'Activar',
      'disable': 'Desactivar',
      'biometricEnableConfirmTitle': '¿Activar desbloqueo biométrico?',
      'biometricEnableConfirmMessage':
          '¿Activar biometría para esta bóveda en este dispositivo?',
      'biometricDisableConfirmTitle': '¿Desactivar desbloqueo biométrico?',
      'biometricDisableConfirmMessage':
          '¿Desactivar biometría para esta bóveda en este dispositivo?',
      'tabVault': 'Inicio',
      'tabFolders': 'Carpetas',
      'tabNotes': 'Favoritos',
      'tabTypes': 'Todos',
      'tabSettings': 'Ajustes',
      'search': 'Buscar',
      'searchNotes': 'Buscar notas',
      'settingsSubtitle': 'Preferencias de la bóveda',
      'language': 'Idioma',
      'systemDefault': 'Predeterminado del sistema',
      'lockVaultNow': 'Bloquear bóveda ahora',
      'typesSubtitle': 'Organización de la bóveda',
      'notesSubtitle': 'Escritura cifrada',
      'createCustomType': 'Crear tipo personalizado',
      'yourCustomTypes': 'Tus tipos personalizados',
      'noNotesFound': 'No se encontraron notas',
      'noNotesFoundHint': 'Prueba otra búsqueda o crea una nota segura.',
      'noMatchingItems': 'No hay elementos coincidentes',
      'noMatchingItemsHint': 'Prueba otra búsqueda o agrega un elemento nuevo.',
      'noItemsYet': 'Aún no hay elementos',
      'noItemsYetHint': 'Crea una entrada de este tipo para verla aquí.',
      'secureNotes': 'Notas seguras',
      'pinned': 'Favoritos',
      'pinnedFirst': 'Favoritos primero',
      'languageUpdated': 'Idioma actualizado.',
      'settingsSecurity': 'Seguridad',
      'settingsAppPin': 'PIN de la app',
      'settingsAppPinEnabledSubtitle':
          'Cambia el PIN usado para desbloqueo rápido en este dispositivo',
      'settingsAppPinDisabledSubtitle':
          'Configura un PIN local cuando la biometría no esté disponible',
      'setUpPin': 'Configurar',
      'changePin': 'Cambiar',
      'unlockWithPin': 'Desbloquear con PIN',
      'appPinSetupTitle': 'Configurar PIN de la app',
      'appPinChangeTitle': 'Cambiar PIN de la app',
      'appPinUnlockTitle': 'Ingresa el PIN de la app',
      'appPinSetupMessage':
          'Usa un PIN de 6 dígitos o más para desbloquear más rápido en este dispositivo. Tu contraseña maestra queda cifrada por este PIN.',
      'appPinUnavailableMessage':
          'Desbloquea con la contraseña maestra primero y luego configura el PIN.',
      'appPinInvalidMessage': 'El PIN no pudo desbloquear esta bóveda.',
      'appPinEnabledMessage': 'PIN de la app activado.',
      'appPinChangedMessage': 'PIN de la app cambiado.',
      'appPinLabel': 'PIN',
      'appPinConfirmLabel': 'Confirmar PIN',
      'appPinTooShortMessage': 'Usa al menos 6 dígitos.',
      'appPinMismatchMessage': 'Los PIN no coinciden.',
      'settingsBiometricAvailableSubtitle': 'Desbloquea usando huella o rostro',
      'settingsBiometricUnavailableSubtitle':
          'El desbloqueo seguro del dispositivo no está disponible',
      'settingsVaultBackup': 'Copia de seguridad de la bóveda',
      'settingsBiometricUnlock': 'Desbloqueo biométrico',
      'settingsRecoveryPhrase': 'Frase de recuperación',
      'settingsAutoLock': 'Bloqueo automático',
      'settingsExportVault': 'Exportar bóveda',
      'settingsDangerZone': 'Zona de peligro',
      'settingsEntitlementChecking': 'Comprobando compra de Google Play...',
      'googlePlayAccountTitle': 'Usa la cuenta correcta de Play',
      'googlePlayAccountMessage':
          'Google Play controla qué cuenta se usa para compras y restauración. Para usar otra cuenta, cambia de cuenta en la app Play Store y vuelve a Nija.',
      'googlePlayAccountContinue': 'Continuar',
      'googlePlayAccountRestore': 'Restaurar compra',
      'googlePlayUnexpectedResponse':
          'Google Play devolvió una respuesta inesperada. Actualiza Google Play Store y Servicios de Play, instala o actualiza Nija desde Google Play y vuelve a intentarlo.',
      'settingComingSoon': 'Ajustes disponibles próximamente.',
      'copySuccess': 'Copiado. El portapapeles se borrará pronto.',
      'customTypeExists': 'Ya existe un tipo personalizado con este nombre.',
      'noteTags': 'Etiquetas',
      'noteTagHint': 'Agregar etiqueta',
      'addTag': 'Agregar etiqueta',
      'vaultName': 'Nombre de la bóveda',
      'pin': 'Favorito',
      'unpin': 'Quitar favorito',
      'delete': 'Eliminar',
      'noteDeleted': 'Nota eliminada.',
      'itemDeleted': 'Elemento eliminado.',
      'edit': 'Editar',
      'select': 'Seleccionar',
      'selected': 'seleccionados',
      'selectAll': 'Seleccionar todo',
      'clearSelection': 'Limpiar',
      'deleteSelected': 'Eliminar seleccionados',
      'sharePlainText': 'Compartir texto plano',
      'sharedTextCopied': 'Texto para compartir copiado al portapapeles.',
      'shareEncryptedFile': 'Compartir archivo cifrado',
      'encryptedShareSuccess': 'Archivo cifrado preparado para compartir.',
      'encryptedShareFailed': 'No se pudo compartir el archivo cifrado.',
      'exportEncryptedFile': 'Exportar archivo cifrado',
      'encryptedExportSuccess': 'Archivo cifrado exportado.',
      'encryptedExportFailed': 'No se pudo exportar el archivo cifrado.',
      'openEncryptedSecret': 'Abrir secreto cifrado',
      'importEncryptedSecret': 'Importar secreto cifrado',
      'encryptedSecretPassword': 'Contraseña del archivo cifrado',
      'encryptedSecretImported': 'Secreto cifrado importado.',
      'encryptedSecretImportFailed':
          'No se pudo importar el secreto cifrado. Verifica contraseña/archivo.',
      'lastAccessed': 'Último acceso',
      'entrySaved': 'Entrada guardada',
      'entrySavedMessage': 'Tu nueva entrada se guardó correctamente.',
      'done': 'Listo',
      'randomPassword': 'Contraseña aleatoria',
      'passphrase': 'Frase de contraseña',
      'regenerate': 'Regenerar',
      'capitalize': 'Mayúsculas',
      'includeNumber': 'Incluir número',
      'copy': 'Copiar',
      'passwordCopied': 'Contraseña copiada al portapapeles',
      'copiedToClipboard': 'Copiado al portapapeles',
      'visibleSecretCopied': 'Secreto visible copiado',
      'copyFullSecretVisible': 'Copiar secreto completo (visible)',
      'importToVault': 'Importar a la bóveda',
      'noContent': 'Sin contenido',
      'encryptedFile': 'Archivo cifrado',
      'importAll': 'Importar todo',
      'imported': 'Importado',
      'importItem': 'Importar elemento',
      'secureNote': 'Nota segura',
      'unableToPreviewDocument': 'No se pudo previsualizar el documento',
      'unableToPreviewDocumentHint':
          'El archivo cifrado no contiene datos de documento legibles.',
      'emptyDocument': 'Documento vacío',
      'emptyDocumentHint': 'No hay contenido para previsualizar.',
      'imagePreviewFailed': 'Error al previsualizar la imagen',
      'imagePreviewFailedHint':
          'Toca para elegir una aplicación que pueda abrir este archivo.',
      'openingDocument': 'Abriendo documento {extension}',
      'openingDocumentHint':
          'Toca para elegir una aplicación que pueda previsualizar este archivo.',
      'noAppCanOpenFile': 'Ninguna aplicación puede abrir este archivo.',
      'favorite': 'Favorito',
      'documentAttached': 'Documento adjuntado.',
      'unableToAttachDocument': 'No se pudo adjuntar el documento.',
      'documentUnavailable': 'Documento no disponible.',
      'useOpenDocumentToView': 'Usa Abrir documento para ver este archivo.',
      'previewUnavailable': 'Vista previa de {extension} no disponible',
      'useOpenDocumentAnotherApp':
          'Usa Abrir documento para ver este archivo en otra aplicación.',
      'openDocument': 'Abrir documento',
      'shareFile': 'Compartir archivo',
      'saveCopy': 'Guardar copia',
      'attachmentRemoved': 'Adjunto eliminado.',
      'unableToProcessAttachment': 'No se pudo procesar el adjunto.',
      'hide': 'Ocultar',
      'reveal': 'Mostrar',
      'shareSecurely': 'Compartir de forma segura',
      'addDocument': 'Agregar documento',
      'addIcon': 'Agregar icono',
      'templateName': 'Nombre de la plantilla',
      'templateNameHint': 'ej. Detalles del auto',
      'descriptionOptional': 'Descripción (opcional)',
      'descriptionOptionalHint': 'Agrega una breve descripción',
      'next': 'Siguiente',
      'details': 'Detalles',
      'fieldKeyHint': 'Clave del campo (ejemplo: Fecha de vencimiento)',
      'stringText': 'Texto',
      'numberType': 'Número',
      'dateType': 'Fecha',
      'passwordSecretType': 'Contraseña / secreto',
      'valueType': 'Tipo de valor',
      'removeField': 'Eliminar campo',
      'addField': 'Agregar campo',
      'saveChanges': 'Guardar cambios',
      'saveTemplate': 'Guardar plantilla',
      'open': 'Abrir',
      'saveDownloadOptions': 'Opciones de guardado / descarga',
      'saveCopyDecrypted': 'Guardar copia (descifrada)',
      'exportEncryptedNija': 'Exportar cifrado (.nija)',
      'shareOptions': 'Opciones para compartir',
      'shareDecryptedFile': 'Compartir archivo descifrado',
      'shareEncryptedNija': 'Compartir cifrado (.nija)',
      'sampleDocumentMetadata': 'Metadatos de documento de muestra',
      'sampleDocumentMetadataHint':
          'Crea una bóveda para almacenar y previsualizar archivos reales.',
      'useOpenWithToView': 'Usa Abrir con... para ver este documento.',
      'useOpenWithAnotherApp':
          'Usa Abrir con... para ver este documento en otra aplicación.',
      'unableToSaveDocumentCopy':
          'No se pudo guardar la copia del documento.',
      'enlargePreview': 'Ampliar vista previa',
      'exportEncrypted': 'Exportar cifrado',
      'closePreview': 'Cerrar vista previa',
      'unableToCompleteDocumentAction':
          'No se pudo completar la acción del documento.',
      'useLabelToViewDocument': 'Usa {label} para ver este documento.',
      'loadingPdf': 'Cargando PDF...',
      'pdfPreviewFailed': 'Error al previsualizar el PDF',
      'pdfPreviewFailedHint':
          'Usa Abrir con aplicación para ver este documento.',
      'newItemOfType': 'Nuevo {type}',
      'editItem': 'Editar elemento',
      'categoryLabel': 'Categoría',
      'folderLabel': 'Carpeta',
      'createNewFolder': 'Crear nueva carpeta',
      'tagsLabel': 'Etiquetas',
      'pressAddAfterEachTag': 'Presiona agregar después de cada etiqueta',
      'removeDocument': 'Eliminar documento',
      'addPhoto': 'Agregar foto',
      'removePhoto': 'Eliminar foto',
      'newItem': 'Nuevo elemento',
      'searchCategoryHint': 'Buscar categoría...',
      'secureNotesAndMemos': 'Notas seguras y recordatorios',
      'encryptedFilesUpTo25Mb': 'Archivos cifrados de hasta 25 MB',
      'createYourOwnTemplate': 'Crea tu propia plantilla',
      'save': 'Guardar',
      'share': 'Compartir',
      'rotateMasterPassword': 'Rotar contraseña maestra',
      'currentMasterPassword': 'Contraseña maestra actual',
      'newMasterPassword': 'Nueva contraseña maestra',
      'confirmNewMasterPassword': 'Confirmar nueva contraseña maestra',
      'rotate': 'Rotar',
      'rotateRecoveryPhrase': 'Rotar frase de recuperación',
      'currentRecoveryPhrase': 'Frase de recuperación actual',
      'newRecoveryPhrase': 'Nueva frase de recuperación',
      'confirmRecoveryPhrase': 'Confirmar frase de recuperación',
      'howVaultUnlockWorks': 'Cómo funciona el desbloqueo de la bóveda',
      'vaultFormat': 'Formato de la bóveda',
      'renameVault': 'Renombrar bóveda',
      'rename': 'Renombrar',
      'uploadDocument': 'Subir documento',
      'titleLabel': 'Título',
      'addTags': 'Agregar etiquetas',
      'addItem': 'Agregar elemento',
      'lockVault': 'Bloquear bóveda',
      'searchYourDataHint': 'Buscar tus datos...',
      'recent': 'Recientes',
      'recentItems': 'Elementos recientes',
      'quickActions': 'Acciones rápidas',
      'viewDemoPreview': 'Ver vista previa de demostración',
      'viewAll': 'Ver todo',
      'allItems': 'Todos los elementos',
      'searchAllItemsHint': 'Buscar todos los elementos...',
      'starredSecrets': 'Secretos destacados',
      'searchFavoritesHint': 'Buscar favoritos...',
      'noFavoritesYet': 'Aún no hay favoritos',
      'noFavoritesYetHint':
          'Marca elementos desde acciones rápidas para verlos aquí.',
      'reset': 'Restablecer',
      'settingsAccount': 'Cuenta',
      'nijaUser': 'Usuario de Nija',
      'currentVersion': 'Versión actual',
      'settingsSecurityTitle': 'Seguridad',
      'changeMasterPasswordSubtitle': 'Cambia tu contraseña maestra',
      'lockNijaAutomatically': 'Bloquear Nija automáticamente',
      'migrateToBalancedVault': 'Migrar a bóveda equilibrada',
      'securityAndEncryption': 'Seguridad y cifrado',
      'securityAndEncryptionSubtitle':
          'Ver detalles de cifrado e información de claves',
      'localBackup': 'Copia de seguridad local',
      'localBackupRow': 'Copia de seguridad local (dispositivo)',
      'settingsMasterPassword': 'Contraseña maestra',
      'moveItemsTo': 'Mover {count} elementos a...',
      'movedItemsToFolder': 'Se movieron {count} elementos a "{folder}".',
      'copyItemsTo': 'Copiar {count} elementos a...',
      'copiedItemsToFolder': 'Se copiaron {count} elementos a "{folder}".',
      'deleteItemsQuestion': '¿Eliminar {count} elementos?',
      'deletedItemsCount': 'Se eliminaron {count} elementos.',
      'moveCount': 'Mover ({count})',
      'copyCount': 'Copiar ({count})',
      'deleteCount': 'Eliminar ({count})',
      'exitDemo': 'Salir de la demo',
      'cancelSelection': 'Cancelar selección',
      'deselectAll': 'Deseleccionar todo',
      'moveSelected': 'Mover seleccionados',
      'copySelected': 'Copiar seleccionados',
      'sortBy': 'Ordenar por',
      'sortNameAsc': 'Nombre (A a Z)',
      'sortNameDesc': 'Nombre (Z a A)',
      'sortDateDesc': 'Fecha (Más reciente primero)',
      'sortDateAsc': 'Fecha (Más antiguo primero)',
      'sortSizeDesc': 'Tamaño (Mayor primero)',
      'sortType': 'Tipo',
      'listView': 'Vista de lista',
      'gridView': 'Vista de cuadrícula',
      'treeView': 'Vista de árbol',
      'closeSearch': 'Cerrar búsqueda',
      'searchFoldersAndItems': 'Buscar carpetas y elementos',
      'clearSearch': 'Limpiar búsqueda',
      'collapseSearch': 'Contraer búsqueda',
      'back': 'Atrás',
      'upToParentFolder': 'Subir a la carpeta superior',
      'selectMultipleItems': 'Seleccionar múltiples elementos',
      'nameColumn': 'Nombre',
      'sizeColumn': 'Tamaño',
      'moveTo': 'Mover a...',
      'copyTo': 'Copiar a...',
      'itemDetails': 'Detalles del elemento',
      'openDetails': 'Abrir detalles',
      'itemInfo': 'Información del elemento',
      'rootFolder': 'Raíz',
      'renameFolder': 'Renombrar carpeta',
      'deleteFolderQuestion': '¿Eliminar "{name}"?',
      'keepFiles': 'Conservar archivos',
      'deleteAll': 'Eliminar todo',
      'apply': 'Aplicar',
      'moveNamedTo': 'Mover "{name}" a...',
      'movedNamedToFolder': 'Se movió "{name}" a "{folder}".',
      'copyNamedTo': 'Copiar "{name}" a...',
      'copiedNamedToFolder': 'Se copió "{name}" a "{folder}".',
      'deleteItemConfirm':
          '¿Estás seguro de que deseas eliminar este elemento cifrado?',
      'move': 'Mover',
      'pleaseWaitForOperation': 'Por favor espera a que termine la operación.',
      'quitApplicationQuestion': '¿Salir de la aplicación?',
      'quitApplicationConfirm':
          '¿Estás seguro de que deseas salir de la aplicación?',
      'quit': 'Salir',
      'biometricUnlockEnabled': 'Desbloqueo biométrico habilitado.',
      'failedToCreateVaultFile': 'No se pudo crear el archivo de bóveda. {hint}',
      'unlockTimedOut': 'El desbloqueo expiró. Inténtalo de nuevo.',
      'sharedTextSavedTo': 'Texto compartido guardado en {title}',
      'failedToImportSecret': 'No se pudo importar el secreto a la bóveda.',
      'noSavedVaultsFound':
          'No se encontraron bóvedas guardadas para desbloquear.',
      'recoveryPhraseOrderMismatch':
          'El orden de la frase de recuperación no coincide.',
      'recoveryTimedOut': 'La recuperación expiró. Inténtalo de nuevo.',
      'recoveryPhraseInvalid': 'La frase de recuperación no es válida.',
      'recoverVault': 'Recuperar bóveda',
      'recoveryPhraseHint': '12 palabras separadas por espacios',
      'recover': 'Recuperar',
      'recoveryPhraseMustBe12Words':
          'La frase de recuperación debe tener exactamente 12 palabras.',
      'googleSignInCancelled': 'Inicio de sesión con Google cancelado.',
      'recoverySuccessfulVaultOpened': 'Recuperación exitosa. Bóveda abierta.',
      'vaultMergeCancelled': 'Fusión de bóvedas cancelada.',
      'vaultMergedSuccessfully': 'Bóveda fusionada correctamente.',
      'failedToMergeVault': 'No se pudo fusionar la bóveda. {hint}',
      'allowVaultExport': 'Permitir exportación de bóveda',
      'cloudBackupCancelled': 'Copia en la nube cancelada.',
      'cloudBackupCompleted': 'Copia en la nube completada.',
      'unlockCloudBackup': 'Desbloquear copia en la nube',
      'cloudBackupRestored': 'Copia en la nube restaurada.',
      'backupMergedVaultQuestion': '¿Respaldar bóveda fusionada?',
      'newFolder': 'Nueva carpeta',
      'newFolderSubtitle': 'Crea una carpeta para organizar elementos',
      'addItemSubtitle': 'Agrega contraseña, nota, tarjeta o credencial',
      'uploadFile': 'Subir archivo',
      'uploadFileSubtitle': 'Sube un documento o adjunto cifrado',
      'createNewFolderTitle': 'Crear nueva carpeta',
      'documentStorageUnavailable':
          'El almacenamiento de documentos no está disponible en esta sesión.',
      'failedToSaveDocument': 'No se pudo guardar el documento.',
      'migrateToBalancedQuestion': '¿Migrar a bóveda equilibrada?',
      'enterCurrentMasterPassword': 'Ingresa la contraseña maestra actual',
      'migrateToBalanced': 'Migrar a equilibrada',
      'vaultMigratedToBalanced':
          'Bóveda migrada correctamente al perfil equilibrado (Búho).',
      'demoPreviewAddItem':
          'Esta es una vista previa de demostración. Agrega un elemento para comenzar.',
      'failedToStoreAttachment':
          'No se pudo guardar el adjunto. Inténtalo de nuevo.',
      'themeSystem': 'Sistema',
      'themeLight': 'Claro',
      'themeDark': 'Oscuro',
      'cloudBackupUnavailable':
          'La copia de seguridad en la nube no está disponible en este momento.',
      'securityModel': 'Modelo de seguridad',
      'yourResponsibility': 'Tu responsabilidad',
      'localFirstStorage': 'Almacenamiento local primero',
      'sensitiveData': 'Datos sensibles',
      'changeTheme': 'Cambiar tema',
      'skip': 'Omitir',
      'debugInternalsUnavailable': 'Depuración interna no disponible',
      'unableToReadInternals': 'No se pueden leer los datos internos',
      'refreshInternals': 'Actualizar datos internos',
      'automatedBackups': 'Copias de seguridad automáticas',
      'backupTime': 'Hora de la copia de seguridad',
      'localBackupSubtitle': '2 instantáneas rotativas · Versión gratuita',
      'backUpNow': 'Hacer copia ahora',
      'cloudBackup': 'Copia en la nube',
      'browserBackupScope': 'Alcance de copia en el navegador',
      'backUpOverWifiOnly': 'Hacer copia solo por Wi-Fi',
      'avoidMobileDataUsage': 'Evitar uso de datos móviles',
      'lastBackup': 'Última copia de seguridad',
      'backedUpVersion': 'Versión respaldada',
      'restore': 'Restaurar',
      'storage': 'Almacenamiento',
      'vaultStorage': 'Almacenamiento de la bóveda',
      'data': 'Datos',
      'webStorage': 'Almacenamiento web',
      'importLabel': 'Importar',
      'exportLabel': 'Exportar',
      'exportDataToFile': 'Exportar datos a un archivo',
      'encryptedExportSize': 'Tamaño de exportación cifrada',
      'preferences': 'Preferencias',
      'theme': 'Tema',
      'chooseAppAppearance': 'Elegir apariencia de la aplicación',
      'categories': 'Categorías',
      'about': 'Acerca de',
      'aboutNija': 'Acerca de Nija',
      'versionLabel': 'Versión {version}',
      'debugInternals': 'Depuración interna',
      'showVaultInternalsTab': 'Mostrar pestaña interna de la bóveda',
      'privacyPolicy': 'Política de privacidad',
      'readOurPrivacyPolicy': 'Lee nuestra política de privacidad',
      'termsOfUse': 'Términos de uso',
      'readOurTermsAndConditions': 'Lee nuestros términos y condiciones',
      'removeFromFavorites': 'Quitar de favoritos',
      'addToFavorites': 'Agregar a favoritos',
      'collapse': 'Contraer',
      'clearTitle': 'Borrar título',
      'undo': 'Deshacer',
      'redo': 'Rehacer',
      'hidePhrase': 'Ocultar frase',
      'revealRecoveryPhrase': 'Mostrar frase de recuperación',
      'add': 'Agregar',
      'addTemplate': 'Agregar plantilla',
      'editTemplate': 'Editar plantilla',
      'deleteTemplate': 'Eliminar plantilla',
      'moveToTrashQuestion': '¿Mover a la papelera?',
      'subfolderName': 'Nombre de la subcarpeta',
      'folderName': 'Nombre de la carpeta',
      'subfolderNameHint': 'ej. T1, Recibos, Facturas',
      'folderNameHint': 'ej. Trabajo, Impuestos, Identidad',
      'create': 'Crear',
      'createSubfolderInside': 'Crear subcarpeta dentro de "{name}"',
      'selectThisFolder': 'Seleccionar esta carpeta',
      'createFolder': 'Crear carpeta',
      'acceptAllFromCurrent': 'Aceptar todo de la actual',
      'vaultMerge': 'Fusión de bóvedas',
      'ok': 'OK',
      'currentVault': 'Bóveda actual',
      'fileName': 'Nombre del archivo',
      'passwordForThisFile': 'Contraseña para este archivo',
      'documentLabel': 'Documento',
      'settings': 'Configuración',
    },
  };
}
