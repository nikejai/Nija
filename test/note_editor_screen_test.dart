import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:nija/features/vault/presentation/note_editor_screen.dart';

void main() {
  Widget testApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: child,
    );
  }

  testWidgets('note editor keeps title/tags collapsed by default', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(const NoteEditorScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Untitled note'), findsOneWidget);

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('note editor autosaves every second through callback', (
    tester,
  ) async {
    Map<String, dynamic>? latest;
    await tester.pumpWidget(
      testApp(
        NoteEditorScreen(
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

    await tester.enterText(find.byType(TextField), 'Updated Draft');
    await tester.pump(const Duration(milliseconds: 1200));
    expect(latest, isNotNull);
    expect(latest!['title'], 'Updated Draft');
  });

  testWidgets('note editor delays autosave while edits are still active', (
    tester,
  ) async {
    var saveCount = 0;
    await tester.pumpWidget(
      testApp(
        NoteEditorScreen(
          initialNote: const {
            'id': 'note-1',
            'title': 'Draft',
            'preview': 'x',
            'tags': ['note'],
            'delta': [
              {'insert': 'hello\n'},
            ],
          },
          onAutoSave: (_) => saveCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.enterText(find.byType(TextField), 'AB');
    await tester.pump(const Duration(milliseconds: 700));
    expect(saveCount, 0);

    await tester.pump(const Duration(milliseconds: 400));
    expect(saveCount, 1);
  });
}
