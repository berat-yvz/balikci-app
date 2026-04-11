import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/shared/widgets/empty_state_widget.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('EmptyStateWidget — genel constructor', () {
    testWidgets('başlık ve altyazı görünür', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyStateWidget(
          title: 'Test Başlığı',
          subtitle: 'Test altyazısı',
        )),
      );
      await tester.pump();
      expect(find.text('Test Başlığı'), findsOneWidget);
      expect(find.text('Test altyazısı'), findsOneWidget);
    });

    testWidgets('buttonLabel verilince buton görünür', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyStateWidget(
          title: 'Başlık',
          subtitle: 'Alt',
          buttonLabel: 'Tıkla',
        )),
      );
      await tester.pump();
      expect(find.text('Tıkla'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('buttonLabel yokken ipucu gösterilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyStateWidget(
          title: 'Başlık',
          subtitle: 'Alt',
        )),
      );
      await tester.pump();
      expect(find.textContaining('yenile'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('buton callback tetiklenir', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(EmptyStateWidget(
          title: 'T',
          subtitle: 'S',
          buttonLabel: 'Ekle',
          onButtonPressed: () => tapped = true,
        )),
      );
      await tester.pump();
      await tester.tap(find.text('Ekle'));
      expect(tapped, isTrue);
    });
  });

  group('EmptyStateWidget.noFishLogs', () {
    testWidgets('doğru başlık gösterilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyStateWidget.noFishLogs()),
      );
      await tester.pump();
      expect(find.text('İlk avını kaydet'), findsOneWidget);
    });

    testWidgets('buttonLabel ile buton görünür', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyStateWidget.noFishLogs(
          buttonLabel: 'Kayıt Ekle',
        )),
      );
      await tester.pump();
      expect(find.text('Kayıt Ekle'), findsOneWidget);
    });

    testWidgets('balık emoji gösterilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyStateWidget.noFishLogs()),
      );
      await tester.pump();
      expect(find.text('🎣'), findsOneWidget);
    });
  });

  group('EmptyStateWidget.mapNoSpots', () {
    testWidgets('doğru başlık gösterilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyStateWidget.mapNoSpots()),
      );
      await tester.pump();
      expect(find.text('Henüz mera yok'), findsOneWidget);
    });

    testWidgets('mera emoji gösterilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyStateWidget.mapNoSpots()),
      );
      await tester.pump();
      expect(find.text('🐟'), findsOneWidget);
    });
  });

  group('EmptyStateWidget.noNotifications', () {
    testWidgets('doğru başlık gösterilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyStateWidget.noNotifications()),
      );
      await tester.pump();
      expect(find.text('Henüz bildirim yok'), findsOneWidget);
    });

    testWidgets('bildirim emoji gösterilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyStateWidget.noNotifications()),
      );
      await tester.pump();
      expect(find.text('🔔'), findsOneWidget);
    });
  });
}
