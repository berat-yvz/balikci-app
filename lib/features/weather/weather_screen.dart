import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/utils/fishing_weather_utils.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:balikci_app/data/models/weather_model.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';

/// Detaylı hava durumu ekranı — H9 sprint.
class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  @override
  void initState() {
    super.initState();
    // Artık otomatik yükleme provider tarafından yapılıyor
  }

  Future<void> _onRefresh() async {
    await ref.read(istanbulWeatherProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final weatherAsync = ref.watch(istanbulWeatherProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hava Durumu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
            tooltip: 'Hava durumunu güncelle',
          ),
        ],
      ),
      body: weatherAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _EmptyWeather(onRetry: _onRefresh),
        data: (data) => RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── İstanbul saatlik tahmin ──────────────
              Text(
                'İstanbul',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              data.hourly.isEmpty
                  ? Text(
                      'Hava verisi alınamadı',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white70,
                      ),
                    )
                  : SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: data.hourly.length,
                        itemBuilder: (context, index) {
                          return _HourlyWeatherCard(hour: data.hourly[index]);
                        },
                      ),
                    ),
              const SizedBox(height: 24),

              if (data.current != null) ...[
                _WeatherHeroCard(weather: data.current!),
                const SizedBox(height: 16),
                _WeatherDetailGrid(weather: data.current!),
                const SizedBox(height: 16),
                _FishingTipsCard(weather: data.current!),
                const SizedBox(height: 16),
                _UpdateInfo(
                  weather: data.current!,
                  lastUpdated: data.lastUpdated,
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Alt widget'lar ──────────────────────────────────────────

class _HourlyWeatherCard extends StatelessWidget {
  final HourlyWeatherModel hour;
  const _HourlyWeatherCard({required this.hour});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${hour.time.hour.toString().padLeft(2, '0')}:00',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(hour.weatherEmoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            '${hour.temperature.round()}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${hour.windspeed.round()} km/s',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _WeatherHeroCard extends StatelessWidget {
  final WeatherModel weather;
  const _WeatherHeroCard({required this.weather});

  String _weatherIcon(int code) {
    if (code == 800) return '☀️';
    if (code > 800) return '⛅';
    if (code >= 700) return '🌫️';
    if (code >= 600) return '❄️';
    if (code >= 500) return '🌧️';
    if (code >= 300) return '🌦️';
    if (code >= 200) return '⛈️';
    return '🌤️';
  }

  Color _scoreColor(int score) {
    if (score >= 75) return AppColors.primary;
    if (score >= 50) return AppColors.accent;
    if (score >= 25) return const Color(0xFFE07B39);
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final score = FishingWeatherUtils.getFishingScore(weather);
    final summary = FishingWeatherUtils.getSummary(weather);
    final icon = _weatherIcon(weather.weatherCode ?? 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 8),
          Text(
            '${weather.tempCelsius.toStringAsFixed(1)}°C',
            style: AppTextStyles.h1.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            style: AppTextStyles.body.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _scoreColor(score).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _scoreColor(score).withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: Text(
              '${FishingWeatherUtils.getScoreEmoji(score)} '
              'Balıkçılık skoru: $score/100 — '
              '${FishingWeatherUtils.getScoreLabel(score)}',
              style: AppTextStyles.caption.copyWith(
                color: _scoreColor(score),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherDetailGrid extends StatelessWidget {
  final WeatherModel weather;
  const _WeatherDetailGrid({required this.weather});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        _DetailTile(
          icon: '💨',
          label: 'Rüzgar',
          value: '${weather.windKmh.toStringAsFixed(0)} km/s',
        ),
        _DetailTile(
          icon: '🌡️',
          label: 'Sıcaklık',
          value: '${weather.tempCelsius.toStringAsFixed(1)}°C',
        ),
        if (weather.waveHeight != null)
          _DetailTile(
            icon: '🌊',
            label: 'Dalga',
            value: '${weather.waveHeight!.toStringAsFixed(1)} m',
          ),
        _DetailTile(
          icon: '💧',
          label: 'Nem',
          value: weather.humidity != null
              ? '%${weather.humidity!.toStringAsFixed(0)}'
              : 'Veri yok',
        ),
        _DetailTile(
          icon: '👁️',
          label: 'Görüş',
          value: weather.visibilityKm != null
              ? '${weather.visibilityKm!.toStringAsFixed(1)} km'
              : 'Veri yok',
        ),
        _DetailTile(
          icon: '☁️',
          label: 'Bulutluluk',
          value: weather.cloudCover != null
              ? '%${weather.cloudCover!.toStringAsFixed(0)}'
              : 'Veri yok',
        ),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String icon, label, value;
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.muted.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FishingTipsCard extends StatelessWidget {
  final WeatherModel weather;
  const _FishingTipsCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final wind = weather.windKmh;
    final temp = weather.tempCelsius;

    final tips = <String>[];
    if (wind < 15) tips.add('✓ Rüzgar ideal seviyede');
    if (wind > 25) tips.add('⚠️ Rüzgar yüksek, dikkatli ol');
    if (temp >= 16 && temp <= 24) tips.add('✓ Su sıcaklığı balık için ideal');
    if (temp > 28) tips.add('⚠️ Çok sıcak, derin sulara bak');
    if (temp < 10) tips.add('⚠️ Soğuk su, yavaş balıklar');
    if (tips.isEmpty) tips.add('Koşullar ortalama, denemeye değer');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.muted.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balıkçı Tüyoları',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                tip,
                style: AppTextStyles.caption.copyWith(
                  color: tip.startsWith('✓')
                      ? AppColors.primary
                      : tip.startsWith('⚠️')
                      ? AppColors.accent
                      : Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateInfo extends StatelessWidget {
  final WeatherModel weather;
  final DateTime lastUpdated;
  const _UpdateInfo({required this.weather, required this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    final ago = DateTime.now().difference(lastUpdated);
    final label = ago.inMinutes < 60
        ? '${ago.inMinutes} dakika önce güncellendi'
        : '${ago.inHours} saat önce güncellendi';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.muted.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🕐', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWeather extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyWeather({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌐', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Hava verisi bulunamadı',
            style: AppTextStyles.h3.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Supabase weather_cache tablosu boş olabilir.\n'
            'Edge Function deploy edildi mi?',
            style: AppTextStyles.body.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
        ],
      ),
    );
  }
}
