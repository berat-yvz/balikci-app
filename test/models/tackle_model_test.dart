import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/data/models/tackle_model.dart';

void main() {
  final itemJson = {
    'name': 'Jig kafası',
    'detail': '10-20g, kancalı',
    'tip': 'Dip sürükleme için ideal',
  };

  final baseJson = {
    'id': 'tackle-1',
    'title': 'Lüfer Takımı',
    'target_species': ['Lüfer', 'Palamut'],
    'season': 'Sonbahar',
    'technique': 'Trolling',
    'difficulty': 2,
    'items': [itemJson],
  };

  group('TackleModel.fromJson', () {
    test('tam veriyle parse edilir', () {
      final tackle = TackleModel.fromJson(baseJson);
      expect(tackle.id, 'tackle-1');
      expect(tackle.title, 'Lüfer Takımı');
      expect(tackle.targetSpecies, ['Lüfer', 'Palamut']);
      expect(tackle.season, 'Sonbahar');
      expect(tackle.technique, 'Trolling');
      expect(tackle.difficulty, 2);
      expect(tackle.items.length, 1);
    });

    test('eksik alanlar için varsayılanlar', () {
      final tackle = TackleModel.fromJson({});
      expect(tackle.id, '');
      expect(tackle.title, '');
      expect(tackle.targetSpecies, isEmpty);
      expect(tackle.difficulty, 1);
      expect(tackle.items, isEmpty);
    });

    test('items TackleItem listesi olarak parse edilir', () {
      final tackle = TackleModel.fromJson(baseJson);
      expect(tackle.items.first, isA<TackleItem>());
      expect(tackle.items.first.name, 'Jig kafası');
    });
  });

  group('TackleItem.fromJson', () {
    test('tam veriyle parse edilir', () {
      final item = TackleItem.fromJson(itemJson);
      expect(item.name, 'Jig kafası');
      expect(item.detail, '10-20g, kancalı');
      expect(item.tip, 'Dip sürükleme için ideal');
    });

    test('eksik alanlar boş string döner', () {
      final item = TackleItem.fromJson({});
      expect(item.name, '');
      expect(item.detail, '');
      expect(item.tip, '');
    });
  });
}
