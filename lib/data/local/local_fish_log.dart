import 'package:isar/isar.dart';
import 'package:balikci_app/data/local/local_spot.dart';

part 'local_fish_log.g.dart';

/// Offline balık günlüğü — Isar şeması.
/// Offline-first: önce buraya yazılır, sync gelince Supabase'e gönderilir.
@collection
class LocalFishLog {
  Id get isarId => fastHash(id);

  late String id; // Geçici UUID (offline) veya Supabase UUID
  late String userId;
  String? spotId;
  late String species;
  double? weight;
  double? length;
  String? photoUrl;
  late bool isPrivate;
  late bool released;
  late DateTime createdAt;
  late bool synced; // false = sync kuyruğunda
}
