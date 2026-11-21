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
        : _cloudBackupAccountLabel == 'Not connected' ||
            _cloudBackupLastAtEpochMs <= 0
        ? 'None'
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
                    Text(AppStrings.settings, style: vaultPageHeadingStyle(context)),
                  if (!isWide) const SizedBox(height: 18),
                  _SettingsSection(
                    title: AppStrings.settingsAccount,
                    children: [
                      _SettingsRow(
                        icon: Icons.dashboard_customize_outlined,
                        title: AppStrings.nijaUser,
                        subtitle: _activeVaultName,
                        onTap: () => _showRenameVaultDialog(context),
                      ),
                      _SettingsRow(
                        key: const ValueKey('settings-current-vault-version'),
                        icon: Icons.commit_outlined,
                        title: AppStrings.currentVersion,
                        subtitle: currentVaultUpdatedLabel == 'Unknown'
                            ? 'Saved vault metadata'
                            : 'Updated $currentVaultUpdatedLabel',
                        value: currentVaultVersionLabel == 'Unknown'
                            ? null
                            : currentVaultVersionLabel,
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: AppStrings.settingsSecurityTitle,
                    children: [
                      _SettingsRow(
                        icon: Icons.lock_outline,
                        title: AppStrings.settingsMasterPassword,
                        subtitle: AppStrings.changeMasterPasswordSubtitle,
                        onTap: () => _showRotateMasterPasswordDialog(context),
                      ),
                      _SettingsRow(
                        key: const ValueKey('settings-auto-lock-row'),
                        icon: Icons.key_outlined,
                        title: AppStrings.settingsAutoLock,
                        subtitle: AppStrings.lockNijaAutomatically,
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
                      if (_activeGuardianProfile.id != GuardianProfiles.owl.id &&
                          widget.onMigrateToBalancedProfile != null)
                        _SettingsRow(
                          key: const ValueKey('settings-migrate-to-balanced-row'),
                          icon: Icons.speed_outlined,
                          iconColor: theme.colorScheme.primary,
                          title: AppStrings.migrateToBalancedVault,
                          subtitle:
                              'Switch from ${_activeGuardianProfile.displayName} to Owl for faster unlock',
                          value: 'Recommended',
                          onTap: () => _showMigrateToBalancedDialog(context),
                        ),
                      _SettingsRow(
                        key: const ValueKey('settings-security-encryption-row'),
                        icon: Icons.shield_outlined,
                        title: AppStrings.securityAndEncryption,
                        subtitle: AppStrings.securityAndEncryptionSubtitle,
                        onTap: () => _showSecurityEncryptionSheet(context),
                      ),
                    ],
                  ),
                  if (!kIsWeb)
                    _SettingsSection(
                      title: AppStrings.localBackup,
                      children: [
                        _SettingsRow(
                          key: const ValueKey(
                            'settings-automated-backup-master-switch',
                          ),
                          icon: Icons.schedule_outlined,
                          title: AppStrings.automatedBackups,
                          subtitle: _automatedBackupFeatureAvailable
                              ? 'Daily automated backup at ${_formatAutomatedBackupTimeLabel()}'
                              : AppFeatures.paidUnavailableLabel,
                          onTap: _automatedBackupFeatureAvailable
                              ? null
                              : () {
                                  if (widget.canPurchaseExpandedVaultStorage) {
                                    _handlePurchasePro();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          AppFeatures.paidUnavailableLabel,
                                        ),
                                      ),
                                    );
                                  }
                                },
                          trailing: Switch(
                            key: const ValueKey(
                              'settings-automated-backup-switch',
                            ),
                            value:
                                _automatedBackupFeatureAvailable &&
                                _automatedBackupEnabled,
                            onChanged: _automatedBackupFeatureAvailable
                                ? _setAutomatedBackupEnabled
                                : null,
                          ),
                        ),
                        if (_automatedBackupFeatureAvailable &&
                            _automatedBackupEnabled)
                          _SettingsRow(
                            key: const ValueKey(
                              'settings-automated-backup-time-row',
                            ),
                            icon: Icons.access_time_outlined,
                            title: AppStrings.backupTime,
                            subtitle:
                                'Runs daily at ${_formatAutomatedBackupTimeLabel()}',
                            value: _formatAutomatedBackupTimeLabel(),
                            onTap: () async {
                              final selected = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: _automatedBackupHour,
                                  minute: _automatedBackupMinute,
                                ),
                              );
                              if (selected != null) {
                                await _setAutomatedBackupTime(
                                  selected.hour,
                                  selected.minute,
                                );
                              }
                            },
                          ),
                        _SettingsRow(
                          key: const ValueKey('settings-local-backup-row'),
                          icon: Icons.save_outlined,
                          title: AppStrings.localBackupRow,
                          subtitle: AppStrings.localBackupSubtitle,
                          detail: _localSnapshotsSummary(),
                          value: _localSnapshots.isEmpty
                              ? '0/2'
                              : '${_localSnapshots.length}/2',
                          onTap: () => _showLocalSnapshotsDialog(context),
                        ),
                        _SettingsActionRow(
                          children: [
                            OutlinedButton.icon(
                              key: const ValueKey('settings-local-backup-now'),
                              onPressed: _handleLocalBackupNow,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(AppStrings.backUpNow),
                            ),
                          ],
                        ),
                      ],
                    ),
                  _SettingsSection(
                    title: AppStrings.cloudBackup,
                    children: [
                      if (kIsWeb)
                        _SettingsRow(
                          key: const ValueKey('settings-web-cloud-backup-note'),
                          icon: Icons.info_outline,
                          title: AppStrings.browserBackupScope,
                          subtitle:
                              'Local rolling snapshots are mobile/desktop-only',
                          detail:
                              'Use Cloud Backup or Export to keep durable backups of your web vault.',
                        ),
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
                          title: AppStrings.backUpOverWifiOnly,
                          subtitle: AppStrings.avoidMobileDataUsage,
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
                          title: AppStrings.lastBackup,
                          subtitle: _formatCloudBackupLastAt(),
                        ),
                        _SettingsRow(
                          key: const ValueKey('settings-cloud-backup-version'),
                          icon: Icons.cloud_done_outlined,
                          title: AppStrings.backedUpVersion,
                          subtitle:
                              _cloudBackupSummaryRefreshInProgress &&
                                  _cloudBackupUpdatedAt.trim().isEmpty
                              ? 'Vault updated: Checking cloud backup...'
                              : _cloudBackupAccountLabel == 'Not connected' ||
                                  _cloudBackupLastAtEpochMs <= 0 ||
                                  _cloudBackupUpdatedAt.trim().isEmpty
                              ? 'Never backed up'
                              : 'Vault updated: ${_formatVaultIsoTimestamp(_cloudBackupUpdatedAt)}',
                          value: _cloudBackupSummaryRefreshInProgress &&
                                  _cloudBackupRevision <= 0 &&
                                  _cloudBackupVersionId.trim().isEmpty
                              ? 'Checking'
                              : (_cloudBackupAccountLabel == 'Not connected' ||
                                      _cloudBackupLastAtEpochMs <= 0 ||
                                      backedUpVaultVersionDisplay == 'None' ||
                                      backedUpVaultVersionDisplay == 'Unknown')
                              ? null
                              : backedUpVaultVersionDisplay,
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
                                label: Text(AppStrings.backUpNow),
                              ),
                            if (_cloudRestoreFeatureAvailable)
                              OutlinedButton.icon(
                                key: const ValueKey(
                                  'settings-cloud-restore-now',
                                ),
                                onPressed: () =>
                                    _showRestoreOptionsDialog(context),
                                icon: const Icon(Icons.restore_outlined),
                                label: Text(AppStrings.restore),
                              ),
                          ],
                        ),
                    ],
                  ),
                  _SettingsSection(
                    title: AppStrings.storage,
                    children: [
                      _SettingsRow(
                        key: const ValueKey('settings-vault-storage-row'),
                        icon: Icons.storage_outlined,
                        title: AppStrings.vaultStorage,
                        subtitle: vaultUsageLabel,
                        detail: widget.expandedVaultStorageEntitled
                            ? (widget.entitlementSource == 'google_play'
                                  ? 'Pro unlocked (Google Play)'
                                  : 'Pro unlocked')
                            : widget.entitlementRefreshInProgress
                            ? 'Checking Google Play purchase...'
                            : 'Free plan',
                      ),
                      if (!widget.expandedVaultStorageEntitled &&
                          !kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.android) ...[
                        _SettingsRow(
                          key: const ValueKey('settings-upgrade-pro-row'),
                          icon: Icons.workspace_premium_outlined,
                          title: 'Upgrade to Pro',
                          subtitle:
                              'Unlock ${VaultLimits.formatBytes(VaultLimits.paidVaultBytes)} storage & automated backups',
                          trailing: widget.purchaseInProgress
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          onTap: widget.purchaseInProgress
                              ? null
                              : _handlePurchasePro,
                        ),
                        _SettingsRow(
                          key: const ValueKey('settings-restore-purchase-row'),
                          icon: Icons.restore_outlined,
                          title: 'Restore purchase',
                          subtitle: 'Check Google Play for an existing Pro license',
                          trailing: widget.restoreInProgress
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          onTap: widget.restoreInProgress
                              ? null
                              : _handleRestorePurchases,
                        ),
                      ],
                    ],
                  ),
                  _SettingsSection(
                    title: AppStrings.data,
                    children: [
                      if (kIsWeb)
                        _SettingsRow(
                          key: const ValueKey('settings-web-storage-note'),
                          icon: Icons.info_outline,
                          title: AppStrings.webStorage,
                          subtitle:
                              'Exported vault files are not updated automatically',
                          detail:
                              'Nija keeps web vault data in private browser storage. Export a fresh vault file after important changes.',
                        ),
                      _SettingsRow(
                        key: const ValueKey('settings-import-encrypted-secret'),
                        icon: Icons.file_download_outlined,
                        title: AppStrings.importLabel,
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
                        title: AppStrings.exportLabel,
                        subtitle: AppStrings.exportDataToFile,
                        onTap: widget.onExportVault,
                      ),
                      _SettingsRow(
                        icon: Icons.sd_storage_outlined,
                        title: AppStrings.encryptedExportSize,
                        subtitle: vaultUsageLabel,
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: AppStrings.preferences,
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
                        title: AppStrings.theme,
                        subtitle: AppStrings.chooseAppAppearance,
                        value: themeLabel,
                        onTap: () => _showThemePicker(context),
                      ),
                      _SettingsRow(
                        key: const ValueKey('settings-categories-row'),
                        icon: Icons.folder_outlined,
                        title: AppStrings.categories,
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
                    title: AppStrings.about,
                    children: [
                      _SettingsRow(
                        key: const ValueKey('settings-about-nija-row'),
                        icon: Icons.info_outline,
                        title: AppStrings.aboutNija,
                        subtitle: AppStrings.versionLabel(AppFeatures.appVersion),
                        onTap: () => _handleAboutNijaTap(context),
                      ),
                      if (_debugInternalsFeatureAvailable &&
                          _debugInternalsUnlocked)
                        _SettingsRow(
                          key: const ValueKey(
                            'settings-debug-internals-switch',
                          ),
                          icon: Icons.bug_report_outlined,
                          title: AppStrings.debugInternals,
                          subtitle: AppStrings.showVaultInternalsTab,
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
                        title: AppStrings.privacyPolicy,
                        subtitle: AppStrings.readOurPrivacyPolicy,
                        onTap: () => _showInfoSheet(
                          context,
                          title: AppStrings.privacyPolicy,
                          icon: Icons.verified_user_outlined,
                          sections: _privacyPolicySections(),
                        ),
                      ),
                      _SettingsRow(
                        icon: Icons.description_outlined,
                        title: AppStrings.termsOfUse,
                        subtitle: AppStrings.readOurTermsAndConditions,
                        onTap: () => _showInfoSheet(
                          context,
                          title: AppStrings.termsOfUse,
                          icon: Icons.description_outlined,
                          sections: _termsOfUseSections(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => unawaited(_lockWithFlush()),
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
