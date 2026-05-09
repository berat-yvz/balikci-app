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
