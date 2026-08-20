import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nija/features/vault/presentation/vault_app_shell.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'PDF attachment preview keeps parent page from stealing gestures',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VaultAppShell(
            recoveryWords: const [
              'anchor',
              'apple',
              'arrow',
              'atlas',
              'beacon',
              'breeze',
              'canyon',
              'cedar',
              'cobalt',
              'ember',
              'harbor',
              'willow',
            ],
            initialItems: const [
              {
                'id': 'item-pdf',
                'type': 'Login',
                'title': 'PDF Preview Item',
                'subtitle': 'pdf@example.com',
                'updated': 'Now',
                'fields': [
                  {'label': 'username', 'value': 'pdf@example.com'},
                  {'label': 'password', 'value': 'StrongPass123'},
                  {
                    'label': 'notes',
                    'value': 'Enough fields to make page scroll',
                  },
                ],
                'attachments': [
                  {
                    'id': 'attachment-pdf',
                    'documentFileName': 'sample.pdf',
                    'documentExtension': 'pdf',
                    'documentSizeBytes': 512,
                    'documentSection': 'document_attachment_pdf.manifest.enc',
                    'documentStorage': 'private-section',
                  },
                ],
              },
            ],
            initialNotes: const [],
            initialCustomTypeDefinitions: const [],
            languageMode: 'en',
            onLanguageModeChanged: (_) {},
            biometricEnabled: false,
            onBiometricChanged: (_) {},
            onPersistVaultData:
                ({
                  required items,
                  required notes,
                  required customTypeDefinitions,
                }) async {},
            onRotateMasterPassword:
                ({required currentPassword, required newPassword}) async {},
            onRotateRecoveryPhrase:
                ({
                  required currentRecoveryPhrase,
                  required newRecoveryPhrase,
                }) async {},
            onExportVault: () async {},
            onImportVault: () async {},
            onBackupToCloud: () async {},
            onRestoreFromCloud: () async {},
            onReadCloudBackupAccount: () async => null,
            onChangeCloudBackupAccount: () async => false,
            onLockNow: () {},
            onReadVaultDocument: ({required sectionName, onProgress}) async =>
                _samplePdfBytes(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('All items'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PDF Preview Item'));
      await tester.pumpAndSettle();

      final preview = find.byKey(const ValueKey('attachment-preview-panel'));
      expect(preview, findsOneWidget);
      expect(
        tester
            .widget<ListView>(
              find.byKey(const ValueKey('item-detail-scroll-view')),
            )
            .physics,
        isNot(isA<NeverScrollableScrollPhysics>()),
      );

      final gesture = await tester.startGesture(tester.getCenter(preview));
      await tester.pump();
      expect(
        tester
            .widget<ListView>(
              find.byKey(const ValueKey('item-detail-scroll-view')),
            )
            .physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      await gesture.moveBy(const Offset(-90, -140));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(
        tester
            .widget<ListView>(
              find.byKey(const ValueKey('item-detail-scroll-view')),
            )
            .physics,
        isNot(isA<NeverScrollableScrollPhysics>()),
      );
    },
  );
}

List<int> _samplePdfBytes() {
  final objects = <String>[
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
    '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
    '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] /Contents 4 0 R >>\nendobj\n',
    '4 0 obj\n<< /Length 44 >>\nstream\nBT /F1 18 Tf 40 150 Td (Nija PDF Preview) Tj ET\nendstream\nendobj\n',
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (final object in objects) {
    offsets.add(utf8.encode(buffer.toString()).length);
    buffer.write(object);
  }
  final xrefOffset = utf8.encode(buffer.toString()).length;
  buffer
    ..write('xref\n')
    ..write('0 ${objects.length + 1}\n')
    ..write('0000000000 65535 f \n');
  for (final offset in offsets) {
    buffer
      ..write(offset.toString().padLeft(10, '0'))
      ..write(' 00000 n \n');
  }
  buffer
    ..write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n')
    ..write('startxref\n')
    ..write('$xrefOffset\n')
    ..write('%%EOF\n');
  return utf8.encode(buffer.toString());
}
