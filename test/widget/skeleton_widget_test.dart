import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/shared/widgets/skeleton_widget.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SkeletonListTile', () {
    testWidgets('leading circle olmadan render edilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const SkeletonListTile()),
      );
      await tester.pump();
      expect(find.byType(SkeletonListTile), findsOneWidget);
    });

    testWidgets('leading circle ile render edilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const SkeletonListTile(hasLeadingCircle: true)),
      );
      await tester.pump();
      expect(find.byType(SkeletonListTile), findsOneWidget);
    });

    testWidgets('trailing ile render edilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const SkeletonListTile(hasTrailing: true)),
      );
      await tester.pump();
      expect(find.byType(SkeletonListTile), findsOneWidget);
    });

    testWidgets('animasyon birden fazla frame sonra da çalışır', (tester) async {
      await tester.pumpWidget(
        _wrap(const SkeletonListTile(hasLeadingCircle: true, hasTrailing: true)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(SkeletonListTile), findsOneWidget);
    });

    testWidgets('dispose sonrası hata yok', (tester) async {
      await tester.pumpWidget(
        _wrap(const SkeletonListTile()),
      );
      await tester.pump(const Duration(milliseconds: 400));
      // Widget ağacından kaldırılınca dispose çalışmalı
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      expect(tester.takeException(), isNull);
    });
  });

  group('SkeletonList', () {
    testWidgets('varsayılan 7 tile render edilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const SkeletonList()),
      );
      await tester.pump();
      expect(find.byType(SkeletonListTile), findsNWidgets(7));
    });

    testWidgets('özel itemCount kadar tile render edilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const SkeletonList(itemCount: 3)),
      );
      await tester.pump();
      expect(find.byType(SkeletonListTile), findsNWidgets(3));
    });

    testWidgets('hasLeadingCircle parametresi tile\'lara aktarılır', (tester) async {
      await tester.pumpWidget(
        _wrap(const SkeletonList(itemCount: 2, hasLeadingCircle: true)),
      );
      await tester.pump();
      final tiles = tester.widgetList<SkeletonListTile>(find.byType(SkeletonListTile));
      expect(tiles.every((t) => t.hasLeadingCircle), isTrue);
    });

    testWidgets('hasTrailing parametresi tile\'lara aktarılır', (tester) async {
      await tester.pumpWidget(
        _wrap(const SkeletonList(itemCount: 2, hasTrailing: true)),
      );
      await tester.pump();
      final tiles = tester.widgetList<SkeletonListTile>(find.byType(SkeletonListTile));
      expect(tiles.every((t) => t.hasTrailing), isTrue);
    });
  });
}
