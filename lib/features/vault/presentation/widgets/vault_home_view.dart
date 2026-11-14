part of '../vault_app_shell.dart';

class _VaultHomeView extends StatelessWidget {
  const _VaultHomeView({
    required this.isWide,
    required this.dashboardData,
    required this.activeVaultName,
    required this.greeting,
    required this.onAddItem,
    required this.onLockNow,
    required this.onApplySearch,
    required this.onOpenFilters,
    required this.adapters,
    required this.keyForRow,
    required this.iconForType,
    required this.colorForType,
    required this.onTypeTap,
    required this.onViewAll,
    required this.onImportData,
    required this.onSwitchVault,
    required this.onShowDemoPreview,
    required this.onHideDemoPreview,
    required this.onOpenRow,
    required this.onRowActions,
  });

  final bool isWide;
  final _DashboardData dashboardData;
  final String activeVaultName;
  final String greeting;
  final VoidCallback onAddItem;
  final VoidCallback onLockNow;
  final ValueChanged<String> onApplySearch;
  final VoidCallback onOpenFilters;
  final List<VaultListEntryAdapter> adapters;
  final String Function(Map<String, dynamic> row) keyForRow;
  final IconData Function(String type) iconForType;
  final Color Function(String type) colorForType;
  final ValueChanged<String> onTypeTap;
  final VoidCallback onViewAll;
  final VoidCallback onImportData;
  final VoidCallback onSwitchVault;
  final VoidCallback onShowDemoPreview;
  final VoidCallback onHideDemoPreview;
  final ValueChanged<Map<String, dynamic>> onOpenRow;
  final ValueChanged<Map<String, dynamic>> onRowActions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recentItems = dashboardData.recentItems;
    final dashboardTypes = dashboardData.dashboardTypes;

