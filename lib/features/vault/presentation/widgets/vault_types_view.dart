part of '../vault_app_shell.dart';

extension _VaultTypesTab on _VaultAppShellState {
  Widget _buildTypesTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = _isWideLayout(context);
    final all = <Map<String, dynamic>>[
      ..._items.map((item) => <String, dynamic>{'kind': 'item', 'entry': item}),
      ..._notes.map((note) => <String, dynamic>{'kind': 'note', 'entry': note}),
    ];
    all.sort((a, b) {
      final av = a['entry'] as Map<String, dynamic>;
      final bv = b['entry'] as Map<String, dynamic>;
      return _entryUpdatedSortValue(bv).compareTo(_entryUpdatedSortValue(av));
    });

    final sortedTypeOptions = ['all', ..._allTypeFilterOptions()];

    final query = _allItemsQuery.trim().toLowerCase();
    final filterSearch = _allItemsFilterSearch.trim().toLowerCase();
    final filtered = all.where((row) {
      final kind = row['kind']?.toString() ?? 'item';
      final entry = row['entry'] as Map<String, dynamic>;
      final type = kind == 'note'
          ? 'Notes'
          : (entry['type']?.toString().trim().isNotEmpty == true
                ? entry['type'].toString().trim()
                : 'Unknown');
      final title = entry['title']?.toString().toLowerCase() ?? '';
      final subtitle =
          (kind == 'note'
                  ? entry['preview']?.toString()
                  : entry['subtitle']?.toString())
              ?.toLowerCase() ??
          '';
      final searchableText = _entrySearchText(kind, entry);
      final matchesQuery =
          query.isEmpty ||
          title.contains(query) ||
          subtitle.contains(query) ||
          searchableText.contains(query);
      final matchesOverlaySearch =
          filterSearch.isEmpty ||
          title.contains(filterSearch) ||
          subtitle.contains(filterSearch) ||
          searchableText.contains(filterSearch);
      final matchesType =
          _allItemsTypeFilter == 'all' || _allItemsTypeFilter == type;
      final matchesOverlayType =
          _allItemsFilterTypes.isEmpty || _allItemsFilterTypes.contains(type);
      final matchesFavorite =
          !_allItemsFilterFavoritesOnly || entry['pinned'] == true;
      final matchesDate = _matchesAllItemsDateFilter(entry);
      return matchesQuery &&
          matchesOverlaySearch &&
          matchesType &&
          matchesOverlayType &&
          matchesFavorite &&
          matchesDate;
    }).toList();
    return SafeArea(
      top: !isWide,
      bottom: !isWide,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isWide ? 24 : 16,
          16,
          isWide ? 24 : 16,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_allItemsSelectionMode)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _clearAllItemsSelection,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else if (!isWide)
                  Text(AppStrings.allItems, style: vaultPageHeadingStyle(context)),
                const Spacer(),
                if (_allItemsSelectionMode)
                  Text(
                    '${_selectedAllItemsKeys.length} Selected',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const Spacer(),
                if (_allItemsSelectionMode)
                  const SizedBox.shrink()
                else if (isWide)
                  FilledButton.icon(
                    onPressed: () => _openAddItemScreen(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppStrings.addItem),
                  ),
              ],
            ),
            if (!_allItemsSelectionMode)
              Text(
                '${filtered.length} items',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _allItemsSearchController,
                    focusNode: _searchFocusNode,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: AppStrings.searchAllItemsHint,
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) =>
                        _updateState(() => _allItemsQuery = value),
                  ),
                ),
                const SizedBox(width: 8),
                if (!_allItemsSelectionMode)
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: () => _openAllItemsFiltersOverlay(
                        sortedTypeOptions.where((t) => t != 'all').toList(),
                      ),
                      icon: Icon(
                        Icons.tune,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sortedTypeOptions.map((type) {
                  final selected = _allItemsTypeFilter == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _AllItemsTypeChip(
                      label: type == 'all' ? 'All' : type,
                      selected: selected,
                      onTap: () =>
                          _updateState(() => _allItemsTypeFilter = type),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            if (_activeAllItemsFilterChips().isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ..._activeAllItemsFilterChips().map(
                    (chip) => _TinyChip(label: chip),
                  ),
                  InkWell(
                    onTap: _clearAllItemsOverlayFilters,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Clear all',
                        style: TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (!_allItemsSelectionMode)
              Text(
                'Sort by: Modified (newest)',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No items found.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : isWide
                  ? _WideAllItemsIndex(
                      rows: filtered,
                      adapters: _vaultListEntryAdapters,
                      selectionMode: _allItemsSelectionMode,
                      selectedKeys: _selectedAllItemsKeys,
                      keyForRow: _allItemsSelectionKey,
                      onTap: (row) {
                        if (_allItemsSelectionMode) {
                          _toggleAllItemsSelection(row);
                          return;
                        }
                        _openVaultListRow(context, row);
                      },
                      onLongPress: kIsWeb
                          ? null
                          : (row) {
                              if (_allItemsSelectionMode) {
                                _toggleAllItemsSelection(row);
                                return;
                              }
                              _enterAllItemsSelectionMode(row);
                            },
                      onMoreTap: (row) =>
                          _showVaultListRowQuickActions(context, row),
                    )
                  : VaultEntryList(
                      padding: const EdgeInsets.only(bottom: 80),
                      rows: filtered,
                      adapters: _vaultListEntryAdapters,
                      selectionMode: _allItemsSelectionMode,
                      selectedKeys: _selectedAllItemsKeys,
                      keyForRow: _allItemsSelectionKey,
                      trailingMode: _allItemsSelectionMode
                          ? VaultEntryTrailingMode.chevron
                          : VaultEntryTrailingMode.more,
                      onTap: (row) {
                        if (_allItemsSelectionMode) {
                          _toggleAllItemsSelection(row);
                          return;
                        }
                        _openVaultListRow(context, row);
                      },
                      onLongPress: kIsWeb
                          ? null
                          : (row) {
                              if (_allItemsSelectionMode) {
                                _toggleAllItemsSelection(row);
                                return;
                              }
                              _enterAllItemsSelectionMode(row);
                            },
                      onMoreTap: (row) =>
                          _showVaultListRowQuickActions(context, row),
                    ),
            ),
            if (_allItemsSelectionMode)
              _AllItemsSelectionActionBar(
                onFavorite: _togglePinSelectedAllItems,
                onDelete: _deleteSelectedAllItems,
                onMore: _showAllItemsMoreActions,
              ),
          ],
        ),
      ),
    );
  }
}
