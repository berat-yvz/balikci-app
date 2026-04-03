/// Hava durumu modeli — ARCHITECTURE.md `weather_cache` tablosu referans.
/// MVP_PLAN.md M-04 balıkçı dili çevirisi bu model üzerinden çalışır.
class WeatherModel {
  final String id;
  final double lat;
  final double lng;

  /// Ham OpenWeather response (JSONB). fromJson path'inde dolu,
  /// Drift cache path'inde null — getter'lar buna göre fallback yapar.
  final Map<String, dynamic>? dataJson;

  /// Drift cache path için stored alanlar (dataJson yoksa kullanılır).
  final double? temperature; // °C
  final double? windspeed; // km/h
  final int? windDirection; // derece
  final double? waveHeight; // metre
  final double? seaSurfaceTemperature; // °C
  final double? precipitation; // mm
  final double? humidity; // %
  final double? visibilityKm; // km
  final double? cloudCover; // %

  // weatherCode: getter olarak tanımlandı (aşağıya bak)
  final int? _weatherCode;

  final String? fishingSummary;
  final DateTime fetchedAt;

  /// "region_key" — weather_cache tablosunda unique.
  final String? regionKey;

  const WeatherModel({
    required this.id,
    required this.lat,
    required this.lng,
    this.dataJson,
    required this.temperature,
    required this.windspeed,
    required this.windDirection,
    required this.waveHeight,
    required this.seaSurfaceTemperature,
    required this.precipitation,
    required this.humidity,
    required this.visibilityKm,
    required this.cloudCover,
    int? weatherCode,
    required this.fishingSummary,
    required this.fetchedAt,
    required this.regionKey,
  }) : _weatherCode = weatherCode;

  // ── Computed getters ───────────────────────────────────────

  /// Sıcaklık °C. dataJson varsa direkt oku (units=metric → zaten Celsius).
  double get tempCelsius {
    if (dataJson != null) {
      return (dataJson!['main']?['temp'] as num?)?.toDouble() ?? 0.0;
    }
    return (temperature ?? 0).toDouble();
  }

  /// Rüzgar km/s. dataJson varsa m/s → km/s çevir.
  double get windKmh {
    if (dataJson != null) {
      return ((dataJson!['wind']?['speed'] as num?)?.toDouble() ?? 0.0) * 3.6;
    }
    return (windspeed ?? 0).toDouble();
  }

  /// OpenWeather hava kodu. dataJson['weather'][0]['id'], bulunamazsa 800.
  int? get weatherCode {
    if (dataJson != null) {
      final list = dataJson!['weather'];
      if (list is List && list.isNotEmpty) {
        return (list[0] as Map<String, dynamic>)['id'] as int? ?? 800;
      }
      return 800;
    }
    return _weatherCode;
  }

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final dataJson = json['data_json'] as Map<String, dynamic>?;
    final main     = dataJson?['main']   as Map<String, dynamic>?;
    final wind     = dataJson?['wind']   as Map<String, dynamic>?;
    final clouds   = dataJson?['clouds'] as Map<String, dynamic>?;
    final rain     = dataJson?['rain']   as Map<String, dynamic>?;
    final windSpeedMs = (wind?['speed'] as num?)?.toDouble();

    return WeatherModel(
      id:       json['id']  as String? ?? '',
      lat:      (json['lat'] as num?)?.toDouble() ?? 0,
      lng:      (json['lng'] as num?)?.toDouble() ?? 0,
      dataJson: dataJson,
      // Stored fields (getter'lar dataJson varken bunları kullanmaz,
      // Drift cache path için yedek olarak tutulur)
      temperature:             (main?['temp']     as num?)?.toDouble(),
      windspeed:               windSpeedMs != null ? windSpeedMs * 3.6 : null,
      windDirection:           (wind?['deg']      as num?)?.toInt(),
      waveHeight:              null,
      seaSurfaceTemperature:   null,
      precipitation:           (rain?['1h']       as num?)?.toDouble(),
      humidity:                (main?['humidity'] as num?)?.toDouble(),
      visibilityKm:            dataJson?['visibility'] != null
          ? (dataJson!['visibility'] as num).toDouble() / 1000
          : null,
      cloudCover:              (clouds?['all']    as num?)?.toDouble(),
      weatherCode:             null, // getter dataJson'dan okur
      fishingSummary:          json['fishing_summary'] as String?,
      fetchedAt:               DateTime.parse(json['fetched_at'] as String),
      regionKey:               json['region_key'] as String?,
    );
  }
}
