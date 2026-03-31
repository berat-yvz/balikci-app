import 'package:flutter/material.dart';

/// Balıkçı dili hava çevirisi çıktısı.
class BalikciWeather {
  final String icon;
  final String summary;
  final String fishingAdvice;
  final Color color;

  const BalikciWeather({
    required this.icon,
    required this.summary,
    required this.fishingAdvice,
    required this.color,
  });
}

/// Hava verisini "balıkçı dili" kurallarına göre çevirir.
class WeatherTranslator {
  const WeatherTranslator._();

  static BalikciWeather translate({
    required double windSpeedKmh,
    required double waveHeightM,
    required double tempC,
    int? weatherCode,
  }) {
    // weatherCode şu an kurallarda kullanılmıyor; ileride eklenebilir.
    // ignore: unused_element
    final _ = weatherCode;

    // 1) Fırtına / denize çıkma
    if (windSpeedKmh > 40) {
      return const BalikciWeather(
        icon: '⛔',
        summary: 'Fırtına var, denize çıkma!',
        fishingAdvice: 'Eve dön',
        color: Colors.red,
      );
    }

    // 2) Rüzgarlı
    if (windSpeedKmh > 25) {
      return const BalikciWeather(
        icon: '⚠️',
        summary: 'Rüzgarlı, dikkatli ol',
        fishingAdvice: 'Kıyıda kal',
        color: Colors.orange,
      );
    }

    // 3) Hafif rüzgar / düz mantık
    if (windSpeedKmh > 15) {
      return const BalikciWeather(
        icon: '🌬️',
        summary: 'Hafif rüzgar',
        fishingAdvice: 'Dikkatli avlan',
        color: Colors.yellow,
      );
    }

    // 4) Soğuk hava
    if (tempC < 5) {
      return const BalikciWeather(
        icon: '🥶',
        summary: 'Soğuk hava',
        fishingAdvice: 'Sıcak tut kendini',
        color: Colors.blue,
      );
    }

    // 5) Dalga kuralları (wave yüksekliğine göre)
    if (waveHeightM > 2.0) {
      return const BalikciWeather(
        icon: '🌊',
        summary: 'Deniz çok dalgalı',
        fishingAdvice: 'Tekneyle çıkma',
        color: Colors.red,
      );
    }

    if (waveHeightM > 1.0) {
      return const BalikciWeather(
        icon: '〰️',
        summary: 'Orta dalga',
        fishingAdvice: 'Deneyimliler için',
        color: Colors.orange,
      );
    }

    // 6) Tam uygun (düşük rüzgar + düşük dalga)
    if (windSpeedKmh <= 15 && waveHeightM <= 0.5) {
      return const BalikciWeather(
        icon: '🎣',
        summary: 'Harika av günü!',
        fishingAdvice: 'Erken çık, şans seninle',
        color: Colors.green,
      );
    }

    // 7) Default
    return const BalikciWeather(
      icon: '☀️',
      summary: 'Normal hava',
      fishingAdvice: 'İyi avlar!',
      color: Colors.green,
    );
  }
}

