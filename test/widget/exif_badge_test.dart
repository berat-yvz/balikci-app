import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/shared/widgets/exif_badge.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('ExifBadge', () {
    testWidgets('null → bekliyor mesajı gösterilir', (tester) async {
      await tester.pumpWidget(_wrap(const ExifBadge(exifVerified: null)));
      expect(find.textContaining('doğrulanıyor'), findsOneWidget);
      expect(find.text('⏳'), findsOneWidget);
    });

    testWidgets('true → doğrulandı mesajı gösterilir', (tester) async {
      await tester.pumpWidget(_wrap(const ExifBadge(exifVerified: true)));
      expect(find.textContaining('doğrulandı'), findsOneWidget);
      expect(find.text('✅'), findsOneWidget);
    });

    testWidgets('false → eşleşmedi mesajı gösterilir', (tester) async {
      await tester.pumpWidget(_wrap(const ExifBadge(exifVerified: false)));
      expect(find.textContaining('eşleşmedi'), findsOneWidget);
      expect(find.text('❌'), findsOneWidget);
    });

    testWidgets('true → bonus puan mesajı içerir', (tester) async {
      await tester.pumpWidget(_wrap(const ExifBadge(exifVerified: true)));
      expect(find.textContaining('bonus puan'), findsOneWidget);
    });
  });
}
