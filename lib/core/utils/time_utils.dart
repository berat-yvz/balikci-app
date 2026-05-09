/// Tarih/saat yardımcı fonksiyonları — Türkçe arayüz için.
const _months = [
  'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
];

/// Verilen [dateTime] için kullanıcı dostu Türkçe geçmiş zaman metni döner.
///
/// - 1 dakikadan az  → "Az önce"
/// - 1–59 dakika     → "X dakika önce"
/// - 1–23 saat       → "X saat önce"
/// - 1–6 gün         → "X gün önce"
/// - 7+ gün          → "dd MMM" (örn. "3 Nis")
String timeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) return 'Az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
  if (diff.inHours < 24) return '${diff.inHours} saat önce';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';

  final month = _months[dateTime.month - 1];
  return '${dateTime.day} $month';
}
