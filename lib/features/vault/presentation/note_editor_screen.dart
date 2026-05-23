import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../core/localization/app_strings.dart';
import 'widgets/vault_page_heading.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.initialNote, this.onAutoSave});

  final Map<String, dynamic>? initialNote;
  final ValueChanged<Map<String, dynamic>>? onAutoSave;

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
  Timer? _autosaveTimer;
  late final String _initialFingerprint;
  String _lastAutoSavedFingerprint = '';

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
    _initialFingerprint = _fingerprintForCurrentState();
    _lastAutoSavedFingerprint = _initialFingerprint;
    _autosaveTimer = Timer.periodic(noteAutosaveInterval, (_) {
      _emitAutoSave();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    _editorScrollController.dispose();
    _editorFocusNode.dispose();
    _quillController.dispose();
    _autosaveTimer?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _saveAndPop();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _saveAndPop,
          ),
          title: Text(widget.initialNote == null ? 'New note' : 'Edit note'),
          actions: [
            TextButton(
              onPressed: _save,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: TextField(
                  controller: _titleController,
                  style: vaultPageHeadingStyle(context),
                  decoration: const InputDecoration(
                    hintText: 'Untitled note',
                    hintStyle: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              quill.QuillSimpleToolbar(
                controller: _quillController,
                config: const quill.QuillSimpleToolbarConfig(
                  multiRowsDisplay: false,
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
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    keyboardVisible ? 0 : 12,
                  ),
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: quill.QuillEditor.basic(
                      controller: _quillController,
                      focusNode: _editorFocusNode,
                      scrollController: _editorScrollController,
                      config: quill.QuillEditorConfig(
                        placeholder: 'Start writing a private document...',
                        scrollable: true,
                        autoFocus: true,
                        scrollBottomInset: keyboardVisible
                            ? keyboardInset + 24
                            : 80,
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                        customStyles: quill.DefaultStyles(
                          paragraph: quill.DefaultTextBlockStyle(
                            const TextStyle(
                              color: Color(0xFF111827),
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
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _buildNotePayload() {
    final fallbackTitle =
        widget.initialNote?['title']?.toString().trim().isNotEmpty == true
        ? widget.initialNote!['title'].toString().trim()
        : 'Untitled note';
    final title = _titleController.text.trim().isEmpty
        ? fallbackTitle
        : _titleController.text.trim();
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

    return {
      'id': _noteId,
      'title': title,
      'preview': preview,
      'updated': 'Now',
      'pinned': widget.initialNote?['pinned'] ?? false,
      'tags': tags.isEmpty ? <String>['note'] : tags,
      'delta': jsonDecode(jsonEncode(deltaJson)),
    };
  }

  String _normalizedTitle() => _titleController.text.trim();

  String _normalizedPlainText() =>
      _quillController.document.toPlainText().trim();

  List<String> _normalizedTags() {
    final tags =
        _tags
            .map((entry) => entry.trim().toLowerCase())
            .where((entry) => entry.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return tags;
  }

  bool _isEmptyDraft() {
    final hasTitle = _normalizedTitle().isNotEmpty;
    final hasBody = _normalizedPlainText().isNotEmpty;
    return !hasTitle && !hasBody;
  }

  String _fingerprintForCurrentState() {
    final deltaJson = _quillController.document.toDelta().toJson();
    return jsonEncode({
      'title': _normalizedTitle(),
      'plainText': _normalizedPlainText(),
      'tags': _normalizedTags(),
      'delta': deltaJson,
    });
  }

  void _emitAutoSave() {
    final callback = widget.onAutoSave;
    if (callback == null) return;
    if (_isEmptyDraft()) return;
    final fingerprint = _fingerprintForCurrentState();
    if (fingerprint == _initialFingerprint) return;
    if (fingerprint == _lastAutoSavedFingerprint) return;
    _lastAutoSavedFingerprint = fingerprint;
    callback(_buildNotePayload());
  }

  void _saveAndPop() {
    if (widget.initialNote == null && _isEmptyDraft()) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    _emitAutoSave();
    if (!mounted) return;
    Navigator.of(context).pop(_buildNotePayload());
  }

  void _save() {
    _saveAndPop();
  }
}

class NoteViewScreen extends StatelessWidget {
  const NoteViewScreen({
    super.key,
    required this.note,
    this.showDeleteAction = false,
    this.onAutoSave,
  });

  final Map<String, dynamic> note;
  final bool showDeleteAction;
  final ValueChanged<Map<String, dynamic>>? onAutoSave;

  @override
  Widget build(BuildContext context) {
    final delta = note['delta'] as List<dynamic>?;
    final document = delta == null
        ? (quill.Document()
            ..insert(0, '${note['preview']?.toString() ?? ''}\n'))
        : quill.Document.fromJson(
            delta
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList(),
          );

    final controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(note['title']?.toString() ?? 'Note'),
        actions: [
          TextButton(
            onPressed: () async {
              final updated = await Navigator.of(context)
                  .push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) => NoteEditorScreen(
                        initialNote: note,
                        onAutoSave: onAutoSave,
                      ),
                    ),
                  );
              if (updated == null || !context.mounted) return;
              Navigator.of(context).pop(updated);
            },
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(AppStrings.edit),
          ),
          if (showDeleteAction)
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: IgnorePointer(
            child: quill.QuillEditor.basic(
              controller: controller,
              config: quill.QuillEditorConfig(
                customStyles: quill.DefaultStyles(
                  paragraph: quill.DefaultTextBlockStyle(
                    const TextStyle(
                      color: Color(0xFF111827),
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
