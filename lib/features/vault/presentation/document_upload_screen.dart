import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/config/vault_limits.dart';
import '../../../core/localization/app_strings.dart';
import '../../../domain/models/vault_folder.dart';
import 'widgets/vault_create_folder_dialog.dart';
import 'widgets/vault_page_heading.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({
    super.key,
    required this.currentVaultSizeBytes,
    required this.maxVaultBytes,
    this.maxDocumentBytes = VaultLimits.maxDocumentBytes,
    this.onLifecycleLockSuppressed,
    this.folders = const <VaultFolder>[],
    this.initialFolderId,
    this.onCreateFolder,
  });

  final int currentVaultSizeBytes;
  final int maxVaultBytes;
  final int maxDocumentBytes;
  final ValueChanged<bool>? onLifecycleLockSuppressed;
  final List<VaultFolder> folders;
  final String? initialFolderId;
  final VaultFolderCreateCallback? onCreateFolder;

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _titleController;
  late final TextEditingController _tagsController;
  late final TextEditingController _descriptionController;
  final List<PlatformFile> _selectedFiles = <PlatformFile>[];
  late String _selectedFolderId;
  late final List<VaultFolder> _customFolders;
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
    _customFolders = widget.folders.where((f) => f.id != 'default').toList();
    final initialFid = widget.initialFolderId?.trim();
    _selectedFolderId = (initialFid != null && initialFid.isNotEmpty) ? initialFid : 'default';
  }

  List<VaultFolder> get _effectiveFolders {
    return [
      VaultFolder(
        id: 'default',
        name: 'Default',
        icon: 'folder_special',
        createdAt: '',
        updatedAt: '',
      ),
      ..._customFolders,
    ];
  }

  List<DropdownMenuItem<String>> get _folderDropdownItems {
    final items = _effectiveFolders.map((folder) {
      return DropdownMenuItem<String>(
        value: folder.id,
        child: Text(
          folder.name,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList();

    if (!_effectiveFolders.any((f) => f.id == _selectedFolderId)) {
      items.add(
        DropdownMenuItem<String>(
          value: _selectedFolderId,
          child: Text(
            _selectedFolderId,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    items.add(
      DropdownMenuItem<String>(
        value: '__create_new_folder__',
        child: Row(
          children: [
            Icon(
              Icons.create_new_folder_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Create new folder...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );

    return items;
  }

  Future<void> _promptCreateFolder() async {
    final newFolder = await showCreateVaultFolderDialog(
      context,
      onCreateFolder: widget.onCreateFolder,
    );
    if (newFolder != null && mounted) {
      setState(() {
        if (!_customFolders.any((f) => f.id == newFolder.id)) {
          _customFolders.add(newFolder);
        }
        _selectedFolderId = newFolder.id;
      });
    }
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
      _selectedFiles.isNotEmpty &&
      _selectedFiles.every(
        (file) => file.readStream != null || file.bytes != null,
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.uploadDocument),
        leading: TextButton(
          onPressed: _uploading ? null : () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(AppStrings.cancel),
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
                                label: Text(
                                  _selectedFiles.isEmpty
                                      ? 'Choose documents'
                                      : 'Add more documents',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Maximum file size: ${VaultLimits.formatBytes(widget.maxDocumentBytes)} per document',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Vault space: ${VaultLimits.formatBytes(widget.currentVaultSizeBytes)} of ${VaultLimits.formatBytes(widget.maxVaultBytes)} used (cloud allocation · local storage is unlimited)',
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
                              if (_selectedFiles.isEmpty)
                                _EmptyDocumentPicker(colorScheme: colorScheme)
                              else
                                _SelectedDocumentsList(
                                  files: _selectedFiles,
                                  onRemove: _uploading
                                      ? null
                                      : (index) => setState(() {
                                          _selectedFiles.removeAt(index);
                                          _errorText = null;
                                        }),
                                ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _titleController,
                                enabled: !_uploading,
                                decoration: InputDecoration(
                                  hintText: AppStrings.titleLabel,
                                  prefixIcon: Icon(Icons.title),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _tagsController,
                                enabled: !_uploading,
                                decoration: InputDecoration(
                                  hintText: AppStrings.addTags,
                                  prefixIcon: Icon(Icons.sell_outlined),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: KeyedSubtree(
                                      key: const ValueKey('document-folder-selector'),
                                      child: DropdownButtonFormField<String>(
                                        key: ValueKey('document-folder-dropdown-$_selectedFolderId'),
                                        isExpanded: true,
                                        initialValue: _selectedFolderId,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.normal,
                                          color: colorScheme.onSurface,
                                        ),
                                        items: _folderDropdownItems,
                                        onChanged: _uploading
                                            ? null
                                            : (value) async {
                                                if (value == null) return;
                                                if (value == '__create_new_folder__') {
                                                  await _promptCreateFolder();
                                                  return;
                                                }
                                                if (value == _selectedFolderId) return;
                                                setState(() {
                                                  _selectedFolderId = value;
                                                });
                                              },
                                        decoration: InputDecoration(
                                          labelText: AppStrings.folderLabel,
                                          prefixIcon: Icon(
                                            _selectedFolderId == 'default'
                                                ? Icons.folder_special
                                                : Icons.folder,
                                            size: 20,
                                            color: _selectedFolderId == 'default'
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFFEAB308),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.outlined(
                                    key: const ValueKey('document-create-folder-button'),
                                    tooltip: AppStrings.createNewFolder,
                                    icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                                    onPressed: _uploading ? null : _promptCreateFolder,
                                  ),
                                ],
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
                            decoration: InputDecoration(
                              hintText: AppStrings.descriptionOptional,
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
                      label: Text(
                        _selectedFiles.length > 1
                            ? 'Upload ${_selectedFiles.length} documents'
                            : 'Upload document',
                      ),
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
        allowMultiple: true,
        withData: false,
        withReadStream: true,
      );
    } finally {
      widget.onLifecycleLockSuppressed?.call(false);
    }
    final files = result?.files ?? const <PlatformFile>[];
    if (files.isEmpty) return;
    for (final file in files) {
      if (file.size > widget.maxDocumentBytes) {
        setState(() {
          _errorText =
              '${file.name} must be ${_formatBytes(widget.maxDocumentBytes)} or smaller.';
        });
        return;
      }
      if (file.readStream == null && file.bytes == null) {
        setState(() {
          _errorText = 'Could not read ${file.name}.';
        });
        return;
      }
    }
    final selectedBytes = _selectedFiles.fold<int>(
      0,
      (sum, file) => sum + file.size,
    );
    final addedBytes = files.fold<int>(0, (sum, file) => sum + file.size);
    if (widget.currentVaultSizeBytes + selectedBytes + addedBytes >
        widget.maxVaultBytes) {
      setState(() {
        _errorText =
            'Not enough vault space. Limit is ${_formatBytes(widget.maxVaultBytes)}.';
      });
      return;
    }
    setState(() {
      _selectedFiles.addAll(files);
      _errorText = null;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = _fileNameWithoutExtension(files.first.name);
      }
    });
  }

  Future<void> _uploadDocument() async {
    if (_selectedFiles.isEmpty) return;
    final oversized = _selectedFiles
        .where((file) => file.size > widget.maxDocumentBytes)
        .toList();
    final selectedBytes = _selectedFiles.fold<int>(
      0,
      (sum, file) => sum + file.size,
    );
    if (oversized.isNotEmpty ||
        widget.currentVaultSizeBytes + selectedBytes > widget.maxVaultBytes) {
      setState(() {
        _errorText = oversized.isNotEmpty
            ? '${oversized.first.name} must be ${_formatBytes(widget.maxDocumentBytes)} or smaller.'
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

    final uploadedAt = DateTime.now().toUtc().toIso8601String();
    final description = _descriptionController.text.trim();
    final customTitle = _titleController.text.trim();
    final tags = _tagsController.text
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();

    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    setState(() => _progress = 0.78);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final documentsList = <Map<String, dynamic>>[];

    for (var i = 0; i < _selectedFiles.length; i++) {
      final file = _selectedFiles[i];
      final extension = _extensionFor(file);
      final title = (i == 0 && customTitle.isNotEmpty)
          ? customTitle
          : _fileNameWithoutExtension(file.name);
      final fields = <Map<String, dynamic>>[
        {'label': 'File name', 'value': file.name, 'sensitive': false},
        {'label': 'Extension', 'value': extension, 'sensitive': false},
        {'label': 'Size', 'value': _formatBytes(file.size), 'sensitive': false},
        if (description.isNotEmpty)
          {'label': 'Description', 'value': description, 'sensitive': false},
      ];

      documentsList.add(<String, dynamic>{
        'id': '${nowMs}_$i',
        'type': 'Documents',
        'title': title,
        'subtitle': description,
        'updated': 'Now',
        'pinned': false,
        'tags': tags,
        'fields': fields,
        'folderId': _selectedFolderId,
        if (file.readStream != null) '__documentReadStream__': file.readStream,
        if (file.bytes != null) '__documentBytes__': file.bytes,
        'documentExtension': extension,
        'documentSizeBytes': file.size,
        'documentFileName': file.name,
        'documentUploadedAt': uploadedAt,
        'documentStorage': 'pending',
      });
    }

    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    setState(() => _progress = 1);

    final primaryItem = Map<String, dynamic>.from(documentsList.first);
    if (documentsList.length > 1) {
      primaryItem['documents'] = documentsList;
    }
    Navigator.of(context).pop(primaryItem);
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
        'No documents selected',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SelectedDocumentsList extends StatelessWidget {
  const _SelectedDocumentsList({required this.files, required this.onRemove});

  final List<PlatformFile> files;
  final ValueChanged<int>? onRemove;

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
      child: Column(
        children: List.generate(files.length, (index) {
          final file = files[index];
          return Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
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
              title: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${_extensionFor(file)} · ${_formatBytes(file.size)}',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              trailing: IconButton(
                key: ValueKey('document-upload-remove-$index'),
                onPressed: onRemove == null ? null : () => onRemove!(index),
                icon: const Icon(Icons.close),
                tooltip: AppStrings.removeDocument,
              ),
            ),
          );
        }),
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

String _formatBytes(int bytes) => VaultLimits.formatBytes(bytes);
