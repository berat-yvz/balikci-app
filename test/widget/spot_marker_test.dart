import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/features/map/widgets/spot_marker.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

SpotMarker _make({
  String privacyLevel = 'public',
  int activeCheckinCount = 0,
  int? checkinAgeMinutes,
  double zoom = 10,
  String spotName = '',
  bool isLocked = false,
}) => SpotMarker(
  privacyLevel: privacyLevel,
  activeCheckinCount: activeCheckinCount,
  checkinAgeMinutes: checkinAgeMinutes,
  zoom: zoom,
  spotName: spotName,
  isLocked: isLocked,
);

void main() {
  group('SpotMarker — kilit durumu', () {
    testWidgets('isLocked=true → 🔒 gösterilir', (tester) async {
      await tester.pumpWidget(_wrap(_make(isLocked: true)));
      expect(find.text('🔒'), findsOneWidget);
    });

    testWidgets('isLocked=false → 🐟 gösterilir', (tester) async {
      await tester.pumpWidget(_wrap(_make(isLocked: false)));
      expect(find.text('🐟'), findsOneWidget);
    });
  });

  group('SpotMarker — VIP gösterimi', () {
    testWidgets('vip ve kilit yok → ⭐ ilave gösterilir', (tester) async {
      await tester.pumpWidget(_wrap(_make(privacyLevel: 'vip', isLocked: false)));
      expect(find.text('⭐'), findsOneWidget);
      expect(find.text('🐟'), findsOneWidget);
    });

    testWidgets('vip ve kilitli → sadece 🔒 gösterilir, ⭐ yok', (tester) async {
      await tester.pumpWidget(_wrap(_make(privacyLevel: 'vip', isLocked: true)));
      expect(find.text('🔒'), findsOneWidget);
      expect(find.text('⭐'), findsNothing);
    });
  });

  group('SpotMarker — isim etiketi', () {
    testWidgets('zoom ≤ 13 → isim etiketi görünmez', (tester) async {
      await tester.pumpWidget(_wrap(_make(zoom: 10, spotName: 'Balık Noktası')));
      expect(find.text('Balık Noktası'), findsNothing);
    });

    testWidgets('zoom > 13 → isim etiketi görünür', (tester) async {
      await tester.pumpWidget(_wrap(_make(zoom: 14, spotName: 'Balık Noktası')));
      expect(find.text('Balık Noktası'), findsOneWidget);
    });

    testWidgets('14 karakter üzeri isim kısaltılır', (tester) async {
      await tester.pumpWidget(
        _wrap(_make(zoom: 14, spotName: 'Uzun Mera İsmi Burada')),
      );
      // 14 karakter + "…" olmalı, tam ad gösterilmemeli
      expect(find.textContaining('…'), findsOneWidget);
      expect(find.text('Uzun Mera İsmi Burada'), findsNothing);
    });

    testWidgets('boş spotName → zoom > 13 olsa da etiket yok', (tester) async {
      await tester.pumpWidget(_wrap(_make(zoom: 14, spotName: '')));
      // boş text widget'ı var mı diye bakmak yerine sadece beklenen text yok
      expect(find.text(''), findsNothing);
    });
  });

  group('SpotMarker — rozet', () {
    testWidgets('activeCheckinCount=0 ve ageMinutes=null → rozet yok', (tester) async {
      await tester.pumpWidget(_wrap(_make(activeCheckinCount: 0)));
      // Rozet widget'ı yok → hiçbir sayı metni yok
      expect(find.text('1'), findsNothing);
    });

    testWidgets('activeCheckinCount=3 → rozet içinde 3 gösterilir', (tester) async {
      await tester.pumpWidget(
        _wrap(_make(activeCheckinCount: 3, checkinAgeMinutes: 10)),
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('count=100 → 99+ olarak gösterilir', (tester) async {
      await tester.pumpWidget(
        _wrap(_make(activeCheckinCount: 100, checkinAgeMinutes: 10)),
      );
      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('SpotMarker — yaş etiketi', () {
    testWidgets('ageMinutes=30, zoom=12 → 30dk etiketi görünür', (tester) async {
      await tester.pumpWidget(
        _wrap(_make(activeCheckinCount: 1, checkinAgeMinutes: 30, zoom: 12)),
      );
      expect(find.text('30dk'), findsOneWidget);
    });

    testWidgets('ageMinutes=150 (aging), zoom=12 → 3sa etiketi görünür', (tester) async {
      // 121-300 dk = aging state → hasBadge=true, label=(150/60).round()=3 → "3sa"
      await tester.pumpWidget(
        _wrap(_make(activeCheckinCount: 0, checkinAgeMinutes: 150, zoom: 12)),
      );
      expect(find.text('3sa'), findsOneWidget);
    });

    testWidgets('ageMinutes=240 (aging), zoom=12 → 4sa etiketi görünür', (tester) async {
      // 240 dk = aging state, (240/60).round()=4 → "4sa"
      await tester.pumpWidget(
        _wrap(_make(activeCheckinCount: 0, checkinAgeMinutes: 240, zoom: 12)),
      );
      expect(find.text('4sa'), findsOneWidget);
    });

    testWidgets('zoom ≤ 11 → yaş etiketi gizlenir', (tester) async {
      await tester.pumpWidget(
        _wrap(_make(activeCheckinCount: 0, checkinAgeMinutes: 30, zoom: 11)),
      );
      expect(find.text('30dk'), findsNothing);
    });
  });
}
