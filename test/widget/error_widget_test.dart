import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/shared/widgets/error_widget.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AppErrorWidget', () {
    testWidgets('varsayılan mesaj gösterilir', (tester) async {
      await tester.pumpWidget(_wrap(const AppErrorWidget()));
      expect(find.textContaining('hata oluştu'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('özel mesaj gösterilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppErrorWidget(message: 'Sunucu bağlantısı kesildi')),
      );
      expect(find.text('Sunucu bağlantısı kesildi'), findsOneWidget);
    });

    testWidgets('onRetry null → retry butonu yok', (tester) async {
      await tester.pumpWidget(_wrap(const AppErrorWidget()));
      expect(find.text('Tekrar Dene'), findsNothing);
    });

    testWidgets('onRetry verilince retry butonu görünür', (tester) async {
      await tester.pumpWidget(
        _wrap(AppErrorWidget(onRetry: () {})),
      );
      expect(find.text('Tekrar Dene'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('retry butonuna tıklayınca callback tetiklenir', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        _wrap(AppErrorWidget(onRetry: () => retried = true)),
      );
      await tester.tap(find.text('Tekrar Dene'));
      expect(retried, isTrue);
    });
  });
}
