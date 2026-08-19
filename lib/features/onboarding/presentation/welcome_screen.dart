import 'package:flutter/material.dart';

import '../../../app/widgets/nija_brand_lockup.dart';
import '../../../app/theme/entry_typography.dart';
import '../../../core/localization/app_strings.dart';
import '../../../domain/models/vault_reference.dart';
import '../../vault/presentation/widgets/pwa_install_dialog.dart';
import 'onboarding_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onCreateVault,
    required this.onSelectKnownVault,
    required this.onOpenVaultFile,
    required this.onImportVault,
    required this.onImportVaultFromCloud,
    required this.onExploreDemo,
    this.recentVaults = const <VaultReference>[],
    this.onRecentVaultSelected,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
  });

  final VoidCallback onCreateVault;
  final VoidCallback onSelectKnownVault;
  final VoidCallback onOpenVaultFile;
  final VoidCallback onImportVault;
  final VoidCallback onImportVaultFromCloud;
  final VoidCallback onExploreDemo;
  final List<VaultReference> recentVaults;
  final ValueChanged<VaultReference>? onRecentVaultSelected;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      fullWidth: true,
      child: _VaultEntrySurface(
        onCreateVault: onCreateVault,
        onSelectKnownVault: onSelectKnownVault,
        onOpenVaultFile: onOpenVaultFile,
        onImportVault: onImportVault,
        onImportVaultFromCloud: onImportVaultFromCloud,
        onExploreDemo: onExploreDemo,
        recentVaults: recentVaults,
        onRecentVaultSelected: onRecentVaultSelected,
        themeMode: themeMode,
        onThemeModeChanged: onThemeModeChanged,
      ),
    );
  }
}

class _VaultEntrySurface extends StatelessWidget {
  const _VaultEntrySurface({
    required this.onCreateVault,
    required this.onSelectKnownVault,
    required this.onOpenVaultFile,
    required this.onImportVault,
    required this.onImportVaultFromCloud,
    required this.onExploreDemo,
    this.recentVaults = const <VaultReference>[],
    this.onRecentVaultSelected,
    required this.themeMode,
    this.onThemeModeChanged,
  });

