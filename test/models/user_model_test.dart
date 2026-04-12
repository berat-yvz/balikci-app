import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/data/models/user_model.dart';

void main() {
  Map<String, dynamic> baseJson({
    String? username,
    String email = 'balikci@test.com',
    String rank = 'acemi',
    int totalScore = 0,
    int sustainabilityScore = 0,
  }) {
    return {
      'id': 'user-1',
      'email': email,
      'username': username,
      'avatar_url': null,
      'rank': rank,
      'total_score': totalScore,
      'sustainability_score': sustainabilityScore,
      'fcm_token': null,
      'created_at': '2025-01-01T00:00:00.000Z',
    };
  }

  group('UserModel.fromJson', () {
    test('tam veriyle parse edilir', () {
      final user = UserModel.fromJson(
        baseJson(username: 'BalikciAhmet', totalScore: 1500),
      );
      expect(user.id, 'user-1');
      expect(user.email, 'balikci@test.com');
      expect(user.username, 'BalikciAhmet');
      expect(user.rank, 'acemi');
      expect(user.totalScore, 1500);
    });

    test('varsayılan rank acemi', () {
      final json = baseJson();
      json.remove('rank');
      final user = UserModel.fromJson(json);
      expect(user.rank, 'acemi');
    });

    test('varsayılan totalScore sıfır', () {
      final json = baseJson();
      json.remove('total_score');
      final user = UserModel.fromJson(json);
      expect(user.totalScore, 0);
    });

    test('total_score double JSON → int', () {
      final json = baseJson(username: 'X', totalScore: 0);
      json['total_score'] = 42.7;
      final user = UserModel.fromJson(json);
      expect(user.totalScore, 43);
    });
  });

  group('UserModel username çözümleme', () {
    test('geçerli username korunur', () {
      final user = UserModel.fromJson(
        baseJson(username: 'BalikciAhmet'),
      );
      expect(user.username, 'BalikciAhmet');
    });

    test('user_xxxxxxxx formatı → e-posta ön eki kullanılır', () {
      final user = UserModel.fromJson(
        baseJson(username: 'user_abc123def', email: 'balikci@test.com'),
      );
      expect(user.username, 'balikci');
    });

    test('username null → e-posta ön eki kullanılır', () {
      final user = UserModel.fromJson(
        baseJson(username: null, email: 'mehmet.usta@test.com'),
      );
      expect(user.username, 'mehmet.usta');
    });

    test('username boş → e-posta ön eki kullanılır', () {
      final user = UserModel.fromJson(
        baseJson(username: '', email: 'deniz@test.com'),
      );
      expect(user.username, 'deniz');
    });

    test('kısa user_ formatı (altı karakterden az) → korunur', () {
      // user_xyz formatı regex: user_[0-9a-f]{6,} → 5 karakter hex geçmez
      final user = UserModel.fromJson(
        baseJson(username: 'user_xyz', email: 'test@test.com'),
      );
      // 'user_xyz' hex değil (x,y,z hex değil) → regex eşleşmez → username korunur
      expect(user.username, 'user_xyz');
    });

    test('RPC: email yok, otomatik user_* → boş kalmaz (otomatik ad gösterilir)', () {
      final user = UserModel.fromJson(
        baseJson(username: 'user_abc123def', email: ''),
      );
      expect(user.username, 'user_abc123def');
    });

    test('RPC: email ve username yok → Balıkçı + id kuyruğu', () {
      final user = UserModel.fromJson(
        baseJson(username: null, email: '')
            ..['id'] = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      );
      expect(user.username, 'Balıkçı_eeeeee');
    });
  });

  group('UserModel.toJson', () {
    test('round-trip: fromJson → toJson → fromJson', () {
      final original = UserModel.fromJson(
        baseJson(username: 'BalikciTest', rank: 'usta', totalScore: 2500),
      );
      final json = original.toJson();
      final restored = UserModel.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.username, original.username);
      expect(restored.rank, original.rank);
      expect(restored.totalScore, original.totalScore);
    });

    test('toJson doğru key isimleri kullanır', () {
      final user = UserModel.fromJson(baseJson(username: 'Test'));
      final json = user.toJson();
      expect(json.containsKey('avatar_url'), isTrue);
      expect(json.containsKey('total_score'), isTrue);
      expect(json.containsKey('sustainability_score'), isTrue);
      expect(json.containsKey('fcm_token'), isTrue);
    });
  });

  group('UserModel rütbe değerleri', () {
    for (final rank in ['acemi', 'olta_kurdu', 'usta', 'deniz_reisi']) {
      test('$rank geçerli rütbe olarak parse edilir', () {
        final user = UserModel.fromJson(baseJson(rank: rank));
        expect(user.rank, rank);
      });
    }
  });
}
