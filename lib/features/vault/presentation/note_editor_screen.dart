import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../core/localization/app_strings.dart';
import '../../../domain/models/vault_folder.dart';
import 'widgets/vault_folder_hierarchy_sheet.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.initialNote,
    this.onAutoSave,
    this.folders = const <VaultFolder>[],
    this.initialFolderId,
    this.onCreateFolder,
  });

  final Map<String, dynamic>? initialNote;
  final ValueChanged<Map<String, dynamic>>? onAutoSave;
  final List<VaultFolder> folders;
  final String? initialFolderId;
  final VaultFolderCreateCallback? onCreateFolder;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  static const noteAutosaveInterval = Duration(seconds: 1);
  late final TextEditingController _titleController;
  late final TextEditingController _tagController;
  late final quill.QuillController _quillController;
  late final ScrollController _editorScrollController;
  late final FocusNode _editorFocusNode;
  late final List<String> _tags;
  late final String _noteId;
  late String _selectedFolderId;
  late final List<VaultFolder> _customFolders;
  late bool _isFavorite;
  Timer? _autosaveTimer;
  late final String _initialFingerprint;
  String _lastAutoSavedFingerprint = '';
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialNote?['title']?.toString() ?? '',
    );
    _tagController = TextEditingController();
    _tags = _extractInitialTags(widget.initialNote);
    _editorScrollController = ScrollController();
    _editorFocusNode = FocusNode();
    _quillController = quill.QuillController(
      document: _buildInitialDocument(widget.initialNote),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _noteId =
        widget.initialNote?['id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    _customFolders = widget.folders.where((f) => f.id != 'default').toList();
    _isFavorite = widget.initialNote?['pinned'] == true;
    final initialFid = widget.initialNote?['folderId']?.toString().trim() ??
        widget.initialFolderId?.trim();
    _selectedFolderId =
        (initialFid != null && initialFid.isNotEmpty) ? initialFid : 'default';
    _initialFingerprint = _fingerprintForCurrentState();
    _lastAutoSavedFingerprint = _initialFingerprint;
    _titleController.addListener(_markDirty);
    _quillController.addListener(_markDirty);
  }

  String _resolveFolderName(String folderId, List<VaultFolder> folders) {
    if (folderId.isEmpty || folderId == 'default') {
      return 'Default';
    }
    for (final folder in folders) {
      if (folder.id == folderId) return folder.name;
    }
    return folderId;
  }

  VaultFolder _resolveFolder(String folderId) {
    for (final folder in _effectiveFolders) {
      if (folder.id == folderId) return folder;
    }
    return VaultFolder(
      id: folderId,
      name: folderId.isEmpty || folderId == 'default' ? 'Default' : folderId,
      icon: folderId == 'default' ? 'folder_special' : null,
      createdAt: '',
      updatedAt: '',
    );
  }

  Future<void> _openFolderPicker() async {
    final picked = await showVaultFolderHierarchySheet(
      context,
      folders: _effectiveFolders,
      selectedFolderId: _selectedFolderId,
      onCreateFolder: widget.onCreateFolder,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedFolderId = picked.id;
        if (!_customFolders.any((f) => f.id == picked.id) && picked.id != 'default') {
          _customFolders.add(picked);
        }
      });
      _markDirty();
    }
  }

  List<VaultFolder> get _effectiveFolders {
    return [
      const VaultFolder(
        id: 'default',
        name: 'Default',
        icon: 'folder_special',
        createdAt: '',
        updatedAt: '',
      ),
      ..._customFolders,
    ];
  }


  @override
  void dispose() {
    _titleController.removeListener(_markDirty);
    _quillController.removeListener(_markDirty);
    _titleController.dispose();
    _tagController.dispose();
    _editorScrollController.dispose();
    _editorFocusNode.dispose();
    _quillController.dispose();
    _autosaveTimer?.cancel();
    super.dispose();
  }

  void _markDirty() {
    _dirty = true;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(noteAutosaveInterval, _emitAutoSave);
  }

  List<String> _extractInitialTags(Map<String, dynamic>? note) {
    final raw = (note?['tags'] as List<dynamic>? ?? const <dynamic>[]);
    final normalized = raw
        .map((entry) => entry.toString().trim().toLowerCase())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList();
    if (normalized.isEmpty) return <String>['note'];
    normalized.sort();
    return normalized;
  }

  quill.Document _buildInitialDocument(Map<String, dynamic>? note) {
    final delta = note?['delta'];
    if (delta is List) {
      return quill.Document.fromJson(
        delta.map((entry) => Map<String, dynamic>.from(entry as Map)).toList(),
      );
    }

    final fallbackText = note?['preview']?.toString() ?? '';
    if (fallbackText.isEmpty) return quill.Document();
    return quill.Document()..insert(0, '$fallbackText\n');
  }

  Widget _buildNotesCanvasHeader(ColorScheme colorScheme, ThemeData theme) {
    final selectedFolder = _resolveFolder(_selectedFolderId);
    final folderColor = resolveFolderColor(selectedFolder);
    final folderName = selectedFolder.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Folder Pill and Favorite Row (One UI Samsung Notes style)
        Row(
          children: [
            Material(
              color: folderColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                key: const ValueKey('note-folder-selector'),
                borderRadius: BorderRadius.circular(20),
                onTap: _openFolderPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selectedFolder.id == 'default' ? Icons.folder_special : Icons.folder,
                        size: 15,
                        color: folderColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        folderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: folderColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: folderColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              key: const ValueKey('note-favorite-button'),
              tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
              icon: Icon(
                _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _isFavorite ? const Color(0xFFF59E0B) : colorScheme.onSurfaceVariant,
                size: 22,
              ),
              onPressed: () {
                setState(() => _isFavorite = !_isFavorite);
                _markDirty();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Large Title Input Row + Clear ('X') Button
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('note-details-title-input'),
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
                onChanged: (_) {
                  setState(() {});
                  _markDirty();
                },
              ),
            ),
            if (_titleController.text.isNotEmpty)
              IconButton(
                key: const ValueKey('note-title-clear-button'),
                icon: Icon(Icons.cancel, size: 20, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                tooltip: 'Clear title',
                onPressed: () {
                  _titleController.clear();
                  setState(() {});
                  _markDirty();
                },
              ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          height: 2,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _saveAndPop();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _saveAndPop,
                    ),
                    Expanded(
                      child: InkWell(
                        key: const ValueKey('note-title-header-button'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: _openFolderPicker,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _titleController.text.trim().isEmpty ? 'New note' : _titleController.text.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: colorScheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (_isFavorite) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${_resolveFolderName(_selectedFolderId, _effectiveFolders)} · Note',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Undo',
                      icon: const Icon(Icons.undo, size: 20),
                      onPressed: () => _quillController.undo(),
                    ),
                    IconButton(
                      tooltip: 'Redo',
                      icon: const Icon(Icons.redo, size: 20),
                      onPressed: () => _quillController.redo(),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      key: const ValueKey('note-save-button'),
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.onSurface,
                        foregroundColor: colorScheme.surface,
                        minimumSize: const Size(68, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        keyboardVisible ? keyboardInset + 12 : 16,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 860,
                            minHeight:
                                constraints.maxHeight -
                                (keyboardVisible ? keyboardInset : 0) -
                                32,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildNotesCanvasHeader(colorScheme, theme),
                              quill.QuillSimpleToolbar(
                                controller: _quillController,
                                config: const quill.QuillSimpleToolbarConfig(
                                  multiRowsDisplay: false,
                                  toolbarSectionSpacing: 1,
                                  showDividers: false,
                                  buttonOptions:
                                      quill.QuillSimpleToolbarButtonOptions(
                                    base: quill.QuillToolbarBaseButtonOptions(
                                      iconButtonFactor: 1.15,
                                      iconSize: 15,
                                    ),
                                  ),
                                  showFontFamily: false,
                                  showFontSize: true,
                                  showSubscript: false,
                                  showSuperscript: false,
                                  showInlineCode: true,
                                  showCodeBlock: true,
                                  showColorButton: true,
                                  showBackgroundColorButton: true,
                                  showAlignmentButtons: true,
                                  showDirection: true,
                                  showIndent: true,
                                  showHeaderStyle: true,
                                  showQuote: true,
                                  showBoldButton: true,
                                  showItalicButton: true,
                                  showUnderLineButton: true,
                                  showStrikeThrough: true,
                                  showListBullets: true,
                                  showListCheck: true,
                                  showListNumbers: true,
                                  showLink: true,
                                ),
                              ),
                              Divider(
                                height: 12,
                                thickness: 0.5,
                                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                              ),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: (constraints.maxHeight - 200).clamp(360.0, 10000.0),
                                ),
                                child: quill.QuillEditor.basic(
                                  controller: _quillController,
                                  focusNode: _editorFocusNode,
                                  scrollController: _editorScrollController,
                                  config: quill.QuillEditorConfig(
                                    placeholder:
                                        'Start writing a private document...',
                                    scrollable: true,
                                    autoFocus: true,
                                    scrollBottomInset: keyboardVisible
                                        ? keyboardInset + 24
                                        : 80,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 8,
                                    ),
                                    customStyles: quill.DefaultStyles(
                                      paragraph: quill.DefaultTextBlockStyle(
                                        TextStyle(
                                          color: colorScheme.onSurface,
                                          fontSize: 15,
                                          height: 1.5,
                                        ),
                                        const quill.HorizontalSpacing(0, 0),
                                        const quill.VerticalSpacing(0, 0),
                                        const quill.VerticalSpacing(0, 0),
                                        null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _NoteEditorSnapshot _buildSnapshot() {
    final fallbackTitle =
        widget.initialNote?['title']?.toString().trim().isNotEmpty == true
        ? widget.initialNote!['title'].toString().trim()
        : 'Untitled note';
    final title = _titleController.text.trim().isEmpty
        ? fallbackTitle
        : _titleController.text.trim();
    final normalizedTitle = _normalizedTitle();
    final plainText = _quillController.document.toPlainText().trim();
    final preview = plainText
        .split('\n')
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
    final deltaJson = _quillController.document.toDelta().toJson();
    final tags =
        _tags
            .map((entry) => entry.trim().toLowerCase())
            .where((entry) => entry.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final fingerprint = jsonEncode({
      'title': normalizedTitle,
      'plainText': plainText,
      'tags': tags,
      'folderId': _selectedFolderId,
      'pinned': _isFavorite,
      'delta': deltaJson,
    });
    final effectiveTags = tags.isEmpty ? <String>['note'] : tags;
    return _NoteEditorSnapshot(
      fingerprint: fingerprint,
      isEmptyDraft: normalizedTitle.isEmpty && plainText.isEmpty,
      payload: {
        'id': _noteId,
        'title': title,
        'preview': preview,
        'updated': 'Now',
        'pinned': _isFavorite,
        'tags': effectiveTags,
        'folderId': _selectedFolderId,
        'delta': _cloneDeltaJson(deltaJson),
      },
    );
  }

  String _normalizedTitle() => _titleController.text.trim();

  List<Map<String, dynamic>> _cloneDeltaJson(List<dynamic> deltaJson) {
    return deltaJson
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList(growable: false);
  }

  String _fingerprintForCurrentState() => _buildSnapshot().fingerprint;

  void _emitAutoSave() {
    final callback = widget.onAutoSave;
    if (callback == null) return;
    if (!_dirty) return;
    final snapshot = _buildSnapshot();
    if (snapshot.isEmptyDraft) return;
    if (snapshot.fingerprint == _initialFingerprint) {
      _dirty = false;
      return;
    }
    if (snapshot.fingerprint == _lastAutoSavedFingerprint) {
      _dirty = false;
      return;
    }
    _lastAutoSavedFingerprint = snapshot.fingerprint;
    _dirty = false;
    callback(snapshot.payload);
  }

  void _saveAndPop() {
    _autosaveTimer?.cancel();
    final snapshot = _buildSnapshot();
    if (widget.initialNote == null && snapshot.isEmptyDraft) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    if (widget.onAutoSave != null &&
        snapshot.fingerprint != _initialFingerprint &&
        snapshot.fingerprint != _lastAutoSavedFingerprint) {
      _lastAutoSavedFingerprint = snapshot.fingerprint;
      widget.onAutoSave!(snapshot.payload);
    }
    _dirty = false;
    if (!mounted) return;
    Navigator.of(context).pop(snapshot.payload);
  }

  void _save() {
    _saveAndPop();
  }
}

class _NoteEditorSnapshot {
  const _NoteEditorSnapshot({
    required this.fingerprint,
    required this.isEmptyDraft,
    required this.payload,
  });

  final String fingerprint;
  final bool isEmptyDraft;
  final Map<String, dynamic> payload;
}


class NoteViewScreen extends StatefulWidget {
  const NoteViewScreen({
    super.key,
    required this.note,
    this.showDeleteAction = false,
    this.readOnly = false,
    this.onAutoSave,
    this.onShareMenu,
    this.folders = const <VaultFolder>[],
    this.onCreateFolder,
  });

  final Map<String, dynamic> note;
  final bool showDeleteAction;
  final bool readOnly;
  final ValueChanged<Map<String, dynamic>>? onAutoSave;
  final VoidCallback? onShareMenu;
  final List<VaultFolder> folders;
  final VaultFolderCreateCallback? onCreateFolder;

  @override
  State<NoteViewScreen> createState() => _NoteViewScreenState();
}

class _NoteViewScreenState extends State<NoteViewScreen> {
  late final quill.QuillController _controller;
  late final bool _isRecoveryNote;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _isRecoveryNote = _checkIsRecoveryNote(widget.note);
    final delta = widget.note['delta'] as List<dynamic>?;
    final document = delta == null
        ? (quill.Document()
            ..insert(0, '${widget.note['preview']?.toString() ?? ''}\n'))
        : quill.Document.fromJson(
            delta
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList(),
          );

    _controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _resolveFolderName(String? folderId, List<VaultFolder> folders) {
    if (folderId == null || folderId.isEmpty || folderId == 'default') {
      return 'Default';
    }
    for (final folder in folders) {
      if (folder.id == folderId) return folder.name;
    }
    return folderId;
  }

  bool _checkIsRecoveryNote(Map<String, dynamic> note) {
    if (note['id']?.toString() == 'note-recovery-phrase') return true;
    final tags = (note['tags'] as List<dynamic>?)
            ?.map((t) => t.toString().toLowerCase().trim())
            .toSet() ??
        <String>{};
    if (tags.contains('recovery') || tags.contains('seed')) return true;
    final title = note['title']?.toString().toLowerCase().trim() ?? '';
    return title.contains('recovery phrase') || title.contains('seed phrase');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final folderId = widget.note['folderId']?.toString().trim();
    final folderName = _resolveFolderName(folderId, widget.folders);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.note['title']?.toString() ?? 'Note',
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  folderName == 'Default'
                      ? Icons.folder_special
                      : Icons.folder_outlined,
                  size: 13,
                  color: folderName == 'Default'
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEAB308),
                ),
                const SizedBox(width: 4),
                Text(
                  folderName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_isRecoveryNote && _revealed)
            IconButton(
              icon: const Icon(Icons.visibility_off_outlined),
              tooltip: 'Hide phrase',
              onPressed: () => setState(() => _revealed = false),
            ),
          if (widget.onShareMenu != null)
            IconButton(
              key: const ValueKey('note-view-share-menu'),
              onPressed: widget.onShareMenu,
              icon: const Icon(Icons.share_outlined),
              tooltip: AppStrings.shareEncryptedFile,
            ),
          if (!widget.readOnly)
            TextButton(
              onPressed: () async {
                final updated = await Navigator.of(context)
                    .push<Map<String, dynamic>>(
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(
                          initialNote: widget.note,
                          onAutoSave: widget.onAutoSave,
                          folders: widget.folders,
                          onCreateFolder: widget.onCreateFolder,
                        ),
                      ),
                    );
                if (updated == null || !context.mounted) return;
                Navigator.of(context).pop(updated);
              },
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(AppStrings.edit),
            ),
          if (widget.showDeleteAction)
            IconButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(<String, dynamic>{'__delete__': true}),
              icon: const Icon(Icons.delete_outline),
              tooltip: AppStrings.delete,
            ),
        ],
      ),
      body: SafeArea(
        child: _isRecoveryNote && !_revealed
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.shield_outlined,
                                size: 28,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Sensitive Recovery Phrase',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '•••• •••• •••• ••••\n•••• •••• •••• ••••\n•••• •••• •••• ••••',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 16,
                                letterSpacing: 2,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Keep this phrase offline and private. Only reveal when you are in a secure location.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              key: const ValueKey(
                                'note-reveal-recovery-phrase-button',
                              ),
                              onPressed: () => setState(() => _revealed = true),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 18,
                              ),
                              label: const Text('Reveal Recovery Phrase'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: IgnorePointer(
                  child: quill.QuillEditor.basic(
                    controller: _controller,
                    config: quill.QuillEditorConfig(
                      customStyles: quill.DefaultStyles(
                        paragraph: quill.DefaultTextBlockStyle(
                          TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 15,
                            height: 1.5,
                          ),
                          const quill.HorizontalSpacing(0, 0),
                          const quill.VerticalSpacing(0, 0),
                          const quill.VerticalSpacing(0, 0),
                          null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
