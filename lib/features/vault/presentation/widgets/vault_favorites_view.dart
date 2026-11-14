part of '../vault_app_shell.dart';

extension _VaultFavoritesTab on _VaultAppShellState {
  Widget _buildFavoritesTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = _isWideLayout(context);
    final favoriteItems = _items
        .where((item) => item['pinned'] == true)
        .map((item) => <String, dynamic>{'kind': 'item', 'entry': item})
        .toList();
    final favoriteNotes = _notes
        .where((note) => note['pinned'] == true)
        .map((note) => <String, dynamic>{'kind': 'note', 'entry': note})
        .toList();
    final allFavorites =
        <Map<String, dynamic>>[...favoriteItems, ...favoriteNotes]
          ..sort((a, b) {
            final av = a['entry'] as Map<String, dynamic>;
            final bv = b['entry'] as Map<String, dynamic>;
            return _updatedSortValue(
              bv['updated']?.toString() ?? '',
            ).compareTo(_updatedSortValue(av['updated']?.toString() ?? ''));
          });

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isWide ? 24 : 16,
        isWide ? 8 : 12,
        isWide ? 24 : 16,
        isWide ? 24 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isWide)
            _SectionHeader(
              title: AppStrings.tabNotes,
              subtitle: 'Starred secrets',
            ),
          if (!isWide) const SizedBox(height: 10),
          if (isWide) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: TextField(
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search favorites...',
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(
                      Icons.search,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Sort by: Modified (newest)',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '${allFavorites.length} items',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: allFavorites.isEmpty
                ? const _EmptyState(
                    title: 'No favorites yet',
                    subtitle: 'Star items from quick actions to see them here.',
                  )
                : isWide
                ? _WideAllItemsIndex(
                    rows: allFavorites,
                    adapters: _vaultListEntryAdapters,
                    selectionMode: false,
                    selectedKeys: const {},
                    keyForRow: _vaultListKeyForRow,
                    onTap: (row) => _openVaultListRow(context, row),
                    onMoreTap: (row) =>
                        _showVaultListRowQuickActions(context, row),
                  )
                : VaultEntryList(
                    rows: allFavorites,
                    adapters: _vaultListEntryAdapters,
                    keyForRow: _vaultListKeyForRow,
                    trailingMode: VaultEntryTrailingMode.more,
                    forceFavoriteIndicator: true,
                    onTap: (row) => _openVaultListRow(context, row),
                    onMoreTap: (row) =>
                        _showVaultListRowQuickActions(context, row),
                  ),
          ),
        ],
      ),
    );
  }
}
