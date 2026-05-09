import 'package:drift/drift.dart';

/// Feed post'larının yerel önbellek tablosu — schemaVersion 8.
///
/// Supabase [posts] tablosunun istemci tarafı yansımasıdır.
/// Uygulama önce bu tabloyu okur; ağ varsa arka planda senkronize eder.
/// Yazar bilgisi (username, avatarUrl) denormalize olarak saklanır —
/// her post için ayrı JOIN yapma gereksinimi ortadan kalkar.
class LocalPosts extends Table {
  // ─── Kimlik ──────────────────────────────────────────────
  TextColumn get id => text()();
  TextColumn get userId => text()();

  // Denormalize yazar bilgisi (profil ekranı için JOIN'siz erişim)
  TextColumn get authorUsername => text().nullable()();
  TextColumn get authorAvatarUrl => text().nullable()();

  // ─── İçerik ──────────────────────────────────────────────
  TextColumn get caption => text().nullable()();
  TextColumn get photoUrl => text().nullable()();

  // ─── Balık bilgisi ────────────────────────────────────────
  TextColumn get fishSpecies => text().nullable()();
  RealColumn get fishWeight => real().nullable()();
  RealColumn get fishLength => real().nullable()();
  BoolColumn get fishReleased =>
      boolean().withDefault(const Constant(false))();

  // ─── Mera bilgisi ─────────────────────────────────────────
  // spot_id gizli olsa bile koordinatlar yaklaşık yayınlanabilir;
  // gerçek mera adı/ID'si FAZ 3 UI katmanında maskelenir.
  TextColumn get spotId => text().nullable()();
  RealColumn get spotLat => real().nullable()();
  RealColumn get spotLng => real().nullable()();

  // ─── Hava snapshot ───────────────────────────────────────
  TextColumn get weatherSnapshot => text().nullable()(); // JSON string

  // ─── Gizlilik & Tip ──────────────────────────────────────
  TextColumn get visibility =>
      text().withDefault(const Constant('public'))();
  TextColumn get postType =>
      text().withDefault(const Constant('catch'))();

  // ─── Sayaçlar ─────────────────────────────────────────────
  IntColumn get likesCount =>
      integer().withDefault(const Constant(0))();
  IntColumn get commentsCount =>
      integer().withDefault(const Constant(0))();

  // Oturum açık kullanıcının bu postu beğenip beğenmediği
  BoolColumn get isLikedByMe =>
      boolean().withDefault(const Constant(false))();

  // ─── Zaman damgaları ─────────────────────────────────────
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get cachedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
