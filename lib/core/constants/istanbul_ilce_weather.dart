/// İstanbul ilçe merkezleri — Open-Meteo saatlik tahmin için `weather_cache.region_key`.
/// Anahtar: `istanbul_ilce_<slug>` (Edge Function ile birebir aynı olmalı).
class IstanbulIlceWeatherPoint {
  final String regionKey;
  final String displayName;
  final double lat;
  final double lng;

  const IstanbulIlceWeatherPoint({
    required this.regionKey,
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}

/// Yaklaşık ilçe merkezleri; mera koordinatına en yakın ilçe seçilir.
const List<IstanbulIlceWeatherPoint> istanbulIlceWeatherPoints = [
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_adalar',
    displayName: 'Adalar',
    lat: 40.87,
    lng: 29.12,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_arnavutkoy',
    displayName: 'Arnavutköy',
    lat: 41.1844,
    lng: 28.7344,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_atasehir',
    displayName: 'Ataşehir',
    lat: 40.9833,
    lng: 29.1167,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_avcilar',
    displayName: 'Avcılar',
    lat: 41.0214,
    lng: 28.7256,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_bagcilar',
    displayName: 'Bağcılar',
    lat: 41.0392,
    lng: 28.8564,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_bahcelievler',
    displayName: 'Bahçelievler',
    lat: 41.0028,
    lng: 28.8597,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_bakirkoy',
    displayName: 'Bakırköy',
    lat: 40.9819,
    lng: 28.8742,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_basaksehir',
    displayName: 'Başakşehir',
    lat: 41.0911,
    lng: 28.8028,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_bayrampasa',
    displayName: 'Bayrampaşa',
    lat: 41.0342,
    lng: 28.9142,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_besiktas',
    displayName: 'Beşiktaş',
    lat: 41.0422,
    lng: 29.0069,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_beyoglu',
    displayName: 'Beyoğlu',
    lat: 41.0369,
    lng: 28.985,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_beykoz',
    displayName: 'Beykoz',
    lat: 41.138,
    lng: 29.0911,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_beylikduzu',
    displayName: 'Beylikdüzü',
    lat: 41.0061,
    lng: 28.6397,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_buyukcekmece',
    displayName: 'Büyükçekmece',
    lat: 41.0203,
    lng: 28.5847,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_catalca',
    displayName: 'Çatalca',
    lat: 41.1486,
    lng: 28.4611,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_cekmekoy',
    displayName: 'Çekmeköy',
    lat: 41.0322,
    lng: 29.1781,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_esenler',
    displayName: 'Esenler',
    lat: 41.0431,
    lng: 28.8775,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_esenyurt',
    displayName: 'Esenyurt',
    lat: 41.0344,
    lng: 28.6775,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_eyupsultan',
    displayName: 'Eyüpsultan',
    lat: 41.1736,
    lng: 28.935,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_fatih',
    displayName: 'Fatih',
    lat: 41.0136,
    lng: 28.9497,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_gaziosmanpasa',
    displayName: 'Gaziosmanpaşa',
    lat: 41.0675,
    lng: 28.9181,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_gungoren',
    displayName: 'Güngören',
    lat: 41.0325,
    lng: 28.8769,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_kadikoy',
    displayName: 'Kadıköy',
    lat: 40.9903,
    lng: 29.0292,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_kagithane',
    displayName: 'Kağıthane',
    lat: 41.0711,
    lng: 28.9753,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_kartal',
    displayName: 'Kartal',
    lat: 40.91,
    lng: 29.1889,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_kucukcekmece',
    displayName: 'Küçükçekmece',
    lat: 41.0025,
    lng: 28.7756,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_maltepe',
    displayName: 'Maltepe',
    lat: 40.9369,
    lng: 29.1306,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_pendik',
    displayName: 'Pendik',
    lat: 40.8778,
    lng: 29.2356,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_sancaktepe',
    displayName: 'Sancaktepe',
    lat: 40.9931,
    lng: 29.2242,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_sariyer',
    displayName: 'Sarıyer',
    lat: 41.1078,
    lng: 29.0569,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_silivri',
    displayName: 'Silivri',
    lat: 41.0733,
    lng: 28.2464,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_sile',
    displayName: 'Şile',
    lat: 41.1753,
    lng: 29.6131,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_sultanbeyli',
    displayName: 'Sultanbeyli',
    lat: 40.9647,
    lng: 29.2797,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_sultangazi',
    displayName: 'Sultangazi',
    lat: 41.1058,
    lng: 28.8714,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_sisli',
    displayName: 'Şişli',
    lat: 41.0603,
    lng: 28.9878,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_tuzla',
    displayName: 'Tuzla',
    lat: 40.8169,
    lng: 29.3031,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_umraniye',
    displayName: 'Ümraniye',
    lat: 41.025,
    lng: 29.1236,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_uskudar',
    displayName: 'Üsküdar',
    lat: 41.0214,
    lng: 29.0156,
  ),
  IstanbulIlceWeatherPoint(
    regionKey: 'istanbul_ilce_zeytinburnu',
    displayName: 'Zeytinburnu',
    lat: 40.9906,
    lng: 28.9039,
  ),
];
