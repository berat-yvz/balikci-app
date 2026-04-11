import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/shared/widgets/loading_widget.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('LoadingWidget', () {
    testWidgets('CircularProgressIndicator gösterilir', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingWidget()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('mesaj verilince Text gösterilir', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingWidget(message: 'Yükleniyor...')));
      expect(find.text('Yükleniyor...'), findsOneWidget);
    });

    testWidgets('mesaj null ise Text gösterilmez', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingWidget()));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('widget ortalanmış (Center içinde)', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingWidget(message: 'Test')));
      expect(find.byType(Center), findsWidgets);
    });
  });
}
