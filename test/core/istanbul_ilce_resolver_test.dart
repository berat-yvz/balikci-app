import 'package:balikci_app/core/utils/istanbul_ilce_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Kadıköy sahil noktasına en yakın ilçe Kadıköy', () {
    final p = IstanbulIlceResolver.nearestIlce(40.995, 29.04);
    expect(p, isNotNull);
    expect(p!.regionKey, 'istanbul_ilce_kadikoy');
  });

  test('Metro dışı — null', () {
    expect(IstanbulIlceResolver.nearestIlce(38.42, 27.14), isNull);
  });

  test('isInIstanbulMetro Silivri ve Şile köşeleri', () {
    expect(IstanbulIlceResolver.isInIstanbulMetro(41.07, 28.25), isTrue);
    expect(IstanbulIlceResolver.isInIstanbulMetro(41.18, 29.61), isTrue);
  });
}
