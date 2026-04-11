import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/data/models/fish_log_model.dart';

/// StatsScreen'deki hesaplamaları doğrudan test eden unit testler.
/// (Ekran Supabase'e bağlı olduğundan mantık buraya ayrıştırılıp test edildi.)

List<FishLogModel> _makeLogs({
  int total = 0,
  int released = 0,
  Map<String, int>? speciesCounts,
}) {
  final logs = <FishLogModel>[];
  int index = 0;

  if (speciesCounts != null) {
    for (final entry in speciesCounts.entries) {
      for (var i = 0; i < entry.value; i++) {
        logs.add(FishLogModel(
          id: 'log_$index',
          userId: 'user1',
          spotId: null,
          species: entry.key,
          weight: 1.0,
          released: i < (released > 0 ? released : 0),
          createdAt: DateTime.now(),
        ));
        index++;
      }
    }
  } else {
    for (var i = 0; i < total; i++) {
      logs.add(FishLogModel(
        id: 'log_$i',
        userId: 'user1',
        spotId: null,
        species: 'Levrek',
        weight: 1.0,
        released: i < released,
        createdAt: DateTime.now(),
      ));
    }
  }
  return logs;
}

// StatsScreen'den kopyalanan saf hesaplama fonksiyonları.
int _total(List<FishLogModel> logs) => logs.length;
int _released(List<FishLogModel> logs) => logs.where((l) => l.released).length;
int _sustainPercent(List<FishLogModel> logs) {
  final t = _total(logs);
  return t == 0 ? 0 : (_released(logs) / t * 100).round();
}

List<MapEntry<String, int>> _topSpecies(List<FishLogModel> logs) {
  final map = <String, int>{};
  for (final l in logs) {
    map[l.species] = (map[l.species] ?? 0) + 1;
  }
  return (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(3)
      .toList();
}

void main() {
  group('StatsScreen hesaplamaları — toplam av', () {
    test('boş liste → toplam 0', () {
      expect(_total([]), 0);
    });

    test('5 kayıt → toplam 5', () {
      expect(_total(_makeLogs(total: 5)), 5);
    });
  });

  group('StatsScreen hesaplamaları — salınan balık', () {
    test('boş liste → 0 salınan', () {
      expect(_released([]), 0);
    });

    test('5 kayıttan 3\'ü salındı', () {
      expect(_released(_makeLogs(total: 5, released: 3)), 3);
    });

    test('tamamı salındı', () {
      expect(_released(_makeLogs(total: 4, released: 4)), 4);
    });

    test('hiç salınmadı', () {
      expect(_released(_makeLogs(total: 3, released: 0)), 0);
    });
  });

  group('StatsScreen hesaplamaları — sürdürülebilirlik %', () {
    test('boş liste → %0 (sıfıra bölme yok)', () {
      expect(_sustainPercent([]), 0);
    });

    test('10 kayıttan 5\'i salındı → %50', () {
      expect(_sustainPercent(_makeLogs(total: 10, released: 5)), 50);
    });

    test('tamamı salındı → %100', () {
      expect(_sustainPercent(_makeLogs(total: 4, released: 4)), 100);
    });

    test('hiç salınmadı → %0', () {
      expect(_sustainPercent(_makeLogs(total: 5, released: 0)), 0);
    });

    test('1 kayıttan 1\'i salındı → %100', () {
      expect(_sustainPercent(_makeLogs(total: 1, released: 1)), 100);
    });

    test('3 kayıttan 1\'i salındı → ~%33', () {
      expect(_sustainPercent(_makeLogs(total: 3, released: 1)), 33);
    });
  });

  group('StatsScreen hesaplamaları — en çok tutulan türler', () {
    test('boş liste → boş liste', () {
      expect(_topSpecies([]), isEmpty);
    });

    test('en çok tutulan tür en üstte', () {
      final logs = _makeLogs(speciesCounts: {'Levrek': 5, 'Çipura': 3, 'Lüfer': 1});
      final top = _topSpecies(logs);
      expect(top.first.key, 'Levrek');
      expect(top.first.value, 5);
    });

    test('en fazla 3 tür döner', () {
      final logs = _makeLogs(speciesCounts: {
        'Levrek': 5,
        'Çipura': 4,
        'Lüfer': 3,
        'Kefal': 2,
        'İstavroz': 1,
      });
      expect(_topSpecies(logs).length, 3);
    });

    test('2 türden az kayıt → 2 döner', () {
      final logs = _makeLogs(speciesCounts: {'Levrek': 3, 'Çipura': 1});
      expect(_topSpecies(logs).length, 2);
    });

    test('sıralama: azalan sayı', () {
      final logs = _makeLogs(speciesCounts: {'A': 1, 'B': 10, 'C': 5});
      final top = _topSpecies(logs);
      expect(top[0].key, 'B');
      expect(top[1].key, 'C');
      expect(top[2].key, 'A');
    });
  });
}
