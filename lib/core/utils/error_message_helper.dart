import 'package:supabase_flutter/supabase_flutter.dart';

/// Teknik exception mesajlarını kullanıcı dostu Türkçeye çevirir.
///
/// 45+ yaş hedef kitle: sade, kısa, teknik terim içermeyen mesajlar.
class ErrorMessageHelper {
  const ErrorMessageHelper._();

  static String toUserMessage(
    dynamic error, {
    String fallback = 'Bir hata oluştu. Lütfen tekrar deneyin.',
  }) {
    if (error is PostgrestException) {
      final code = error.code;
      final details = (error.details ?? '').toString().toLowerCase();
      final message = error.message.toLowerCase();
      if (code == '42501' ||
          message.contains('row-level security') ||
          message.contains('new row violates row-level security') ||
          message.contains('permission denied for') ||
          details.contains('row-level security')) {
        return 'Gönderi oluşturulamadı, tekrar giriş yapmayı dene';
      }
      // Örn. users.bio seçiliyken sunucuda kolon yok → profil / arkadaş listesi patlar
      if (message.contains('does not exist') &&
          message.contains('column')) {
        return 'Profil verisi sunucuda güncelleniyor olabilir.\n'
            'Bir süre sonra tekrar dene veya uygulamayı son sürüme güncelle.';
      }
    }

    if (error is StorageException) {
      final blob = '${error.message} ${error.statusCode}'.toLowerCase();
      if (blob.contains('403') ||
          blob.contains('forbidden') ||
          blob.contains('policy') ||
          blob.contains('row-level security')) {
        return 'Gönderi oluşturulamadı, tekrar giriş yapmayı dene';
      }
      return 'Fotoğraf yüklenemedi, internet bağlantını kontrol et';
    }

    final msg = error.toString().toLowerCase();

    if (msg.contains('socket') ||
        msg.contains('host lookup') ||
        msg.contains('network') ||
        msg.contains('errno = 7') ||
        msg.contains('errno=7') ||
        msg.contains('connection refused') ||
        msg.contains('failed host') ||
        msg.contains('no address associated') ||
        msg.contains('clientexception') ||
        msg.contains('failed to connect')) {
      return '📵 İnternet bağlantısı yok.\nBağlantını kontrol edip tekrar dene.';
    }

    if (msg.contains('timeout') || msg.contains('timed out')) {
      return '⏱️ Bağlantı zaman aşımına uğradı.\nLütfen tekrar dene.';
    }

    if (msg.contains('401') ||
        msg.contains('unauthorized') ||
        msg.contains('jwt')) {
      return '🔐 Oturum süresi dolmuş.\nLütfen tekrar giriş yap.';
    }

    if (msg.contains('500') ||
        msg.contains('503') ||
        msg.contains('server error')) {
      return '🔧 Sunucu şu an meşgul.\nBiraz bekleyip tekrar dene.';
    }

    // PostgREST: tablo şema önbelleğinde yok (migration uygulanmamış projeler)
    if (msg.contains('pgrst205') ||
        (msg.contains('could not find the table') &&
            (msg.contains('posts') ||
                msg.contains('post_comments') ||
                msg.contains('post_likes')))) {
      return '🛠️ Yorum veya beğeni için gerekli tablolar sunucuda eksik.\n\n'
          'Supabase Dashboard → SQL Editor’da şunu çalıştırın:\n'
          '`20260509120000_ensure_post_likes_post_comments.sql`\n\n'
          'veya terminalde proje kökünde: `supabase db push`.\n'
          'Sonra Dashboard → Settings → API → Reload schema (veya birkaç dk bekleyin).';
    }

    if (msg.contains('not found') || msg.contains('404')) {
      return '🔍 İstenen veri bulunamadı.';
    }

    // Supabase Storage — MIME / boyut / politika
    if (msg.contains('mime') ||
        msg.contains('invalid mime') ||
        msg.contains('content-type') ||
        msg.contains('invalid upload')) {
      return '📷 Fotoğraf sunucuya uygun formatta gitmedi.\n'
          'Başka bir JPG veya PNG dene (veya galeriden seç).';
    }

    if (msg.contains('413') ||
        msg.contains('payload too large') ||
        msg.contains('entity too large')) {
      return '📷 Fotoğraf çok büyük.\nDaha küçük bir görsel seç.';
    }

    if ((msg.contains('storage') || msg.contains('bucket')) &&
        (msg.contains('403') ||
            msg.contains('forbidden') ||
            msg.contains('policy') ||
            msg.contains('row-level security'))) {
      return 'Gönderi oluşturulamadı, tekrar giriş yapmayı dene';
    }

    // posts.user_id → users(id)
    if (msg.contains('foreign key') ||
        msg.contains('23503') ||
        (msg.contains('posts') &&
            msg.contains('violates') &&
            msg.contains('users'))) {
      return '👤 Hesap kaydı eksik görünüyor.\n'
          'Çıkış yapıp tekrar giriş yap; sorun sürerse destek al.';
    }

    // posts INSERT RLS
    if (msg.contains('row-level security') && msg.contains('posts')) {
      return 'Gönderi oluşturulamadı, tekrar giriş yapmayı dene';
    }

    // Genel yetki / JWT
    if (msg.contains('jwt expired') ||
        msg.contains('invalid jwt') ||
        (msg.contains('401') &&
            (msg.contains('postgrest') || msg.contains('pgrst')))) {
      return 'Gönderi oluşturulamadı, tekrar giriş yapmayı dene';
    }

    return fallback;
  }

  static bool isNetworkError(dynamic error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('socket') ||
        msg.contains('host lookup') ||
        msg.contains('errno = 7') ||
        msg.contains('errno=7') ||
        msg.contains('network') ||
        msg.contains('failed host') ||
        msg.contains('no address associated') ||
        msg.contains('clientexception') ||
        msg.contains('failed to connect');
  }
}
