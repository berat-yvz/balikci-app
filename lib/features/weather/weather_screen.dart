import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/location_service.dart';
import 'package:balikci_app/core/services/weather_service.dart';
import 'package:balikci_app/core/utils/weather_translator.dart';
import 'package:balikci_app/data/models/weather_model.dart';

/// Hava durumu detay ekranı.
class WeatherScreen extends StatefulWidget {
  // cleaned: H9 için tam hava durumu ekranı uygulandı
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  WeatherModel? _weather;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        throw Exception('Konum alınamadı. Lütfen konum iznini kontrol et.');
      }
      final weather = await WeatherService.getWeatherForLocation(
        lat: pos.latitude,
        lng: pos.longitude,
      );
      if (weather == null) {
        throw Exception('Bölgene ait hava verisi bulunamadı.');
      }
      if (!mounted) return;
      setState(() => _weather = weather);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _regionToTr(String? key) {
    final raw = (key ?? 'bilinmiyor').toLowerCase();
    if (raw.contains('karadeniz')) return 'Karadeniz Bölgesi';
    if (raw.contains('marmara')) return 'Marmara Bölgesi';
    if (raw.contains('ege')) return 'Ege Bölgesi';
    if (raw.contains('akdeniz')) return 'Akdeniz Bölgesi';
    if (raw.contains('ic_anadolu') || raw.contains('iç_anadolu')) {
      return 'İç Anadolu Bölgesi';
    }
    if (raw.contains('dogu_anadolu') || raw.contains('doğu_anadolu')) {
      return 'Doğu Anadolu Bölgesi';
    }
    if (raw.contains('guneydogu') || raw.contains('güneydoğu')) {
      return 'Güneydoğu Anadolu Bölgesi';
    }
    return key ?? 'Bilinmiyor';
  }

  String _ago(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'az önce';
    return '${diff.inMinutes} dk önce';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weather = _weather;
    final translated = weather == null
        ? null
        : WeatherTranslator.translate(
            windSpeedKmh: weather.windspeed ?? 0,
            waveHeightM: weather.waveHeight ?? 0,
            tempC: weather.temperature ?? 0,
            weatherCode: weather.weatherCode,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Hava Durumu')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: AppTextStyles.body),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadWeather,
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            )
          : weather == null || translated == null
          ? const Center(child: Text('Hava verisi bulunamadı.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: translated.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: translated.color.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            translated.icon,
                            style: const TextStyle(fontSize: 64),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              translated.summary,
                              style: AppTextStyles.h2.copyWith(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        translated.fishingAdvice,
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Son güncelleme: ${_ago(weather.fetchedAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _WeatherTile(
                      icon: '🌡️',
                      label: 'Sıcaklık',
                      value:
                          '${(weather.temperature ?? 0).toStringAsFixed(1)} °C',
                    ),
                    _WeatherTile(
                      icon: '💨',
                      label: 'Rüzgar',
                      value:
                          '${(weather.windspeed ?? 0).toStringAsFixed(1)} km/h',
                    ),
                    _WeatherTile(
                      icon: '🌊',
                      label: 'Dalga',
                      value: weather.waveHeight == null
                          ? '-'
                          : '${weather.waveHeight!.toStringAsFixed(1)} m',
                    ),
                    _WeatherTile(
                      icon: '💧',
                      label: 'Nem',
                      value: weather.humidity == null
                          ? '-'
                          : '%${weather.humidity!.toStringAsFixed(0)}',
                    ),
                    _WeatherTile(
                      icon: '👁️',
                      label: 'Görüş',
                      value: weather.visibilityKm == null
                          ? '-'
                          : '${weather.visibilityKm!.toStringAsFixed(1)} km',
                    ),
                    _WeatherTile(
                      icon: '☁️',
                      label: 'Bulutluluk',
                      value: weather.cloudCover == null
                          ? '-'
                          : '%${weather.cloudCover!.toStringAsFixed(0)}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '📍 Bölge: ${_regionToTr(weather.regionKey)}',
                      style: AppTextStyles.body.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _WeatherTile extends StatelessWidget {
  const _WeatherTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
