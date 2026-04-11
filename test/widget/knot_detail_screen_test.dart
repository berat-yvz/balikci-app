import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balikci_app/data/models/knot_model.dart';
import 'package:balikci_app/features/knots/knot_detail_screen.dart';

/// Test için örnek KnotModel.
KnotModel _makeKnot({
  String id = 'knot_test',
  String title = 'Test Düğümü',
  String category = 'kanca',
  int difficulty = 3,
  List<String> useCases = const ['Levrek', 'Çipura'],
  List<String> steps = const ['Adım 1: ip al', 'Adım 2: düğüm at', 'Adım 3: sık'],
}) {
  return KnotModel(
    id: id,
    title: title,
    category: category,
    difficulty: difficulty,
    useCases: useCases,
    steps: steps,
  );
}

/// Test sarmalayıcı — MaterialApp + Türkçe locale.
Widget _wrap(Widget child) {
  return MaterialApp(
    home: child,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('KnotDetailScreen — temel içerik', () {
    testWidgets('düğüm başlığı AppBar\'da görünür', (tester) async {
      await tester.pumpWidget(_wrap(KnotDetailScreen(knot: _makeKnot())));
      await tester.pump();
      expect(find.text('Test Düğümü'), findsWidgets);
    });

    testWidgets('kategori etiketi görünür', (tester) async {
      await tester.pumpWidget(_wrap(KnotDetailScreen(knot: _makeKnot())));
      await tester.pump();
      expect(find.text('kanca'), findsOneWidget);
    });

    testWidgets('kullanım alanı chip\'leri görünür', (tester) async {
      await tester.pumpWidget(_wrap(KnotDetailScreen(knot: _makeKnot())));
      await tester.pump();
      expect(find.text('Levrek'), findsOneWidget);
      expect(find.text('Çipura'), findsOneWidget);
    });

    testWidgets('Adımlar başlığı görünür', (tester) async {
      await tester.pumpWidget(_wrap(KnotDetailScreen(knot: _makeKnot())));
      await tester.pump();
      expect(find.text('Adımlar'), findsOneWidget);
    });

    testWidgets('adım metinleri sırayla listelenir', (tester) async {
      await tester.pumpWidget(_wrap(KnotDetailScreen(knot: _makeKnot())));
      await tester.pump();
      expect(find.text('Adım 1: ip al'), findsOneWidget);
      expect(find.text('Adım 2: düğüm at'), findsOneWidget);
      expect(find.text('Adım 3: sık'), findsOneWidget);
    });

    testWidgets('zorluk yıldızları doğru sayıda dolu gösterilir', (tester) async {
      // difficulty=3 → 3 dolu, 2 boş yıldız
      await tester.pumpWidget(
        _wrap(KnotDetailScreen(knot: _makeKnot(difficulty: 3))),
      );
      await tester.pump();
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    });

    testWidgets('difficulty clamp: 0 → 1 yıldız dolu', (tester) async {
      await tester.pumpWidget(
        _wrap(KnotDetailScreen(knot: _makeKnot(difficulty: 0))),
      );
      await tester.pump();
      // clamp(1,5) → en az 1 dolu yıldız
      expect(find.byIcon(Icons.star), findsNWidgets(1));
    });

    testWidgets('difficulty clamp: 10 → 5 yıldız dolu', (tester) async {
      await tester.pumpWidget(
        _wrap(KnotDetailScreen(knot: _makeKnot(difficulty: 10))),
      );
      await tester.pump();
      // clamp(1,5) → en fazla 5 dolu yıldız
      expect(find.byIcon(Icons.star), findsNWidgets(5));
    });
  });

  group('KnotDetailScreen — Öğrendim butonu', () {
    testWidgets('başlangıçta "Öğrendim Olarak İşaretle" butonu görünür', (tester) async {
      await tester.pumpWidget(_wrap(KnotDetailScreen(knot: _makeKnot())));
      await tester.pump(); // setState için
      expect(find.text('Öğrendim Olarak İşaretle'), findsOneWidget);
      expect(find.text('✓ Öğrendim'), findsNothing);
    });

    testWidgets('butona tıklayınca "✓ Öğrendim" yazısı görünür', (tester) async {
      await tester.pumpWidget(_wrap(KnotDetailScreen(knot: _makeKnot())));
      await tester.pump();

      await tester.tap(find.text('Öğrendim Olarak İşaretle'));
      await tester.pump(); // async setState

      expect(find.text('✓ Öğrendim'), findsOneWidget);
      expect(find.text('Öğrendim Olarak İşaretle'), findsNothing);
    });

    testWidgets('öğrenildi iken tekrar tıklayınca geri alınır', (tester) async {
      await tester.pumpWidget(_wrap(KnotDetailScreen(knot: _makeKnot())));
      await tester.pump();

      await tester.tap(find.text('Öğrendim Olarak İşaretle'));
      await tester.pump();
      expect(find.text('✓ Öğrendim'), findsOneWidget);

      await tester.tap(find.text('✓ Öğrendim'));
      await tester.pump();
      expect(find.text('Öğrendim Olarak İşaretle'), findsOneWidget);
    });

    testWidgets('öğrenildi durumu SharedPreferences\'e kaydedilir', (tester) async {
      const knotId = 'knot_prefs_test';
      await tester.pumpWidget(
        _wrap(KnotDetailScreen(knot: _makeKnot(id: knotId))),
      );
      await tester.pump();

      await tester.tap(find.text('Öğrendim Olarak İşaretle'));
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      final learned = prefs.getStringList('learned_knots') ?? [];
      expect(learned.contains(knotId), isTrue);
    });

    testWidgets('SharedPreferences\'ten önceden öğrenilmiş durum yüklenir', (tester) async {
      const knotId = 'knot_preloaded';
      SharedPreferences.setMockInitialValues({
        'learned_knots': [knotId],
      });

      await tester.pumpWidget(
        _wrap(KnotDetailScreen(knot: _makeKnot(id: knotId))),
      );
      await tester.pumpAndSettle();

      expect(find.text('✓ Öğrendim'), findsOneWidget);
    });
  });
}
