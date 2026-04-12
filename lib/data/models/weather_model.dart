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

  /// Open-Meteo `surface_pressure` (hPa), anlık.
  final double? pressureHpa;

  /// Yaklaşık 3 saat önceki basınç (saatlik diziden); trend için.
  final double? pressureHpa3hAgo;

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
    this.pressureHpa,
    this.pressureHpa3hAgo,
    int? weatherCode,
    required this.fishingSummary,
    required this.fetchedAt,
    required this.regionKey,
  }) : _weatherCode = weatherCode;

  // ── Computed getters ───────────────────────────────────────

  /// Sıcaklık °C. dataJson varsa direkt oku (units=metric → zaten Celsius).
  bool get _isOpenMeteoV1 =>
      dataJson != null && dataJson!['source'] == 'open_meteo_v1';

  double get tempCelsius {
    if (_isOpenMeteoV1) {
      return (temperature ?? 0).toDouble();
    }
    if (dataJson != null) {
      return (dataJson!['main']?['temp'] as num?)?.toDouble() ?? 0.0;
    }
    return (temperature ?? 0).toDouble();
  }

  /// Rüzgar km/h. Open-Meteo bundle’da zaten km/h; OpenWeather’da m/s → km/h.
  double get windKmh {
    if (_isOpenMeteoV1) {
      return (windspeed ?? 0).toDouble();
    }
    if (dataJson != null) {
      return ((dataJson!['wind']?['speed'] as num?)?.toDouble() ?? 0.0) * 3.6;
    }
    return (windspeed ?? 0).toDouble();
  }

  /// WMO (Open-Meteo) veya OpenWeather kodu.
  int? get weatherCode {
    if (_isOpenMeteoV1) {
      return _weatherCode;
    }
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
    if (dataJson != null && dataJson['source'] == 'open_meteo_v1') {
      final cur = dataJson['current'] as Map<String, dynamic>?;
      if (cur != null) {
        final pressureNow = (cur['surface_pressure'] as num?)?.toDouble();
        final pressure3h = _surfacePressure3hAgo(dataJson, cur);
        return WeatherModel(
          id: json['id'] as String? ?? '',
          lat: (json['lat'] as num?)?.toDouble() ??
              (dataJson['lat'] as num?)?.toDouble() ??
              0,
          lng: (json['lng'] as num?)?.toDouble() ??
              (dataJson['lng'] as num?)?.toDouble() ??
              0,
          dataJson: dataJson,
          temperature: (cur['temperature'] as num?)?.toDouble(),
          windspeed: (cur['windspeed'] as num?)?.toDouble(),
          windDirection: null,
          waveHeight: (cur['wave_height'] as num?)?.toDouble(),
          seaSurfaceTemperature:
              (cur['sea_surface_temperature'] as num?)?.toDouble(),
          precipitation: (cur['precipitation'] as num?)?.toDouble(),
          humidity: null,
          visibilityKm: (cur['visibility_m'] as num?) != null
              ? (cur['visibility_m'] as num).toDouble() / 1000
              : null,
          cloudCover: (cur['cloud_cover'] as num?)?.toDouble(),
          pressureHpa: pressureNow,
          pressureHpa3hAgo: pressure3h,
          weatherCode: (cur['weather_code'] as num?)?.toInt(),
          fishingSummary: json['fishing_summary'] as String?,
          fetchedAt: DateTime.parse(json['fetched_at'] as String),
          regionKey: json['region_key'] as String?,
        );
      }
    }

    final main = dataJson?['main'] as Map<String, dynamic>?;
    final wind = dataJson?['wind'] as Map<String, dynamic>?;
    final clouds = dataJson?['clouds'] as Map<String, dynamic>?;
    final rain = dataJson?['rain'] as Map<String, dynamic>?;
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
      pressureHpa:             null,
      pressureHpa3hAgo:        null,
      weatherCode:             null, // getter dataJson'dan okur
      fishingSummary:          json['fishing_summary'] as String?,
      fetchedAt:               DateTime.parse(json['fetched_at'] as String),
      regionKey:               json['region_key'] as String?,
    );
  }

  /// `hourly` içinde `current` ile aynı `time` satırını bulup 3 saat önceki `surface_pressure`.
  static double? _surfacePressure3hAgo(
    Map<String, dynamic> dataJson,
    Map<String, dynamic> current,
  ) {
    final hourly = dataJson['hourly'];
    if (hourly is! List || hourly.isEmpty) return null;
    final timeStr = current['time'] as String?;
    var idx = -1;
    if (timeStr != null) {
      for (var i = 0; i < hourly.length; i++) {
        final row = hourly[i];
        if (row is Map && row['time'] == timeStr) {
          idx = i;
          break;
        }
      }
    }
    if (idx < 0) {
      idx = hourly.length - 1;
    }
    final j = idx - 3;
    if (j < 0) return null;
    final prev = hourly[j];
    if (prev is! Map<String, dynamic>) return null;
    return (prev['surface_pressure'] as num?)?.toDouble();
  }
}
