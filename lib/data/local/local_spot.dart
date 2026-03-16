import 'package:isar/isar.dart';

part 'local_spot.g.dart';

/// Offline mera cache — Isar şeması.
/// Supabase'den çekilen meraları yerel olarak saklar.
@collection
class LocalSpot {
  Id get isarId => fastHash(id);

  late String id; // Supabase UUID
  late String name;
  late double lat;
  late double lng;
  late String privacyLevel;
  String? type;
  String? description;
  late bool verified;
  late DateTime createdAt;
  late DateTime cachedAt;
}

/// String'den int ID üretimi (Isar için).
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;
  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }
  return hash;
}