    return SafeArea(
      top: !isWide,
      bottom: !isWide,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isWide ? 24 : 16,
          isWide ? 22 : 10,
          isWide ? 24 : 16,
          isWide ? 22 : 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isWide) ...[
                        Text(
                          'Dashboard',
                          style: DashboardTypography.microLabel(
                            colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 5),
                      ],
                      Text(
                        isWide ? greeting : 'Nija',
                        style: isWide
                            ? DashboardTypography.greetingTitle(
                                colorScheme.onSurface,
                              )
                            : vaultPageHeadingStyle(context),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isWide
                            ? "Here's what's happening with your vault."
                            : activeVaultName,
                        maxLines: isWide ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: isWide
                            ? DashboardTypography.greetingSubtitle(
                                colorScheme.onSurfaceVariant,
                              )
                            : TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                      ),
                    ],
                  ),
                ),
                if (isWide)
                  FilledButton.icon(
                    key: const ValueKey('dashboard-add-item'),
                    onPressed: onAddItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )
                else ...[
                  IconButton(
                    key: const ValueKey('dashboard-add-item'),
                    onPressed: onAddItem,
                    icon: Icon(Icons.add, color: colorScheme.onSurfaceVariant),
                    tooltip: 'Create',
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: onLockNow,
                    icon: Icon(
                      Icons.lock_outline,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Lock vault',
                  ),
                ],
              ],
            ),
            if (!isWide)
              Text(
                'All your important information,\nin one secure place.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 720 : double.infinity,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search your data...',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: onApplySearch,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        key: const ValueKey('dashboard-filter-selector'),
                        onPressed: onOpenFilters,
                        icon: Icon(
                          Icons.tune,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isWide ? 18 : 12),
            Expanded(
              child: isWide
                  ? _WideDashboardLayout(
                      data: dashboardData,
                      dashboardTypes: dashboardTypes,
                      recentItems: recentItems,
                      adapters: adapters,
                      keyForRow: keyForRow,
                      iconForType: iconForType,
                      colorForType: colorForType,
                      onTypeTap: onTypeTap,
                      onViewAll: onViewAll,
                      onAddItem: onAddItem,
                      onImportData: onImportData,
                      onSwitchVault: onSwitchVault,
                      onShowDemoPreview: onShowDemoPreview,
                      onHideDemoPreview: onHideDemoPreview,
                      onOpenRow: onOpenRow,
                      onRowActions: onRowActions,
                    )
                  : _MobileDashboardList(
                      data: dashboardData,
                      recentItems: recentItems,
                      adapters: adapters,
                      keyForRow: keyForRow,
                      iconForType: iconForType,
                      colorForType: colorForType,
                      onTypeTap: onTypeTap,
                      onViewAll: onViewAll,
                      onShowDemoPreview: onShowDemoPreview,
                      onHideDemoPreview: onHideDemoPreview,
                      onOpenRow: onOpenRow,
                      onRowActions: onRowActions,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDashboardList extends StatelessWidget {
  const _MobileDashboardList({
    required this.data,
    required this.recentItems,
    required this.adapters,
    required this.keyForRow,
    required this.iconForType,
    required this.colorForType,
    required this.onTypeTap,
    required this.onViewAll,
    required this.onShowDemoPreview,
    required this.onHideDemoPreview,
    required this.onOpenRow,
    required this.onRowActions,
  });

  final _DashboardData data;
  final List<Map<String, dynamic>> recentItems;
  final List<VaultListEntryAdapter> adapters;
  final String Function(Map<String, dynamic> row) keyForRow;
  final IconData Function(String type) iconForType;
  final Color Function(String type) colorForType;
  final ValueChanged<String> onTypeTap;
  final VoidCallback onViewAll;
  final VoidCallback onShowDemoPreview;
  final VoidCallback onHideDemoPreview;
  final ValueChanged<Map<String, dynamic>> onOpenRow;
  final ValueChanged<Map<String, dynamic>> onRowActions;

  @override
  Widget build(BuildContext context) {
    final categories = _homeDashboardCategories(data);
    return ListView(
      children: [
        if (data.isDemo ||
            data.canShowDemoPreview ||
            data.isExploreSession) ...[
          _DemoDashboardNotice(
            isActive: data.isDemo || data.isExploreSession,
            isExploreSession: data.isExploreSession,
            onShowPreview: onShowDemoPreview,
            onHidePreview: onHideDemoPreview,
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 700 ? 4 : 2;
            final childAspectRatio = crossAxisCount >= 4 ? 1.2 : 1.45;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final entry = categories[index];
                return _HomeTypeCard(
                  label: entry.label,
                  count: entry.count,
                  icon: iconForType(entry.filterType),
                  accent: colorForType(entry.filterType),
                  onTap: () => onTypeTap(entry.filterType),
                );
              },
            );
          },
        ),
        const SizedBox(height: 14),
        _DashboardSectionTitle(title: 'Recent', onViewAll: onViewAll),
        const SizedBox(height: 6),
        _DashboardRecentList(
          recentItems: recentItems,
          adapters: adapters,
          keyForRow: keyForRow,
          onOpenRow: onOpenRow,
          onRowActions: onRowActions,
        ),
      ],
    );
  }
}

class _WideDashboardLayout extends StatelessWidget {
  const _WideDashboardLayout({
    required this.data,
    required this.dashboardTypes,
    required this.recentItems,
    required this.adapters,
    required this.keyForRow,
    required this.iconForType,
    required this.colorForType,
    required this.onTypeTap,
    required this.onViewAll,
    required this.onAddItem,
    required this.onImportData,
    required this.onSwitchVault,
    required this.onShowDemoPreview,
    required this.onHideDemoPreview,
    required this.onOpenRow,
    required this.onRowActions,
  });

  final _DashboardData data;
  final List<MapEntry<String, int>> dashboardTypes;
  final List<Map<String, dynamic>> recentItems;
  final List<VaultListEntryAdapter> adapters;
  final String Function(Map<String, dynamic> row) keyForRow;
  final IconData Function(String type) iconForType;
  final Color Function(String type) colorForType;
  final ValueChanged<String> onTypeTap;
  final VoidCallback onViewAll;
  final VoidCallback onAddItem;
  final VoidCallback onImportData;
  final VoidCallback onSwitchVault;
  final VoidCallback onShowDemoPreview;
  final VoidCallback onHideDemoPreview;
  final ValueChanged<Map<String, dynamic>> onOpenRow;
  final ValueChanged<Map<String, dynamic>> onRowActions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (data.isDemo ||
            data.canShowDemoPreview ||
            data.isExploreSession) ...[
          _DemoDashboardNotice(
            isActive: data.isDemo || data.isExploreSession,
            isExploreSession: data.isExploreSession,
            onShowPreview: onShowDemoPreview,
            onHidePreview: onHideDemoPreview,
          ),
          const SizedBox(height: 12),
        ],
        _DesktopDashboardStats(
          stats: [
            _DashboardStatData(
              label: 'Total Items',
              value: data.totalCount,
              icon: Icons.inventory_2_outlined,
            ),
            _DashboardStatData(
              label: 'Folders',
              value: data.folderCount,
              icon: Icons.folder_outlined,
            ),
            _DashboardStatData(
              label: 'Logins',
              value: data.typeCounts['Login'] ?? 0,
              icon: Icons.lock_outline,
            ),
            _DashboardStatData(
              label: 'Notes',
              value: data.dashboardTypes
                  .firstWhere(
                    (entry) => entry.key == 'Notes',
                    orElse: () => const MapEntry<String, int>('Notes', 0),
                  )
                  .value,
              icon: Icons.description_outlined,
            ),
            _DashboardStatData(
              label: 'Identities',
              value:
                  (data.typeCounts['Identity'] ?? 0) +
                  (data.typeCounts['Passport'] ?? 0) +
                  (data.typeCounts['Driver License'] ?? 0),
              icon: Icons.badge_outlined,
            ),
            _DashboardStatData(
              label: 'Documents',
              value:
                  (data.typeCounts['Documents'] ?? 0) +
                  (data.typeCounts['Document'] ?? 0),
              icon: Icons.folder_copy_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final showSidePanel = constraints.maxWidth >= 880;
            final recent = _DesktopPanel(
              title: 'Recent Items',
              trailing: TextButton(
                onPressed: onViewAll,
                child: Text(
                  'View all',
                  style: DashboardTypography.textLink(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              child: _WideDashboardRecentList(
                recentItems: recentItems,
                adapters: adapters,
                keyForRow: keyForRow,
                onOpenRow: onOpenRow,
                onRowActions: onRowActions,
              ),
            );
            final actions = _DesktopPanel(
              title: 'Quick Actions',
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _QuickActionGrid(
                  actions: [
                    _QuickActionTileData(
                      icon: Icons.add,
                      label: 'Add Item',
                      onTap: onAddItem,
                    ),
                    _QuickActionTileData(
                      icon: Icons.grid_view_outlined,
                      label: 'All Items',
                      onTap: onViewAll,
                    ),
                    _QuickActionTileData(
                      icon: Icons.download_outlined,
                      label: 'Import',
                      onTap: onImportData,
                    ),
                    _QuickActionTileData(
                      icon: Icons.switch_access_shortcut_outlined,
                      label: 'Switch Vault',
                      onTap: onSwitchVault,
                    ),
                  ],
                ),
              ),
            );
            if (!showSidePanel) {
              return Column(
                children: [recent, const SizedBox(height: 12), actions],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: recent),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: actions),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DemoDashboardNotice extends StatelessWidget {
  const _DemoDashboardNotice({
    required this.isActive,
    required this.isExploreSession,
    required this.onShowPreview,
    required this.onHidePreview,
  });

  final bool isActive;
  final bool isExploreSession;
  final VoidCallback onShowPreview;
  final VoidCallback onHidePreview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeMessage = isExploreSession
        ? AppStrings.exploreDemoActiveNotice
        : 'Viewing sample data. Your vault has not been changed.';
    final inactiveMessage =
        'New here? Preview how a filled vault dashboard looks.';
    final exitLabel = isExploreSession
        ? AppStrings.exitExploreDemo
        : 'Exit demo';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isActive ? Icons.visibility_outlined : Icons.auto_awesome_outlined,
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isActive ? activeMessage : inactiveMessage,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            fit: FlexFit.loose,
            child: OutlinedButton(
              key: ValueKey(
                isActive
                    ? 'dashboard-hide-demo-preview'
                    : 'dashboard-show-demo-preview',
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: isActive ? onHidePreview : onShowPreview,
              child: Text(isActive ? exitLabel : 'View demo preview'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatData {
  const _DashboardStatData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;
}

class _DesktopDashboardStats extends StatelessWidget {
  const _DesktopDashboardStats({required this.stats});

  final List<_DashboardStatData> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100 ? 6 : 3;
        return GridView.builder(
          key: const ValueKey('desktop-dashboard-stats'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 88,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            return _DesktopDashboardStatCard(stat: stat);
          },
        );
      },
    );
  }
}

class _DesktopDashboardStatCard extends StatelessWidget {
  const _DesktopDashboardStatCard({required this.stat});

  final _DashboardStatData stat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey<String>('desktop-dashboard-stat-${stat.label}'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${stat.value}',
            style: DashboardTypography.statValue(colorScheme.onSurface),
          ),
          const SizedBox(height: 5),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardTypography.statLabel(colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _HomeCategoryData {
  const _HomeCategoryData({
    required this.label,
    required this.filterType,
    required this.count,
  });

  final String label;
  final String filterType;
  final int count;
}

List<_HomeCategoryData> _homeDashboardCategories(_DashboardData data) {
  final candidates = <_HomeCategoryData>[
    _HomeCategoryData(
      label: 'Notes',
      filterType: 'Notes',
      count: data.dashboardTypes
          .firstWhere(
            (entry) => entry.key == 'Notes',
            orElse: () => const MapEntry<String, int>('Notes', 0),
          )
          .value,
    ),
    _HomeCategoryData(
      label: 'Logins',
      filterType: 'Login',
      count: data.typeCounts['Login'] ?? 0,
    ),
    _HomeCategoryData(
      label: 'Identities',
      filterType: 'Identity',
      count:
          (data.typeCounts['Identity'] ?? 0) +
          (data.typeCounts['Passport'] ?? 0) +
          (data.typeCounts['Driver License'] ?? 0),
    ),
    _HomeCategoryData(
      label: 'Documents',
      filterType: data.typeCounts.containsKey('Documents')
          ? 'Documents'
          : 'Document',
      count:
          (data.typeCounts['Documents'] ?? 0) +
          (data.typeCounts['Document'] ?? 0),
    ),
  ];
  final coveredTypes = <String>{
    'Notes',
    'Login',
    'Identity',
    'Passport',
    'Driver License',
    'Documents',
    'Document',
  };
  for (final entry in data.dashboardTypes) {
    if (coveredTypes.contains(entry.key)) continue;
    candidates.add(
      _HomeCategoryData(
        label: entry.key,
        filterType: entry.key,
        count: entry.value,
      ),
    );
  }
  return candidates.where((category) => category.count > 0).toList();
}

class _DashboardSectionTitle extends StatelessWidget {
  const _DashboardSectionTitle({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onViewAll,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text('View all', style: TextStyle(color: Color(0xFF4F46E5))),
          ),
        ),
      ],
    );
  }
}

class _DashboardRecentList extends StatelessWidget {
  const _DashboardRecentList({
    required this.recentItems,
    required this.adapters,
    required this.keyForRow,
    required this.onOpenRow,
    required this.onRowActions,
  });

  final List<Map<String, dynamic>> recentItems;
  final List<VaultListEntryAdapter> adapters;
  final String Function(Map<String, dynamic> row) keyForRow;
  final ValueChanged<Map<String, dynamic>> onOpenRow;
  final ValueChanged<Map<String, dynamic>> onRowActions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (recentItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Text(
          'No recent items yet.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    return VaultEntryList(
      rows: recentItems,
      adapters: adapters,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      iconAlpha: 0.2,
      rowPadding: const EdgeInsets.all(12),
      trailingMode: VaultEntryTrailingMode.more,
      keyForRow: keyForRow,
      onTap: onOpenRow,
      onMoreTap: onRowActions,
    );
  }
}
