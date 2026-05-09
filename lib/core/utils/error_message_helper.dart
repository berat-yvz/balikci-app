/// Teknik exception mesajlarını kullanıcı dostu Türkçeye çevirir.
///
/// 45+ yaş hedef kitle: sade, kısa, teknik terim içermeyen mesajlar.
class ErrorMessageHelper {
  const ErrorMessageHelper._();

  static String toUserMessage(
    dynamic error, {
    String fallback = 'Bir hata oluştu. Lütfen tekrar deneyin.',
  }) {
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
      return '📷 Fotoğraf yüklemesi engellendi.\n'
          'Supabase’de fish-photos politikalarının güncel olduğundan emin ol '
          '(bkz. migration `20260509000005_fix_fish_photos_storage_rls.sql`).';
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
      return '📝 Gönderi kaydı sunucu güvenlik kuralına takıldı.\n'
          'Çıkış yapıp tekrar dene; migration’ların uygulandığını kontrol et.';
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
