import 'dart:async';
import 'package:flutter/material.dart';

import '../../../app/theme/entry_typography.dart';
import '../../../core/localization/app_strings.dart';
import '../../../domain/models/vault_reference.dart';
import 'onboarding_scaffold.dart';

enum VaultPickerAction { importFromDevice }

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
                                  ).pop(VaultPickerAction.importFromDevice);
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
                      _displayTitle(entry),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EntryTypography.vaultCardTitle(
                        colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (_truncatedId(entry).isNotEmpty) ...[
                          Text(
                            _truncatedId(entry),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            ' · ',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            entry.sourceDescription.trim().isEmpty
                                ? AppStrings.localVaultReference
                                : entry.sourceDescription.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EntryTypography.vaultCardMeta(
                              colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
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

  static String _displayTitle(VaultReference entry) {
    final raw = entry.label.trim();
    if (raw.isEmpty ||
        raw == 'vault.nija' ||
        raw == 'nija_vault.nija' ||
        raw == 'web_vault.nija' ||
        _isUuid(raw)) {
      return 'Personal Vault';
    }
    return raw;
  }

  static String _truncatedId(VaultReference entry) {
    final rawId = (_isUuid(entry.id)
            ? entry.id
            : (_isUuid(entry.label) ? entry.label : ''))
        .trim();
    final clean = rawId.endsWith('.nija')
        ? rawId.substring(0, rawId.length - 5)
        : rawId;
    if (clean.length > 8 && _isUuid(clean)) {
      return '${clean.substring(0, 4)}...${clean.substring(clean.length - 4)}';
    }
    return '';
  }

  static bool _isUuid(String value) {
    final clean = value.endsWith('.nija')
        ? value.substring(0, value.length - 5)
        : value;
    final parts = clean.split('-');
    return parts.length == 5 && clean.length == 36;
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
