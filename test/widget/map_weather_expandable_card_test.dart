import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/data/models/weather_model.dart';
import 'package:balikci_app/features/map/widgets/weather_card.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';
import 'package:balikci_app/shared/providers/fishing_score_provider.dart';

WeatherModel _fixtureWeather() => WeatherModel(
      id: 'test_region',
      lat: 41.01,
      lng: 28.98,
      dataJson: null,
      temperature: 22,
      windspeed: 15,
      windDirection: 90,
      waveHeight: 0.4,
      seaSurfaceTemperature: null,
      precipitation: null,
      humidity: 65,
      visibilityKm: 10,
      cloudCover: 40,
      fishingSummary: null,
      fetchedAt: DateTime.utc(2026, 5, 1),
      regionKey: 'istanbul',
    );

IstanbulWeatherData _fixturePack() => IstanbulWeatherData(
      hourly: const [],
      current: _fixtureWeather(),
      lat: 41.01,
      lng: 28.98,
    );

/// Ağ/Drift yolu kullanmadan sabit hava paketi döner.
class _FixedIstanbulWeatherNotifier extends IstanbulWeatherNotifier {
  _FixedIstanbulWeatherNotifier(this._data);
  final IstanbulWeatherData _data;

  @override
  Future<IstanbulWeatherData> build() async => _data;
}

void main() {
  group('MapWeatherExpandableCard', () {
    testWidgets('defer sonrası sıcaklık ve geniş kart görünür', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            istanbulWeatherProvider.overrideWith(
              () => _FixedIstanbulWeatherNotifier(_fixturePack()),
            ),
            fishingScoreProvider.overrideWith(
              (ref) => const AsyncValue.loading(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MapWeatherExpandableCard(),
            ),
          ),
        ),
      );

      await tester.pump();
      // defer iskeleti: Padding(top:12) + 48px kutu
      expect(tester.getSize(find.byType(MapWeatherExpandableCard)).height, 60);

      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(find.textContaining('22'), findsWidgets);
      expect(find.textContaining('km/h'), findsOneWidget);
    });

    testWidgets('dokununca küçük pill metnine geçer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            istanbulWeatherProvider.overrideWith(
              () => _FixedIstanbulWeatherNotifier(_fixturePack()),
            ),
            fishingScoreProvider.overrideWith(
              (ref) => const AsyncValue.loading(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MapWeatherExpandableCard(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(find.textContaining('° · '), findsNothing);

      await tester.tap(find.byType(MapWeatherExpandableCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.textContaining('° · '), findsOneWidget);
    });
  });
}
