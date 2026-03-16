/// Uygulama genelinde kullanılan sabitler.
/// Supabase URL ve anon key .env'den okunacak (asla hard-code yapma!).
class AppConstants {
  AppConstants._();

  // Supabase — değerler runtime'da env'den gelecek
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Harita
  static const defaultLat = 41.015; // İstanbul
  static const defaultLng = 28.979;
  static const defaultZoom = 11.0;
  static const clusterZoomThreshold = 12.0; // bu zoom altında cluster aktif

  // Check-in
  static const checkinRadiusMeters = 500; // ±500m konum kontrolü
  static const checkinExpireHours = 2; // rapor "eski" olma süresi
  static const checkinRemoveHours = 6; // haritadan kalkma süresi

  // Oylama
  static const voteThresholdPercent = 0.70; // %70 yanlış → gizle

  // Fotoğraf
  static const maxPhotoSizeBytes = 2 * 1024 * 1024; // 2 MB
  static const photoBucket = 'fish-photos';

  // Pagination
  static const pageSize = 20;

  // HTTP
  static const httpTimeoutSeconds = 15;
}
