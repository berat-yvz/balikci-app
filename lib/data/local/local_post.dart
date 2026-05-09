import 'package:drift/drift.dart';

/// Feed post'larının yerel önbellek tablosu — schemaVersion 8.
///
/// Supabase [posts] tablosunun istemci tarafı yansımasıdır.
/// [fishSpecies] TEXT[] dizisi JSON string olarak saklanır.
class LocalPosts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// Fotoğraf zorunlu (posts.photo_url NOT NULL ile eşleşir)
  TextColumn get photoUrl => text()();

  TextColumn get caption => text().nullable()();

  /// Supabase TEXT[] → JSON string (ör. '["levrek","çipura"]')
  TextColumn get fishSpecies => text().nullable()();

  TextColumn get spotId => text().nullable()();

  /// fishing_spots.privacy_level snapshot'ı (public/friends/private/vip)
  TextColumn get spotPrivacySnapshot =>
      text().withDefault(const Constant('public'))();

  TextColumn get spotDistrict => text().nullable()();

  IntColumn get likesCount => integer().withDefault(const Constant(0))();
  IntColumn get commentsCount => integer().withDefault(const Constant(0))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
