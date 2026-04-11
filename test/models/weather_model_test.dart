import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/data/models/weather_model.dart';

WeatherModel _makeStored({
  double temp = 20,
  double wind = 10,
  int? weatherCode,
}) => WeatherModel(
  id: 'test',
  lat: 41.0,
  lng: 28.0,
  dataJson: null,
  temperature: temp,
  windspeed: wind,
  windDirection: null,
  waveHeight: null,
  seaSurfaceTemperature: null,
  precipitation: null,
  humidity: null,
  visibilityKm: null,
  cloudCover: null,
  weatherCode: weatherCode,
  fishingSummary: null,
  fetchedAt: DateTime(2025),
  regionKey: 'test',
);

WeatherModel _makeFromDataJson({
  double tempC = 20,
  double windMs = 5,
  int? weatherId,
  double? visibilityM,
}) => WeatherModel(
  id: 'test',
  lat: 41.0,
  lng: 28.0,
  dataJson: {
    'main': {'temp': tempC, 'humidity': 70.0},
    'wind': {'speed': windMs, 'deg': 270},
    'clouds': {'all': 40.0},
    if (weatherId != null) 'weather': [{'id': weatherId, 'main': 'Clear'}],
    if (visibilityM != null) 'visibility': visibilityM,
  },
  temperature: tempC,
  windspeed: windMs * 3.6,
  windDirection: null,
  waveHeight: null,
  seaSurfaceTemperature: null,
  precipitation: null,
  humidity: null,
  visibilityKm: null,
  cloudCover: null,
  weatherCode: null,
  fishingSummary: null,
  fetchedAt: DateTime(2025),
  regionKey: 'test',
);

void main() {
  group('WeatherModel.tempCelsius', () {
    test('stored path → doğrudan temperature döner', () {
      expect(_makeStored(temp: 22.5).tempCelsius, 22.5);
    });

    test('dataJson path → main.temp döner', () {
      expect(_makeFromDataJson(tempC: 18.0).tempCelsius, 18.0);
    });

    test('temperature null → 0.0 döner', () {
      final m = WeatherModel(
        id: 'x', lat: 0, lng: 0, dataJson: null,
        temperature: null, windspeed: null, windDirection: null,
        waveHeight: null, seaSurfaceTemperature: null,
        precipitation: null, humidity: null, visibilityKm: null,
        cloudCover: null, fishingSummary: null,
        fetchedAt: DateTime(2025), regionKey: null,
      );
      expect(m.tempCelsius, 0.0);
    });
  });

  group('WeatherModel.windKmh', () {
    test('stored path → doğrudan windspeed döner (km/h)', () {
      // stored windspeed is already in km/h
      expect(_makeStored(wind: 36.0).windKmh, 36.0);
    });

    test('dataJson path → m/s × 3.6 = km/h', () {
      // 10 m/s × 3.6 = 36 km/h
      expect(_makeFromDataJson(windMs: 10.0).windKmh, closeTo(36.0, 0.01));
    });

    test('windspeed null → 0.0 döner', () {
      final m = WeatherModel(
        id: 'x', lat: 0, lng: 0, dataJson: null,
        temperature: null, windspeed: null, windDirection: null,
        waveHeight: null, seaSurfaceTemperature: null,
        precipitation: null, humidity: null, visibilityKm: null,
        cloudCover: null, fishingSummary: null,
        fetchedAt: DateTime(2025), regionKey: null,
      );
      expect(m.windKmh, 0.0);
    });
  });

  group('WeatherModel.weatherCode', () {
    test('stored path → _weatherCode döner', () {
      expect(_makeStored(weatherCode: 800).weatherCode, 800);
    });

    test('stored path → null döner (kod verilmediyse)', () {
      expect(_makeStored().weatherCode, isNull);
    });

    test('dataJson path → weather[0].id döner', () {
      expect(_makeFromDataJson(weatherId: 500).weatherCode, 500);
    });

    test('dataJson path → weather listesi yoksa 800 döner', () {
      expect(_makeFromDataJson().weatherCode, 800);
    });
  });

  group('WeatherModel.fromJson', () {
    test('tam JSON ile parse edilir', () {
      final json = {
        'id': 'w-1',
        'lat': 41.0,
        'lng': 28.0,
        'data_json': {
          'main': {'temp': 22.0, 'humidity': 65.0},
          'wind': {'speed': 8.0, 'deg': 180},
          'clouds': {'all': 25.0},
          'weather': [{'id': 800, 'main': 'Clear'}],
          'visibility': 10000,
        },
        'fishing_summary': 'Harika gün',
        'fetched_at': '2025-06-01T09:00:00.000',
        'region_key': 'istanbul',
      };
      final m = WeatherModel.fromJson(json);
      expect(m.id, 'w-1');
      expect(m.lat, 41.0);
      expect(m.fishingSummary, 'Harika gün');
      expect(m.regionKey, 'istanbul');
    });

    test('data_json null → stored alanlar null, getter\'lar 0 döner', () {
      final json = {
        'id': 'w-2',
        'lat': 41.0,
        'lng': 28.0,
        'data_json': null,
        'fetched_at': '2025-06-01T09:00:00.000',
        'region_key': null,
      };
      final m = WeatherModel.fromJson(json);
      expect(m.tempCelsius, 0.0);
      expect(m.windKmh, 0.0);
    });

    test('visibility metre → km\'e çevrilir', () {
      final json = {
        'id': 'w-3',
        'lat': 0.0,
        'lng': 0.0,
        'data_json': {
          'main': {'temp': 20.0},
          'wind': {'speed': 5.0},
          'visibility': 5000,
        },
        'fetched_at': '2025-06-01T09:00:00.000',
      };
      final m = WeatherModel.fromJson(json);
      expect(m.visibilityKm, 5.0);
    });

    test('windspeed m/s → km/h olarak stored alana yazılır', () {
      final json = {
        'id': 'w-4',
        'lat': 0.0,
        'lng': 0.0,
        'data_json': {
          'main': {'temp': 20.0},
          'wind': {'speed': 10.0},
        },
        'fetched_at': '2025-06-01T09:00:00.000',
      };
      final m = WeatherModel.fromJson(json);
      // stored windspeed = 10 * 3.6 = 36
      expect(m.windspeed, closeTo(36.0, 0.01));
    });
  });
}
