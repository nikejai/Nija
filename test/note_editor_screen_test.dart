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

  testWidgets('note editor displays title in top header with edit button', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(const NoteEditorScreen()));
    await tester.pumpAndSettle();

    expect(find.text('New note'), findsOneWidget);
    expect(find.byKey(const ValueKey('note-title-header-button')), findsOneWidget);
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

    await tester.enterText(find.byKey(const ValueKey('note-details-title-input')), 'Updated Draft');
    await tester.pump(const Duration(milliseconds: 1200));
    expect(latest, isNotNull);
    expect(latest!['title'], 'Updated Draft');
  });

  testWidgets('note editor delays autosave while edits are still active', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    await tester.enterText(find.byKey(const ValueKey('note-details-title-input')), 'A');
    await tester.pump(const Duration(milliseconds: 700));

    await tester.enterText(find.byKey(const ValueKey('note-details-title-input')), 'AB');
    await tester.pump(const Duration(milliseconds: 700));
    expect(saveCount, 0);

    await tester.pump(const Duration(milliseconds: 400));
    expect(saveCount, 1);
  });
}
