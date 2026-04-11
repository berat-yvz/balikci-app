/// Kıyı bölgeleri — `fishing_spots` bu dikdörtgen içinde olan kullanıcılar
/// bölgesel sıralamaya dahil edilir (toplam puana göre).
class CoastalLeaderboardRegion {
  final String key;
  final String label;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const CoastalLeaderboardRegion({
    required this.key,
    required this.label,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });
}

/// [weather_regions.dart] merkezlerine yakın kutular (~80–120 km kenar).
const kCoastalLeaderboardRegions = <CoastalLeaderboardRegion>[
  CoastalLeaderboardRegion(
    key: 'istanbul',
    label: 'İstanbul & Marmara',
    minLat: 40.72,
    maxLat: 41.38,
    minLng: 27.85,
    maxLng: 30.05,
  ),
  CoastalLeaderboardRegion(
    key: 'izmir',
    label: 'İzmir & Ege kıyısı',
    minLat: 37.95,
    maxLat: 38.75,
    minLng: 26.55,
    maxLng: 27.65,
  ),
  CoastalLeaderboardRegion(
    key: 'antalya',
    label: 'Antalya',
    minLat: 36.55,
    maxLat: 37.15,
    minLng: 30.35,
    maxLng: 31.15,
  ),
  CoastalLeaderboardRegion(
    key: 'trabzon',
    label: 'Trabzon & Doğu Karadeniz',
    minLat: 40.72,
    maxLat: 41.35,
    minLng: 39.35,
    maxLng: 40.35,
  ),
  CoastalLeaderboardRegion(
    key: 'canakkale',
    label: 'Çanakkale',
    minLat: 39.95,
    maxLat: 40.45,
    minLng: 25.95,
    maxLng: 26.85,
  ),
  CoastalLeaderboardRegion(
    key: 'bodrum',
    label: 'Bodrum',
    minLat: 36.85,
    maxLat: 37.35,
    minLng: 27.05,
    maxLng: 27.75,
  ),
  CoastalLeaderboardRegion(
    key: 'fethiye',
    label: 'Fethiye',
    minLat: 36.45,
    maxLat: 36.85,
    minLng: 28.75,
    maxLng: 29.45,
  ),
  CoastalLeaderboardRegion(
    key: 'sinop',
    label: 'Sinop',
    minLat: 41.85,
    maxLat: 42.25,
    minLng: 34.75,
    maxLng: 35.45,
  ),
  CoastalLeaderboardRegion(
    key: 'samsun',
    label: 'Samsun',
    minLat: 41.05,
    maxLat: 41.55,
    minLng: 35.85,
    maxLng: 36.75,
  ),
  CoastalLeaderboardRegion(
    key: 'mersin',
    label: 'Mersin',
    minLat: 36.55,
    maxLat: 37.05,
    minLng: 34.35,
    maxLng: 35.05,
  ),
  CoastalLeaderboardRegion(
    key: 'mugla',
    label: 'Muğla kıyıları',
    minLat: 36.95,
    maxLat: 37.55,
    minLng: 27.95,
    maxLng: 28.85,
  ),
  CoastalLeaderboardRegion(
    key: 'balikesir',
    label: 'Balıkesir & Edremit körfezi',
    minLat: 39.35,
    maxLat: 40.05,
    minLng: 26.65,
    maxLng: 28.15,
  ),
];
