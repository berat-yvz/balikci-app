import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/data/models/checkin_model.dart';

void main() {
  final now = DateTime.now();

  Map<String, dynamic> baseJson({
    bool isHidden = false,
    int trueVotes = 0,
    int falseVotes = 0,
    DateTime? createdAt,
    DateTime? expiresAt,
    dynamic users,
  }) {
    return {
      'id': 'checkin-1',
      'user_id': 'user-1',
      'spot_id': 'spot-1',
      'crowd_level': 'normal',
      'fish_density': 'yoğun',
      'photo_url': null,
      'exif_verified': false,
      'is_hidden': isHidden,
      'true_votes': trueVotes,
      'false_votes': falseVotes,
      'created_at': (createdAt ?? now).toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'users': users,
    };
  }

  group('CheckinModel.fromJson', () {
    test('tam veriyle parse edilir', () {
      final model = CheckinModel.fromJson(baseJson());
      expect(model.id, 'checkin-1');
      expect(model.userId, 'user-1');
      expect(model.spotId, 'spot-1');
      expect(model.crowdLevel, 'normal');
      expect(model.fishDensity, 'yoğun');
      expect(model.isHidden, isFalse);
      expect(model.trueVotes, 0);
      expect(model.falseVotes, 0);
    });

    test('eksik alanlar için varsayılanlar', () {
      final json = {
        'id': 'c-2',
        'user_id': 'u-2',
        'spot_id': 's-2',
        'created_at': now.toIso8601String(),
      };
      final model = CheckinModel.fromJson(json);
      expect(model.exifVerified, isFalse);
      expect(model.isHidden, isFalse);
      expect(model.trueVotes, 0);
      expect(model.falseVotes, 0);
      expect(model.fishSpecies, isEmpty);
    });

    test('fish_species dizi olarak parse edilir', () {
      final j = baseJson();
      j['fish_species'] = ['Lüfer', 'Levrek'];
      final model = CheckinModel.fromJson(j);
      expect(model.fishSpecies, ['Lüfer', 'Levrek']);
    });
  });

  group('CheckinModel.isActive', () {
    test('gizlenmiş → aktif değil', () {
      final model = CheckinModel.fromJson(
        baseJson(
          isHidden: true,
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );
      expect(model.isActive, isFalse);
    });

    test('süresi dolmamış, gizlenmemiş → aktif', () {
      final model = CheckinModel.fromJson(
        baseJson(expiresAt: now.add(const Duration(hours: 1))),
      );
      expect(model.isActive, isTrue);
    });

    test('expires_at null, kayıt remove penceresi içinde → aktif', () {
      final model = CheckinModel.fromJson(
        baseJson(createdAt: now.subtract(const Duration(hours: 1))),
      );
      expect(model.isActive, isTrue);
    });

    test('expires_at null, kayıt remove saatini aştı → aktif değil', () {
      final model = CheckinModel.fromJson(
        baseJson(createdAt: now.subtract(const Duration(hours: 7))),
      );
      expect(model.isActive, isFalse);
    });

    test('süresi geçmiş → aktif değil', () {
      final model = CheckinModel.fromJson(
        baseJson(expiresAt: now.subtract(const Duration(hours: 1))),
      );
      expect(model.isActive, isFalse);
    });
  });

  group('CheckinModel.isStale', () {
    test('1 saat önce oluşturulmuş → stale değil', () {
      final model = CheckinModel.fromJson(
        baseJson(createdAt: now.subtract(const Duration(hours: 1))),
      );
      expect(model.isStale, isFalse);
    });

    test('3 saat önce oluşturulmuş → stale', () {
      final model = CheckinModel.fromJson(
        baseJson(createdAt: now.subtract(const Duration(hours: 3))),
      );
      expect(model.isStale, isTrue);
    });

    test('tam 2 saat → stale (sınır dahil)', () {
      final model = CheckinModel.fromJson(
        baseJson(createdAt: now.subtract(const Duration(hours: 2))),
      );
      expect(model.isStale, isTrue);
    });
  });

  group('CheckinModel.isExpired', () {
    test('5 saat önce → süresi dolmamış', () {
      final model = CheckinModel.fromJson(
        baseJson(createdAt: now.subtract(const Duration(hours: 5))),
      );
      expect(model.isExpired, isFalse);
    });

    test('7 saat önce → süresi dolmuş', () {
      final model = CheckinModel.fromJson(
        baseJson(createdAt: now.subtract(const Duration(hours: 7))),
      );
      expect(model.isExpired, isTrue);
    });
  });

  group('CheckinModel.isSuppressedByVotes', () {
    test('3 oydan az → gizleme yok', () {
      final model = CheckinModel.fromJson(
        baseJson(trueVotes: 0, falseVotes: 2),
      );
      expect(model.isSuppressedByVotes, isFalse);
    });

    test('tam %70 yanlış oy (3/3 false + 0 true → imkansız; 3 false 0 true) → gizle', () {
      final model = CheckinModel.fromJson(
        baseJson(trueVotes: 0, falseVotes: 3),
      );
      expect(model.isSuppressedByVotes, isTrue);
    });

    test('%70 eşik: 7 false 3 true (10 oy) → %70 → gizle', () {
      final model = CheckinModel.fromJson(
        baseJson(trueVotes: 3, falseVotes: 7),
      );
      expect(model.isSuppressedByVotes, isTrue);
    });

    test('%69 yanlış oy → gizleme yok (eşik altı)', () {
      final model = CheckinModel.fromJson(
        baseJson(trueVotes: 31, falseVotes: 69),
      );
      // 69/100 = 0.69 < 0.70
      expect(model.isSuppressedByVotes, isFalse);
    });

    test('3 true 1 false (4 oy) → %25 yanlış → gizleme yok', () {
      final model = CheckinModel.fromJson(
        baseJson(trueVotes: 3, falseVotes: 1),
      );
      expect(model.isSuppressedByVotes, isFalse);
    });

    test('hiç oy yok → gizleme yok', () {
      final model = CheckinModel.fromJson(baseJson());
      expect(model.isSuppressedByVotes, isFalse);
    });

    test('oy baskısı isActive\'i de etkiler', () {
      // %70+ false oy → isActive false olmalı (süresi dolmamış olsa bile)
      final model = CheckinModel.fromJson(
        baseJson(
          trueVotes: 1,
          falseVotes: 9,
          expiresAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      );
      expect(model.isSuppressedByVotes, isTrue);
      expect(model.isActive, isFalse);
    });
  });

  group('CheckinModel username parse', () {
    test('users Map formatında → username parse edilir', () {
      final model = CheckinModel.fromJson(
        baseJson(users: {'username': 'ahmet_balikci', 'id': 'u-1'}),
      );
      expect(model.username, 'ahmet_balikci');
    });

    test('users List formatında → ilk elemanın username alınır', () {
      final model = CheckinModel.fromJson(
        baseJson(users: [{'username': 'mehmet_usta', 'id': 'u-2'}]),
      );
      expect(model.username, 'mehmet_usta');
    });

    test('users null → username null', () {
      final model = CheckinModel.fromJson(baseJson(users: null));
      expect(model.username, isNull);
    });

    test('users boş liste → username null', () {
      final model = CheckinModel.fromJson(baseJson(users: []));
      expect(model.username, isNull);
    });
  });
}
