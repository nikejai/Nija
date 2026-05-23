class AppStrings {
  AppStrings._();

  static String _languageCode = 'en';

  static void setLanguageCode(String? code) {
    _languageCode = (code == 'es') ? 'es' : 'en';
  }

  static String _t(String key) =>
      _localized[_languageCode]?[key] ?? _localized['en']![key]!;

  static String get appName => _t('appName');
  static String get tagline => _t('tagline');

  static String get welcomeLabel => _t('welcomeLabel');
  static String get welcomeTitle => _t('welcomeTitle');
  static String get welcomeDescription => _t('welcomeDescription');

  static String get createVault => _t('createVault');
  static String get openExistingVault => _t('openExistingVault');
  static String get noExistingVaultFound => _t('noExistingVaultFound');
  static String get wrongVaultPassword => _t('wrongVaultPassword');
  static String get selectVaultToOpen => _t('selectVaultToOpen');
  static String get noSavedVaultLocations => _t('noSavedVaultLocations');
  static String get importVaultToContinue => _t('importVaultToContinue');
  static String get importVaultFromDevice => _t('importVaultFromDevice');
  static String get vaultImportedSuccess => _t('vaultImportedSuccess');
  static String get vaultImportFailed => _t('vaultImportFailed');
  static String get vaultExportedSuccess => _t('vaultExportedSuccess');
  static String get vaultExportFailed => _t('vaultExportFailed');
  static String get vaultExportCancelled => _t('vaultExportCancelled');

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
  static String get selectDifferentVault => _t('selectDifferentVault');
  static String get useBiometricUnlock => _t('useBiometricUnlock');
  static String get biometricComingSoon => _t('biometricComingSoon');

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
  static String get settingsVaultBackup => _t('settingsVaultBackup');
  static String get settingsBiometricUnlock => _t('settingsBiometricUnlock');
  static String get settingsRecoveryPhrase => _t('settingsRecoveryPhrase');
  static String get settingsAutoLock => _t('settingsAutoLock');
  static String get settingsExportVault => _t('settingsExportVault');
  static String get settingsDangerZone => _t('settingsDangerZone');
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

  static const Map<String, Map<String, String>> _localized = {
    'en': {
      'appName': 'Nija',
      'tagline': 'Your private digital vault.',
      'welcomeLabel': 'Private vault',
      'welcomeTitle': 'Your digital life, locked in one file.',
      'welcomeDescription':
          'A portable encrypted vault for passwords, notes, cards, and identity details. You choose where it lives.',
      'createVault': 'Create vault',
      'openExistingVault': 'Open existing vault',
      'noExistingVaultFound': 'No existing vault found. Create a vault first.',
      'wrongVaultPassword': 'Wrong vault password.',
      'selectVaultToOpen': 'Select vault to open',
      'noSavedVaultLocations': 'No saved vault locations yet.',
      'importVaultToContinue':
          'Import a vault file from your device to continue.',
      'importVaultFromDevice': 'Import vault from device',
      'vaultImportedSuccess': 'Vault imported successfully.',
      'vaultImportFailed': 'Failed to import vault file.',
      'vaultExportedSuccess': 'Vault exported successfully.',
      'vaultExportFailed': 'Failed to export vault.',
      'vaultExportCancelled': 'Vault export cancelled.',
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
      'selectDifferentVault': 'Select different vault',
      'useBiometricUnlock': 'Use biometrics',
      'biometricComingSoon': 'Biometric unlock integration coming soon.',
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
      'tabNotes': 'Favorites',
      'tabTypes': 'All items',
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
      'settingsVaultBackup': 'Vault Backup',
      'settingsBiometricUnlock': 'Biometric Unlock',
      'settingsRecoveryPhrase': 'Recovery Phrase',
      'settingsAutoLock': 'Auto Lock',
      'settingsExportVault': 'Export Vault',
      'settingsDangerZone': 'Danger Zone',
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
    },
    'es': {
      'appName': 'Nija',
      'tagline': 'Tu bóveda digital privada.',
      'welcomeLabel': 'Bóveda privada',
      'welcomeTitle': 'Tu vida digital, protegida en un archivo.',
      'welcomeDescription':
          'Una bóveda cifrada y portátil para contraseñas, notas, tarjetas e identidad. Tú eliges dónde guardarla.',
      'createVault': 'Crear bóveda',
      'openExistingVault': 'Abrir bóveda existente',
      'noExistingVaultFound':
          'No se encontró una bóveda existente. Crea una bóveda primero.',
      'wrongVaultPassword': 'Contraseña de bóveda incorrecta.',
      'selectVaultToOpen': 'Selecciona una bóveda para abrir',
      'noSavedVaultLocations': 'Aún no hay ubicaciones de bóveda guardadas.',
      'importVaultToContinue':
          'Importa un archivo de bóveda desde tu dispositivo para continuar.',
      'importVaultFromDevice': 'Importar bóveda del dispositivo',
      'vaultImportedSuccess': 'Bóveda importada correctamente.',
      'vaultImportFailed': 'No se pudo importar el archivo de bóveda.',
      'vaultExportedSuccess': 'Bóveda exportada correctamente.',
      'vaultExportFailed': 'No se pudo exportar la bóveda.',
      'vaultExportCancelled': 'Exportación de bóveda cancelada.',
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
      'settingsVaultBackup': 'Copia de seguridad de la bóveda',
      'settingsBiometricUnlock': 'Desbloqueo biométrico',
      'settingsRecoveryPhrase': 'Frase de recuperación',
      'settingsAutoLock': 'Bloqueo automático',
      'settingsExportVault': 'Exportar bóveda',
      'settingsDangerZone': 'Zona de peligro',
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
    },
  };
}
