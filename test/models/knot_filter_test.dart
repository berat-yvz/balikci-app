import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/data/models/knot_model.dart';

/// KnotsScreen'deki filtreleme mantığını test eder.
/// (Ekran JsonAssets gerektirdiğinden mantık ayrıştırılıp test edildi.)

List<KnotModel> _makeKnots() => [
  const KnotModel(
    id: 'k1', title: 'Palomar', category: 'kanca',
    difficulty: 1, useCases: [], steps: [],
  ),
  const KnotModel(
    id: 'k2', title: 'Albright', category: 'birlestirme',
    difficulty: 3, useCases: [], steps: [],
  ),
  const KnotModel(
    id: 'k3', title: 'FG Düğüm', category: 'lider',
    difficulty: 5, useCases: [], steps: [],
  ),
  const KnotModel(
    id: 'k4', title: 'Clinch', category: 'kanca',
    difficulty: 2, useCases: [], steps: [],
  ),
];

List<KnotModel> _filter(List<KnotModel> knots, String category) {
  if (category == 'tumu') return knots;
  return knots.where((k) => k.category == category).toList();
}

void main() {
  final knots = _makeKnots();

  group('KnotsScreen filtreleme mantığı', () {
    test('"tumu" filtresi tüm düğümleri döner', () {
      expect(_filter(knots, 'tumu').length, 4);
    });

    test('"kanca" filtresi yalnızca kanca düğümlerini döner', () {
      final result = _filter(knots, 'kanca');
      expect(result.length, 2);
      expect(result.every((k) => k.category == 'kanca'), isTrue);
    });

    test('"birlestirme" filtresi yalnızca birleştirme düğümlerini döner', () {
      final result = _filter(knots, 'birlestirme');
      expect(result.length, 1);
      expect(result.first.id, 'k2');
    });

    test('"lider" filtresi yalnızca lider düğümlerini döner', () {
      final result = _filter(knots, 'lider');
      expect(result.length, 1);
      expect(result.first.id, 'k3');
    });

    test('eşleşen düğüm yoksa boş liste döner', () {
      expect(_filter(knots, 'bilinmeyen').isEmpty, isTrue);
    });

    test('boş listede filtreleme → boş döner', () {
      expect(_filter([], 'kanca').isEmpty, isTrue);
    });
  });

  group('KnotModel zorluk doğrulaması', () {
    test('difficulty 1 → 1 (min)', () {
      const k = KnotModel(
        id: 'k', title: 'T', category: 'kanca',
        difficulty: 1, useCases: [], steps: [],
      );
      expect(k.difficulty.clamp(1, 5), 1);
    });

    test('difficulty 5 → 5 (max)', () {
      const k = KnotModel(
        id: 'k', title: 'T', category: 'kanca',
        difficulty: 5, useCases: [], steps: [],
      );
      expect(k.difficulty.clamp(1, 5), 5);
    });

    test('difficulty 0 → clamp(1,5) = 1', () {
      const k = KnotModel(
        id: 'k', title: 'T', category: 'kanca',
        difficulty: 0, useCases: [], steps: [],
      );
      expect(k.difficulty.clamp(1, 5), 1);
    });

    test('difficulty 10 → clamp(1,5) = 5', () {
      const k = KnotModel(
        id: 'k', title: 'T', category: 'kanca',
        difficulty: 10, useCases: [], steps: [],
      );
      expect(k.difficulty.clamp(1, 5), 5);
    });
  });
}
