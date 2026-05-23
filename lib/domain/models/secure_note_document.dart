class SecureNoteDocument {
  const SecureNoteDocument({
    required this.id,
    required this.title,
    required this.blocks,
  });

  final String id;
  final String title;
  final List<NoteBlock> blocks;
}

class NoteBlock {
  const NoteBlock({
    required this.type,
    required this.text,
    this.checked,
  });

  final String type;
  final String text;
  final bool? checked;
}
