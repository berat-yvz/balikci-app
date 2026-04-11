import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/shared/widgets/rank_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('RankBadge — rütbe metinleri', () {
    testWidgets('acemi rütbesi "Acemi" gösterir', (tester) async {
      await tester.pumpWidget(_wrap(const RankBadge(rank: 'acemi')));
      await tester.pump();
      expect(find.text('Acemi'), findsOneWidget);
      expect(find.text('🪝'), findsOneWidget);
    });

    testWidgets('olta_kurdu rütbesi "Olta Kurdu" gösterir', (tester) async {
      await tester.pumpWidget(_wrap(const RankBadge(rank: 'olta_kurdu')));
      await tester.pump();
      expect(find.text('Olta Kurdu'), findsOneWidget);
      expect(find.text('🎣'), findsOneWidget);
    });

    testWidgets('usta rütbesi "Usta" gösterir', (tester) async {
      await tester.pumpWidget(_wrap(const RankBadge(rank: 'usta')));
      await tester.pump();
      expect(find.text('Usta'), findsOneWidget);
      expect(find.text('⚓'), findsOneWidget);
    });

    testWidgets('deniz_reisi rütbesi "Deniz Reisi" gösterir', (tester) async {
      await tester.pumpWidget(_wrap(const RankBadge(rank: 'deniz_reisi')));
      await tester.pump();
      expect(find.text('Deniz Reisi'), findsOneWidget);
      expect(find.text('👑'), findsOneWidget);
    });

    testWidgets('bilinmeyen rütbe → Deniz Reisi gösterilir (default)', (tester) async {
      await tester.pumpWidget(_wrap(const RankBadge(rank: 'bilinmeyen')));
      await tester.pump();
      expect(find.text('Deniz Reisi'), findsOneWidget);
    });
  });

  group('RankBadge — boyut', () {
    testWidgets('small boyut render edilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const RankBadge(rank: 'usta', size: RankBadgeSize.small)),
      );
      await tester.pump();
      expect(find.text('Usta'), findsOneWidget);
    });

    testWidgets('medium boyut render edilir (varsayılan)', (tester) async {
      await tester.pumpWidget(
        _wrap(const RankBadge(rank: 'usta')),
      );
      await tester.pump();
      expect(find.text('Usta'), findsOneWidget);
    });

    testWidgets('large boyut render edilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const RankBadge(rank: 'usta', size: RankBadgeSize.large)),
      );
      await tester.pump();
      expect(find.text('Usta'), findsOneWidget);
    });
  });

  group('RankBadge — deniz_reisi animasyonu', () {
    testWidgets('deniz_reisi — birden fazla frame sonra da düzgün render', (tester) async {
      await tester.pumpWidget(_wrap(const RankBadge(rank: 'deniz_reisi')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Deniz Reisi'), findsOneWidget);
    });
  });
}
