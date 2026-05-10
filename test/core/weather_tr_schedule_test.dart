import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/core/utils/weather_tr_schedule.dart';

void main() {
  group('nextUtcInstantForIstanbulWallMinute2', () {
    test('10:01 UTC → 10:02 UTC (İstanbul 13:02)', () {
      final utc = DateTime.utc(2026, 5, 10, 10, 1, 0);
      final next = nextUtcInstantForIstanbulWallMinute2(utc);
      expect(next, DateTime.utc(2026, 5, 10, 10, 2, 0));
    });

    test('10:03 UTC → 11:02 UTC', () {
      final utc = DateTime.utc(2026, 5, 10, 10, 3, 0);
      final next = nextUtcInstantForIstanbulWallMinute2(utc);
      expect(next, DateTime.utc(2026, 5, 10, 11, 2, 0));
    });
  });

  group('isIstanbulWallMinuteAtOrAfterSyncMark', () {
    test('TR 13:01 → false', () {
      final utc = DateTime.utc(2026, 5, 10, 10, 1, 0);
      expect(isIstanbulWallMinuteAtOrAfterSyncMark(utc), isFalse);
    });
    test('TR 13:02 → true', () {
      final utc = DateTime.utc(2026, 5, 10, 10, 2, 0);
      expect(isIstanbulWallMinuteAtOrAfterSyncMark(utc), isTrue);
    });
  });

  group('openMeteoIstanbulNaiveTimeToUtc', () {
    test('ofsetsiz TR saati UTC\'ye iner', () {
      final u = openMeteoIstanbulNaiveTimeToUtc('2026-05-08T14:30');
      expect(u.toUtc().hour, 11);
      expect(u.toUtc().minute, 30);
    });
  });
}
