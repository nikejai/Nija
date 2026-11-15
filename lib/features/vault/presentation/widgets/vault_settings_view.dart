part of '../vault_app_shell.dart';

extension _VaultSettingsTab on _VaultAppShellState {
  Widget _buildSettingsTab(BuildContext context) {
    if (kIsWeb && !widget.isExploreDemoSession) {
      unawaited(_refreshPwaInstallStatus());
    }
    final pwaInstallStatus = _pwaInstallStatus;
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
    final vaultLimitBytes = _effectiveMaxVaultBytes;
    final vaultUsageLabel =
        '${VaultLimits.formatBytes(effectiveVaultSizeBytes)} of ${VaultLimits.formatBytes(vaultLimitBytes)}';
    final backupSubtitle = widget.isExploreDemoSession &&
            !_cloudBackupFeatureAvailable
        ? 'Disabled in demo session'
        : _cloudBackupFeatureAvailable
        ? (_cloudBackupEnabled
              ? 'Automatic cloud backup is enabled'
              : 'Backup your data locally')
        : _cloudRestoreFeatureAvailable
        ? 'Restore is available. Backup requires paid version'
        : AppFeatures.paidUnavailableLabel;
    final currentVaultVersionLabel = _vaultVersionSummary(
      revision: widget.activeVaultRevision,
      versionId: widget.activeVaultVersionId,
    );
    final currentVaultUpdatedLabel = _formatVaultIsoTimestamp(
      widget.activeVaultUpdatedAt,
    );
    final backedUpVaultVersionLabel = _vaultVersionSummary(
      revision: _cloudBackupRevision,
      versionId: _cloudBackupVersionId,
    );
    final backedUpVaultVersionDisplay =
        _cloudBackupSummaryRefreshInProgress &&
            _cloudBackupRevision <= 0 &&
            _cloudBackupVersionId.trim().isEmpty
        ? 'Checking'
        : backedUpVaultVersionLabel;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = _isWideLayout(context);
        return DecoratedBox(
          decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 900 : double.infinity,
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 24 : 16,
                  18,
                  isWide ? 24 : 16,
                  28,
                ),
                children: [
                  if (!isWide)
                    Text('Settings', style: vaultPageHeadingStyle(context)),
                  if (!isWide) const SizedBox(height: 18),
                  _SettingsSection(
                    title: 'Account',
                    children: [
                      _SettingsRow(
                        icon: Icons.dashboard_customize_outlined,
                        title: 'Nija User',
                        subtitle: _activeVaultName,
                        onTap: () => _showRenameVaultDialog(context),
                      ),
                      _SettingsRow(
                        key: const ValueKey('settings-current-vault-version'),
                        icon: Icons.commit_outlined,
                        title: 'Current version',
                        subtitle: currentVaultUpdatedLabel == 'Unknown'
                            ? 'Saved vault metadata'
                            : 'Updated $currentVaultUpdatedLabel',
                        detail: currentVaultVersionLabel,
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
                        icon: _iconForSetting(
                          AppStrings.settingsBiometricUnlock,
                        ),
                        title: AppStrings.settingsBiometricUnlock,
                        subtitle: widget.biometricAvailable
                            ? AppStrings.settingsBiometricAvailableSubtitle
                            : AppStrings.settingsBiometricUnavailableSubtitle,
                        onTap: widget.biometricAvailable
                            ? null
                            : () => widget.onBiometricChanged(true),
                        trailing: Switch(
                          value: widget.biometricEnabled,
                          onChanged: widget.biometricAvailable
                              ? widget.onBiometricChanged
                              : null,
                        ),
                      ),
                      _SettingsRow(
                        key: const ValueKey('settings-app-pin-row'),
                        icon: Icons.pin_outlined,
                        title: AppStrings.settingsAppPin,
                        subtitle: widget.pinEnabled
                            ? AppStrings.settingsAppPinEnabledSubtitle
                            : AppStrings.settingsAppPinDisabledSubtitle,
                        value: widget.pinEnabled
                            ? AppStrings.changePin
                            : AppStrings.setUpPin,
                        onTap: widget.onPinChanged == null
                            ? null
                            : () => widget.onPinChanged!(!widget.pinEnabled),
                      ),
                      _SettingsRow(
                        key: const ValueKey('settings-security-encryption-row'),
                        icon: Icons.shield_outlined,
                        title: 'Security & Encryption',
                        subtitle: 'View encryption details and key info',
                        onTap: () => _showSecurityEncryptionSheet(context),
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'Backup',
                    children: [
                      _SettingsRow(
                        key: const ValueKey(
                          'settings-automated-backup-master-switch',
                        ),
                        icon: Icons.schedule_outlined,
                        title: 'Automated backups',
                        subtitle: 'Daily automated backup at midnight',
                        trailing: Switch(
                          key: const ValueKey(
                            'settings-automated-backup-switch',
                          ),
                          value: _automatedBackupEnabled,
                          onChanged: _setAutomatedBackupEnabled,
                        ),
                      ),
                      _SettingsRow(
                        key: const ValueKey('settings-local-backup-row'),
                        icon: Icons.save_outlined,
                        title: 'Local backup',
                        subtitle: '2 rolling snapshots · Free version',
                        detail: _localSnapshotsSummary(),
                        value: _localSnapshots.isEmpty
                            ? '0/2'
                            : '${_localSnapshots.length}/2',
                        onTap: () => _showLocalSnapshotsDialog(context),
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
                        trailing: _cloudBackupExpansionTrailing(context),
                        onTap: _cloudBackupFeatureAvailable
                            ? () => _setCloudBackupEnabled(!_cloudBackupEnabled)
                            : _handleCloudBackupLockedTap,
                      ),
                      if (_cloudRestoreFeatureAvailable)
                        _SettingsRow(
                          key: const ValueKey('settings-cloud-account-row'),
                          icon: Icons.account_circle_outlined,
                          title:
                              _cloudBackupFeatureAvailable &&
                                  _cloudBackupEnabled
                              ? 'Backup account'
                              : 'Cloud account',
                          subtitle: _cloudBackupAccountLabel,
                          onTap: _handleChangeCloudBackupAccount,
                        ),
                      if (_cloudBackupFeatureAvailable &&
                          _cloudBackupEnabled) ...[
                        _SettingsRow(
                          key: const ValueKey(
                            'settings-cloud-backup-wifi-only-switch',
                          ),
                          icon: Icons.wifi_outlined,
                          title: 'Back up over Wi-Fi only',
                          subtitle: 'Avoid mobile data usage',
                          trailing: Switch(
                            key: const ValueKey(
                              'settings-cloud-backup-wifi-switch',
                            ),
                            value: _cloudBackupWifiOnly,
                            onChanged: _setCloudBackupWifiOnly,
                          ),
                        ),
                        _SettingsRow(
                          key: const ValueKey('settings-cloud-backup-last-at'),
                          icon: Icons.schedule_outlined,
                          title: 'Last backup',
                          subtitle: _formatCloudBackupLastAt(),
                        ),
                        _SettingsRow(
                          key: const ValueKey('settings-cloud-backup-version'),
                          icon: Icons.cloud_done_outlined,
                          title: 'Backed up version',
                          subtitle:
                              _cloudBackupSummaryRefreshInProgress &&
                                  _cloudBackupUpdatedAt.trim().isEmpty
                              ? 'Vault updated: Checking cloud backup...'
                              : _cloudBackupUpdatedAt.trim().isEmpty
                              ? 'Vault updated: Unknown'
                              : 'Vault updated: ${_formatVaultIsoTimestamp(_cloudBackupUpdatedAt)}',
                          detail: backedUpVaultVersionDisplay,
                        ),
                      ],
                      if (_cloudRestoreFeatureAvailable ||
                          (_cloudBackupFeatureAvailable && _cloudBackupEnabled))
                        _SettingsActionRow(
                          children: [
                            if (_cloudBackupFeatureAvailable &&
                                _cloudBackupEnabled)
                              OutlinedButton.icon(
                                key: const ValueKey(
                                  'settings-cloud-backup-now',
                                ),
                                onPressed: _handleBackupNow,
                                icon: const Icon(Icons.backup_outlined),
                                label: const Text('Backup now'),
                              ),
                            if (_cloudRestoreFeatureAvailable)
                              OutlinedButton.icon(
                                key: const ValueKey(
                                  'settings-cloud-restore-now',
                                ),
                                onPressed: () =>
                                    _showRestoreOptionsDialog(context),
                                icon: const Icon(Icons.restore_outlined),
                                label: const Text('Restore'),
                              ),
                          ],
                        ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'Storage',
                    children: [
                      _SettingsRow(
                        key: const ValueKey('settings-vault-storage-row'),
                        icon: Icons.storage_outlined,
                        title: 'Vault storage',
                        subtitle: 'Local device storage is unlimited',
                        detail:
                            'Optional cloud backup allocation: $vaultUsageLabel. Local-first vault storage is bounded only by your device capacity.',
                        value: vaultUsageLabel,
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'Data',
                    children: [
                      if (kIsWeb)
                        const _SettingsRow(
                          key: ValueKey('settings-web-storage-note'),
                          icon: Icons.info_outline,
                          title: 'Web storage',
                          subtitle:
                              'Exported vault files are not updated automatically',
                          detail:
                              'Nija keeps web vault data in private browser storage. Export a fresh vault file after important changes.',
                        ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                        title: 'Encrypted export size',
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
                            SnackBar(
                              content: Text(AppStrings.settingComingSoon),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: 'Preferences',
                    children: [
                      if (kIsWeb &&
                          !widget.isExploreDemoSession &&
                          pwaInstallStatus != null &&
                          pwaInstallStatus.showInstallOffer)
                        _SettingsRow(
                          key: const ValueKey('settings-install-app-row'),
                          icon: _pwaInstallSettingsIcon(pwaInstallStatus),
                          title: _pwaInstallSettingsTitle(pwaInstallStatus),
                          subtitle: _pwaInstallSettingsSubtitle(
                            pwaInstallStatus,
                          ),
                          onTap: () => _handlePwaInstallTap(context),
                        ),
                      _SettingsRow(
                        icon: Icons.palette_outlined,
                        title: 'Theme',
                        subtitle: 'Choose app appearance',
                        value: themeLabel,
                        onTap: () => _showThemePicker(context),
                      ),
                      _SettingsRow(
                        key: const ValueKey('settings-categories-row'),
                        icon: Icons.folder_outlined,
                        title: 'Categories',
                        subtitle:
                            '${_customTypeDefinitions.length} custom templates',
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
                        key: const ValueKey('settings-about-nija-row'),
                        icon: Icons.info_outline,
                        title: 'About Nija',
                        subtitle: 'Version 1.0.0',
                        onTap: () => _handleAboutNijaTap(context),
                      ),
                      if (_debugInternalsFeatureAvailable &&
                          _debugInternalsUnlocked)
                        _SettingsRow(
                          key: const ValueKey(
                            'settings-debug-internals-switch',
                          ),
                          icon: Icons.bug_report_outlined,
                          title: 'Debug internals',
                          subtitle: 'Show vault internals tab',
                          trailing: Switch(
                            value: _debugInternalsEnabled,
                            onChanged: _setDebugInternalsEnabled,
                          ),
                          onTap: () => _setDebugInternalsEnabled(
                            !_debugInternalsEnabled,
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
            ),
          ),
        );
      },
    );
  }
}
