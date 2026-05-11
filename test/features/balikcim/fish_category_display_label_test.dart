import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_model.dart';

void main() {
  group('fishCategoryDisplayLabel', () {
    test('bilinen kategori kodları Türkçe etiket döner', () {
      expect(fishCategoryDisplayLabel('goc'), 'Göçmen Balık');
      expect(fishCategoryDisplayLabel('kiyi'), 'Kıyı Balığı');
      expect(fishCategoryDisplayLabel('dip'), 'Dip Balığı');
      expect(fishCategoryDisplayLabel('acik_deniz'), 'Açık Deniz');
      expect(fishCategoryDisplayLabel('tatli_su'), 'Tatlısu Balığı');
    });

    test('bilinmeyen kod ham olarak döner', () {
      expect(fishCategoryDisplayLabel('ozel_kategori'), 'ozel_kategori');
    });
  });
}