  final VoidCallback onCreateVault;
  final VoidCallback onSelectKnownVault;
  final VoidCallback onOpenVaultFile;
  final VoidCallback onImportVault;
  final VoidCallback onImportVaultFromCloud;
  final VoidCallback onExploreDemo;
  final List<VaultReference> recentVaults;
  final ValueChanged<VaultReference>? onRecentVaultSelected;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  static const _splitBreakpoint = 960.0;
  static const _contentMaxWidth = 1080.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Column(
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
              const Expanded(child: NijaBrandLockup()),
              const PwaInstallOfferButton(),
              IconButton(
                key: const ValueKey('entry-theme-toggle'),
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
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSplit = constraints.maxWidth >= _splitBreakpoint;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isSplit ? 32 : 16,
                  isSplit ? 28 : 16,
                  isSplit ? 32 : 16,
                  40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: isSplit ? constraints.maxHeight - 68 : 0,
                      maxWidth: _contentMaxWidth,
                    ),
                    child: isSplit
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _EntryProductStory(
                                  key: const ValueKey(
                                    'vault-entry-product-story',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                              SizedBox(
                                width: 460,
                                child: _EntryActionsPanel(
                                  onCreateVault: onCreateVault,
                                  onSelectKnownVault: onSelectKnownVault,
                                  onOpenVaultFile: onOpenVaultFile,
                                  onImportVault: onImportVault,
                                  onImportVaultFromCloud:
                                      onImportVaultFromCloud,
                                  onExploreDemo: onExploreDemo,
                                  recentVaults: recentVaults,
                                  onRecentVaultSelected:
                                      onRecentVaultSelected,
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: _EntryActionsPanel(
                              onCreateVault: onCreateVault,
                              onSelectKnownVault: onSelectKnownVault,
                              onOpenVaultFile: onOpenVaultFile,
                              onImportVault: onImportVault,
                              onImportVaultFromCloud:
                                  onImportVaultFromCloud,
                              onExploreDemo: onExploreDemo,
                              recentVaults: recentVaults,
                              onRecentVaultSelected:
                                  onRecentVaultSelected,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EntryProductStory extends StatelessWidget {
  const _EntryProductStory({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.welcomeLabel.toUpperCase(),
          style: EntryTypography.productEyebrow(accent),
        ),
        const SizedBox(height: 18),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.07),
                blurRadius: isDark ? 30 : 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.shield_outlined, size: 34, color: accent),
        ),
        const SizedBox(height: 18),
        Text(
          AppStrings.welcomeTitle,
          style: EntryTypography.productTitle(colorScheme.onSurface),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            AppStrings.welcomeDescription,
            style: EntryTypography.productDescription(
              colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ProductTag(label: AppStrings.welcomeTagLocalFirst),
            _ProductTag(label: AppStrings.welcomeTagEncrypted),
            _ProductTag(label: AppStrings.welcomeTagPortable),
            _ProductTag(label: AppStrings.welcomeTagNoAccount),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 520
                ? (constraints.maxWidth - 24) / 4
                : (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ProductTypeCard(
                  width: cardWidth.clamp(120, 180),
                  code: 'LG',
                  title: AppStrings.welcomeTypePasswords,
                  subtitle: AppStrings.welcomeTypePasswordsHint,
                ),
                _ProductTypeCard(
                  width: cardWidth.clamp(120, 180),
                  code: 'ID',
                  title: AppStrings.welcomeTypeIdentity,
                  subtitle: AppStrings.welcomeTypeIdentityHint,
                ),
                _ProductTypeCard(
                  width: cardWidth.clamp(120, 180),
                  code: 'DC',
                  title: AppStrings.welcomeTypeDocuments,
                  subtitle: AppStrings.welcomeTypeDocumentsHint,
                ),
                _ProductTypeCard(
                  width: cardWidth.clamp(120, 180),
                  code: 'NT',
                  title: AppStrings.welcomeTypeNotes,
                  subtitle: AppStrings.welcomeTypeNotesHint,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Divider(color: colorScheme.outlineVariant),
        const SizedBox(height: 18),
        Text(
          AppStrings.welcomeVaultFileTitle,
          style: EntryTypography.productSectionTitle(colorScheme.onSurface),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ProductFlowStep(
              title: AppStrings.welcomeFlowDevice,
              subtitle: AppStrings.welcomeFlowDeviceHint,
            ),
            Icon(Icons.arrow_forward, size: 16, color: colorScheme.outline),
            _ProductFlowStep(
              title: AppStrings.welcomeFlowVault,
              subtitle: AppStrings.welcomeFlowVaultHint,
            ),
            Icon(Icons.arrow_forward, size: 16, color: colorScheme.outline),
            _ProductFlowStep(
              title: AppStrings.welcomeFlowBackup,
              subtitle: AppStrings.welcomeFlowBackupHint,
            ),
          ],
        ),
      ],
    );
  }
}

class _ProductTag extends StatelessWidget {
  const _ProductTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label.toUpperCase(),
            style: EntryTypography.productTag(colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ProductTypeCard extends StatelessWidget {
  const _ProductTypeCard({
    required this.width,
    required this.code,
    required this.title,
    required this.subtitle,
  });

  final double width;
  final String code;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              code,
              style: EntryTypography.productTypeCode(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: EntryTypography.productTypeTitle(colorScheme.onSurface),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: EntryTypography.productTypeHint(
              colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFlowStep extends StatelessWidget {
  const _ProductFlowStep({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: EntryTypography.productFlowTitle(colorScheme.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: EntryTypography.productFlowHint(
              colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryActionsPanel extends StatelessWidget {
  const _EntryActionsPanel({
    required this.onCreateVault,
    required this.onSelectKnownVault,
    required this.onOpenVaultFile,
    required this.onImportVault,
    required this.onImportVaultFromCloud,
    required this.onExploreDemo,
    this.recentVaults = const <VaultReference>[],
    this.onRecentVaultSelected,
  });

  static const _recentVaultLimit = 3;

  final VoidCallback onCreateVault;
  final VoidCallback onSelectKnownVault;
  final VoidCallback onOpenVaultFile;
  final VoidCallback onImportVault;
  final VoidCallback onImportVaultFromCloud;
  final VoidCallback onExploreDemo;
  final List<VaultReference> recentVaults;
  final ValueChanged<VaultReference>? onRecentVaultSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      key: const ValueKey('vault-entry-shell'),
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const NijaBrandLockup(
            layout: NijaBrandLayout.vertical,
            markSize: 56,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.entryTitle,
            textAlign: TextAlign.center,
            style: EntryTypography.heroTitle(colorScheme.onSurface),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              AppStrings.entryDescription,
              textAlign: TextAlign.center,
              style: EntryTypography.heroDescription(
                colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 26),
          _EntryActionGroup(
            children: [
              _EntryAction(
                key: const ValueKey('entry-select-vault'),
                code: '01',
                title: AppStrings.selectKnownVault,
                subtitle: AppStrings.selectKnownVaultHint,
                icon: Icons.chevron_right,
                onTap: onSelectKnownVault,
                showDivider: true,
              ),
              _EntryAction(
                key: const ValueKey('entry-open-vault-file'),
                code: '02',
                title: AppStrings.openVaultFile,
                subtitle: AppStrings.openVaultFileHint,
                icon: Icons.open_in_new_outlined,
                onTap: onOpenVaultFile,
                showDivider: true,
              ),
              _EntryAction(
                key: const ValueKey('entry-create-vault'),
                code: '03',
                title: AppStrings.createVault,
                subtitle: AppStrings.createVaultHint,
                icon: Icons.add,
                onTap: onCreateVault,
                showDivider: true,
              ),
              _EntryAction(
                key: const ValueKey('entry-import-data'),
                code: '04',
                title: AppStrings.importData,
                subtitle: AppStrings.importDataHint,
                icon: Icons.south_east,
                onTap: onImportVault,
                showDivider: true,
              ),
              _EntryAction(
                key: const ValueKey('entry-explore-demo'),
                code: '05',
                title: AppStrings.exploreDemo,
                subtitle: AppStrings.exploreDemoHint,
                icon: Icons.visibility_outlined,
                onTap: onExploreDemo,
              ),
            ],
          ),
          if (recentVaults.isNotEmpty && onRecentVaultSelected != null) ...[
            const SizedBox(height: 16),
            _EntryRecentVaultsSection(
              vaults: recentVaults.take(_recentVaultLimit).toList(),
              onVaultSelected: onRecentVaultSelected!,
              onViewAll: recentVaults.length > _recentVaultLimit
                  ? onSelectKnownVault
                  : null,
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppStrings.restoreFromStorage.toUpperCase(),
              style: EntryTypography.sectionLabel(colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('entry-restore-cloud'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: BorderSide(color: colorScheme.outlineVariant),
                textStyle: EntryTypography.restoreButton(colorScheme.onSurface),
              ),
              onPressed: onImportVaultFromCloud,
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(AppStrings.restoreFromStorage),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRecentVaultsSection extends StatelessWidget {
  const _EntryRecentVaultsSection({
    required this.vaults,
    required this.onVaultSelected,
    this.onViewAll,
  });

  final List<VaultReference> vaults;
  final ValueChanged<VaultReference> onVaultSelected;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('entry-recent-vaults-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.webRecentVaults.toUpperCase(),
          style: EntryTypography.sectionLabel(colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.webRecentVaultsHint,
          style: EntryTypography.actionSubtitle(colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        _EntryActionGroup(
          children: [
            for (var index = 0; index < vaults.length; index++)
              _EntryRecentVaultRow(
                entry: vaults[index],
                onTap: () => onVaultSelected(vaults[index]),
                showDivider: index < vaults.length - 1,
              ),
          ],
        ),
        if (onViewAll != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('entry-recent-vaults-view-all'),
              onPressed: onViewAll,
              child: Text(AppStrings.selectKnownVault),
            ),
          ),
        ],
      ],
    );
  }
}

class _EntryRecentVaultRow extends StatelessWidget {
  const _EntryRecentVaultRow({
    required this.entry,
    required this.onTap,
    this.showDivider = false,
  });

  final VaultReference entry;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final source = entry.sourceDescription.trim().isEmpty
        ? AppStrings.localVaultReference
        : entry.sourceDescription.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('entry-recent-vault-${entry.id}'),
        onTap: onTap,
        hoverColor: colorScheme.surfaceContainerHighest,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          decoration: showDivider
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  ),
                )
              : null,
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
                  Icons.shield_outlined,
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
                      style: EntryTypography.actionTitle(
                        colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EntryTypography.actionSubtitle(
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _recentVaultActivityLabel(entry.lastOpenedAtEpochMs),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EntryTypography.actionSubtitle(
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

String _recentVaultActivityLabel(int lastOpenedAtEpochMs) {
  if (lastOpenedAtEpochMs <= 0) {
    return AppStrings.neverOpened;
  }
  final opened = DateTime.fromMillisecondsSinceEpoch(
    lastOpenedAtEpochMs,
  ).toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final openedDay = DateTime(opened.year, opened.month, opened.day);
  final timeLabel =
      '${opened.hour.toString().padLeft(2, '0')}:${opened.minute.toString().padLeft(2, '0')}';
  if (openedDay == today) {
    return '${AppStrings.lastOpened} · Today $timeLabel';
  }
  final yesterday = today.subtract(const Duration(days: 1));
  if (openedDay == yesterday) {
    return '${AppStrings.lastOpened} · Yesterday $timeLabel';
  }
  final month = opened.month.toString().padLeft(2, '0');
  final day = opened.day.toString().padLeft(2, '0');
  return '${AppStrings.lastOpened} · ${opened.year}-$month-$day';
}

class _EntryActionGroup extends StatelessWidget {
  const _EntryActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _EntryAction extends StatelessWidget {
  const _EntryAction({
    super.key,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.showDivider = false,
  });

  final String code;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: colorScheme.surfaceContainerHighest,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          decoration: showDivider
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  ),
                )
              : null,
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  code,
                  style: EntryTypography.actionCode(colorScheme.primary),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: EntryTypography.actionTitle(
                        colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: EntryTypography.actionSubtitle(
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
