import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/core/constants/app_constants.dart';
import 'package:balikci_app/core/constants/weather_regions.dart';

void main() {
  group('AppConstants — check-in sabitler', () {
    test('checkinRadiusMeters = 500', () {
      expect(AppConstants.checkinRadiusMeters, 500);
    });

    test('checkinExpireHours = 2', () {
      expect(AppConstants.checkinExpireHours, 2);
    });

    test('checkinRemoveHours = 6', () {
      expect(AppConstants.checkinRemoveHours, 6);
    });

    test('expire < remove (mantık sırası doğru)', () {
      expect(AppConstants.checkinExpireHours, lessThan(AppConstants.checkinRemoveHours));
    });
  });

  group('AppConstants — oy sabitleri', () {
    test('voteThresholdPercent = 0.70', () {
      expect(AppConstants.voteThresholdPercent, 0.70);
    });

    test('minVotesForHide = 3', () {
      expect(AppConstants.minVotesForHide, 3);
    });

    test('eşik 0-1 aralığında', () {
      expect(AppConstants.voteThresholdPercent, inInclusiveRange(0.0, 1.0));
    });
  });

  group('AppConstants — harita sabitleri', () {
    test('defaultLat İstanbul enlem aralığında', () {
      // İstanbul: ~40-42°N
      expect(AppConstants.defaultLat, inInclusiveRange(39.0, 43.0));
    });

    test('defaultLng İstanbul boylam aralığında', () {
      // İstanbul: ~28-29°E
      expect(AppConstants.defaultLng, inInclusiveRange(27.0, 31.0));
    });

    test('defaultZoom pozitif', () {
      expect(AppConstants.defaultZoom, greaterThan(0));
    });

    test('clusterZoomThreshold > defaultZoom', () {
      expect(AppConstants.clusterZoomThreshold, greaterThan(AppConstants.defaultZoom));
    });
  });

  group('AppConstants — genel sabitler', () {
    test('maxPhotoSizeBytes = 2 MB', () {
      expect(AppConstants.maxPhotoSizeBytes, 2 * 1024 * 1024);
    });

    test('pageSize pozitif', () {
      expect(AppConstants.pageSize, greaterThan(0));
    });

    test('httpTimeoutSeconds pozitif', () {
      expect(AppConstants.httpTimeoutSeconds, greaterThan(0));
    });
  });

  group('weatherRegions', () {
    test('12 bölge tanımlı', () {
      expect(weatherRegions.length, 12);
    });

    test('her bölgenin lat ve lng değeri var', () {
      for (final entry in weatherRegions.entries) {
        expect(entry.value.containsKey('lat'), isTrue,
            reason: '${entry.key} bölgesinde lat eksik');
        expect(entry.value.containsKey('lng'), isTrue,
            reason: '${entry.key} bölgesinde lng eksik');
      }
    });

    test('istanbul bölgesi koordinatları doğru', () {
      final istanbul = weatherRegions['istanbul']!;
      expect(istanbul['lat'], closeTo(41.015, 0.001));
      expect(istanbul['lng'], closeTo(28.979, 0.001));
    });

    test('tüm bölgelerin lat değerleri Türkiye sınırlarında', () {
      // Türkiye: 36-42°N
      for (final entry in weatherRegions.entries) {
        final lat = entry.value['lat']!;
        expect(lat, inInclusiveRange(35.0, 43.0),
            reason: '${entry.key} lat=$lat Türkiye sınırları dışında');
      }
    });

    test('tüm bölgelerin lng değerleri Türkiye sınırlarında', () {
      // Türkiye: 26-45°E
      for (final entry in weatherRegions.entries) {
        final lng = entry.value['lng']!;
        expect(lng, inInclusiveRange(25.0, 46.0),
            reason: '${entry.key} lng=$lng Türkiye sınırları dışında');
      }
    });
  });
}
