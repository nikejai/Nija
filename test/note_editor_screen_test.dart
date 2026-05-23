import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nija/features/vault/presentation/note_editor_screen.dart';

void main() {
  testWidgets('note editor keeps title/tags collapsed by default', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: NoteEditorScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Document title'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('toggle-note-details')));
    await tester.pumpAndSettle();

    expect(find.text('Document title'), findsOneWidget);
  });

  testWidgets('note editor autosaves every second through callback', (
    tester,
  ) async {
    Map<String, dynamic>? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditorScreen(
          initialNote: const {
            'id': 'note-1',
            'title': 'Draft',
            'preview': 'x',
            'tags': ['note'],
            'delta': [
              {'insert': 'hello\n'},
            ],
          },
          onAutoSave: (note) => latest = note,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 1200));
    expect(latest, isNotNull);
    expect(latest!['title'], 'Draft');
  });
}
