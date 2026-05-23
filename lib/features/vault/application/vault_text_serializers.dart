class VaultTextSerializers {
  VaultTextSerializers._();

  static String itemPlainText(Map<String, dynamic> item) {
    final buffer = StringBuffer();
    buffer.writeln(item['title']?.toString() ?? 'Untitled');
    buffer.writeln('Type: ${item['type']?.toString() ?? 'Item'}');
    final fields = (item['fields'] as List<dynamic>? ?? const <dynamic>[])
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    for (final field in fields) {
      final label = field['label']?.toString() ?? 'Field';
      final value = field['value']?.toString() ?? '';
      if (value.trim().isEmpty) continue;
      buffer.writeln('$label: $value');
    }
    return buffer.toString().trim();
  }

  static String notePlainText(Map<String, dynamic> note) {
    final buffer = StringBuffer();
    buffer.writeln(note['title']?.toString() ?? 'Untitled note');
    final fullText = noteBodyShareText(note);
    if (fullText.isNotEmpty) {
      buffer.writeln(fullText);
    }
    return buffer.toString().trim();
  }

  static String noteBodyShareText(Map<String, dynamic> note) {
    final delta = note['delta'];
    if (delta is List) {
      try {
        final lines = <String>[];
        final currentLine = StringBuffer();
        final segmentAttrs = <Map<String, dynamic>>[];
        var orderedIndex = 0;

        String applyInlineAttrs(String text, Map<String, dynamic> attrs) {
          var out = text;
          if (attrs['code'] == true) out = '`$out`';
          if (attrs['bold'] == true) out = '**$out**';
          if (attrs['italic'] == true) out = '_${out}_';
          if (attrs['strike'] == true) out = '~~$out~~';
          return out;
        }

        String applyBlockAttrs(String content, Map<String, dynamic> attrs) {
          final listType = attrs['list']?.toString();
          if (listType == 'ordered') {
            orderedIndex += 1;
            return '$orderedIndex. $content';
          }
          if (listType == 'bullet') {
            orderedIndex = 0;
            return '• $content';
          }
          if (listType == 'checked') {
            orderedIndex = 0;
            return '[x] $content';
          }
          if (listType == 'unchecked') {
            orderedIndex = 0;
            return '[ ] $content';
          }
          orderedIndex = 0;
          if (attrs['header'] == 1) return '# $content';
          if (attrs['header'] == 2) return '## $content';
          if (attrs['header'] == 3) return '### $content';
          if (attrs['blockquote'] == true) return '> $content';
          if (attrs['code-block'] == true) return '```$content```';
          return content;
        }

        for (final raw in delta) {
          final op = Map<String, dynamic>.from(raw as Map);
          final insert = op['insert'];
          if (insert is! String) continue;
          final attrs = Map<String, dynamic>.from(
            (op['attributes'] as Map?) ?? const <String, dynamic>{},
          );

          final parts = insert.split('\n');
          for (var i = 0; i < parts.length; i++) {
            final segment = parts[i];
            final isLineBreak = i < parts.length - 1;
            if (segment.isNotEmpty) {
              currentLine.write(applyInlineAttrs(segment, attrs));
              segmentAttrs.add(attrs);
            }
            if (!isLineBreak) continue;

            final content = currentLine.toString().trim();
            final baseAttrs = segmentAttrs.isNotEmpty
                ? Map<String, dynamic>.from(segmentAttrs.last)
                : <String, dynamic>{};
            final lineAttrs = <String, dynamic>{...baseAttrs, ...attrs};
            if (content.isNotEmpty) {
              lines.add(applyBlockAttrs(content, lineAttrs));
            } else {
              orderedIndex = 0;
            }
            currentLine.clear();
            segmentAttrs.clear();
          }
        }

        final trailing = currentLine.toString().trim();
        if (trailing.isNotEmpty) {
          final trailingAttrs = segmentAttrs.isNotEmpty
              ? segmentAttrs.last
              : const <String, dynamic>{};
          lines.add(applyBlockAttrs(trailing, trailingAttrs));
        }

        if (lines.isNotEmpty) {
          return lines.join('\n').trim();
        }
      } catch (_) {
        // Fallback handled below.
      }
    }
    return note['preview']?.toString().trim() ?? '';
  }
}
