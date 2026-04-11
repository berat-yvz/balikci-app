import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase Storage bucket adı — profil fotoğrafları (`avatars/{userId}/...`).
///
/// Projede bucket yoksa: `supabase/migrations/20260411_storage_users_avatars_bucket.sql`
/// dosyasını Supabase SQL Editor'da çalıştırın.
///
/// İsteğe bağlı: `.env` içinde mevcut bir bucket adı kullanmak için
/// `SUPABASE_AVATAR_BUCKET=senin-bucket-adin`
String avatarStorageBucket() {
  final fromEnv = dotenv.env['SUPABASE_AVATAR_BUCKET']?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  return 'users-avatars';
}
