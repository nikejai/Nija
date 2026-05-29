import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/config/vault_limits.dart';
import 'widgets/vault_page_heading.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({
    super.key,
    required this.currentVaultSizeBytes,
    required this.maxVaultBytes,
    this.maxDocumentBytes = VaultLimits.maxDocumentBytes,
    this.onLifecycleLockSuppressed,
  });

  final int currentVaultSizeBytes;
  final int maxVaultBytes;
  final int maxDocumentBytes;
  final ValueChanged<bool>? onLifecycleLockSuppressed;

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _titleController;
  late final TextEditingController _tagsController;
  late final TextEditingController _descriptionController;
  PlatformFile? _selectedFile;
  String? _errorText;
  bool _uploading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _titleController = TextEditingController();
    _tagsController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    widget.onLifecycleLockSuppressed?.call(false);
    _tabController.dispose();
    _titleController.dispose();
    _tagsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canUpload =>
      !_uploading &&
      _selectedFile != null &&
      (_selectedFile!.readStream != null || _selectedFile!.bytes != null);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final file = _selectedFile;
    final extension = _extensionFor(file);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Document'),
        leading: TextButton(
          onPressed: _uploading ? null : () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Cancel'),
        ),
        leadingWidth: 86,
      ),
      body: SafeArea(
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'File'),
                Tab(text: 'Description'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFFB7185,
                                      ).withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: const Icon(
                                      Icons.folder_outlined,
                                      color: Color(0xFFFB7185),
                                      size: 21,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Documents',
                                      style: vaultPageHeadingStyle(context),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _uploading ? null : _pickFile,
                                icon: const Icon(Icons.attach_file),
                                label: const Text('Choose document'),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Maximum file size: ${_formatBytes(widget.maxDocumentBytes)}',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Vault space: ${_formatBytes(widget.currentVaultSizeBytes)} of ${_formatBytes(widget.maxVaultBytes)} used',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              if (_errorText != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _errorText!,
                                  style: TextStyle(
                                    color: colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              if (file == null)
                                _EmptyDocumentPicker(colorScheme: colorScheme)
                              else
                                _SelectedDocumentSummary(
                                  name: file.name,
                                  extension: extension,
                                  size: _formatBytes(file.size),
                                ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _titleController,
                                enabled: !_uploading,
                                decoration: const InputDecoration(
                                  hintText: 'Title',
                                  prefixIcon: Icon(Icons.title),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _tagsController,
                                enabled: !_uploading,
                                decoration: const InputDecoration(
                                  hintText: 'Add tags',
                                  prefixIcon: Icon(Icons.sell_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          child: TextField(
                            controller: _descriptionController,
                            enabled: !_uploading,
                            minLines: 7,
                            maxLines: 12,
                            decoration: const InputDecoration(
                              hintText: 'Description (optional)',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_uploading) ...[
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 8),
                    Text(
                      'Encrypting and saving document...',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _canUpload ? _uploadDocument : null,
                      icon: const Icon(Icons.enhanced_encryption_outlined),
                      label: const Text('Upload document'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    widget.onLifecycleLockSuppressed?.call(true);
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
        withReadStream: true,
      );
    } finally {
      widget.onLifecycleLockSuppressed?.call(false);
    }
    final file = result?.files.single;
    if (file == null) return;
    if (file.size > widget.maxDocumentBytes) {
      setState(() {
        _selectedFile = null;
        _errorText =
            'Document must be ${_formatBytes(widget.maxDocumentBytes)} or smaller.';
      });
      return;
    }
    if (widget.currentVaultSizeBytes + file.size > widget.maxVaultBytes) {
      setState(() {
        _selectedFile = null;
        _errorText =
            'Not enough vault space. Limit is ${_formatBytes(widget.maxVaultBytes)}.';
      });
      return;
    }
    if (file.readStream == null && file.bytes == null) {
      setState(() {
        _selectedFile = null;
        _errorText = 'Could not read the selected document.';
      });
      return;
    }
    setState(() {
      _selectedFile = file;
      _errorText = null;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = _fileNameWithoutExtension(file.name);
      }
    });
  }

  Future<void> _uploadDocument() async {
    final file = _selectedFile;
    if (file == null) return;
    if (file.size > widget.maxDocumentBytes ||
        widget.currentVaultSizeBytes + file.size > widget.maxVaultBytes) {
      setState(() {
        _errorText = file.size > widget.maxDocumentBytes
            ? 'Document must be ${_formatBytes(widget.maxDocumentBytes)} or smaller.'
            : 'Not enough vault space. Limit is ${_formatBytes(widget.maxVaultBytes)}.';
      });
      return;
    }
    setState(() {
      _uploading = true;
      _progress = 0.12;
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() => _progress = 0.45);

    final extension = _extensionFor(file);
    final description = _descriptionController.text.trim();
    final title = _titleController.text.trim().isEmpty
        ? _fileNameWithoutExtension(file.name)
        : _titleController.text.trim();
    final uploadedAt = DateTime.now().toUtc().toIso8601String();
    final tags = _tagsController.text
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();

    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    setState(() => _progress = 0.78);

    final fields = <Map<String, dynamic>>[
      {'label': 'File name', 'value': file.name, 'sensitive': false},
      {'label': 'Extension', 'value': extension, 'sensitive': false},
      {'label': 'Size', 'value': _formatBytes(file.size), 'sensitive': false},
      if (description.isNotEmpty)
        {'label': 'Description', 'value': description, 'sensitive': false},
    ];

    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    setState(() => _progress = 1);
    Navigator.of(context).pop(<String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'Documents',
      'title': title,
      'subtitle': description,
      'updated': 'Now',
      'pinned': false,
      'tags': tags,
      'fields': fields,
      if (file.readStream != null) '__documentReadStream__': file.readStream,
      if (file.bytes != null) '__documentBytes__': file.bytes,
      'documentExtension': extension,
      'documentSizeBytes': file.size,
      'documentFileName': file.name,
      'documentUploadedAt': uploadedAt,
      'documentStorage': 'pending',
    });
  }
}

class _EmptyDocumentPicker extends StatelessWidget {
  const _EmptyDocumentPicker({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        'No document selected',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SelectedDocumentSummary extends StatelessWidget {
  const _SelectedDocumentSummary({
    required this.name,
    required this.extension,
    required this.size,
  });

  final String name;
  final String extension;
  final String size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFB7185).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.insert_drive_file_outlined,
              color: Color(0xFFFB7185),
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$extension · $size',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _extensionFor(PlatformFile? file) {
  final extension = file?.extension?.trim();
  if (extension != null && extension.isNotEmpty) {
    return extension.toUpperCase();
  }
  final name = file?.name ?? '';
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) return 'FILE';
  return name.substring(dot + 1).toUpperCase();
}

String _fileNameWithoutExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  return name.substring(0, dot);
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}
