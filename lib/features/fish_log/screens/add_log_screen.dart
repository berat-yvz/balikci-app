import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../data/repositories/fish_log_repository.dart';

class AddLogScreen extends ConsumerStatefulWidget {
  const AddLogScreen({super.key});

  @override
  ConsumerState<AddLogScreen> createState() => _AddLogScreenState();
}

class _AddLogScreenState extends ConsumerState<AddLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedFishType;
  bool _isPrivate = false;
  bool _isReleased = false;
  bool _isLoading = false;
  File? _selectedImage;

  static const List<String> _fishTypes = [
    'Levrek',
    'Çipura',
    'Saroz',
    'Palamut',
    'Lüfer',
    'Kefal',
    'Alabalık',
    'Sazan',
    'Turna',
    'Zargana',
    'İstavrit',
    'Hamsi',
    'Kolyoz',
    'Orfoz',
    'Lahoz',
    'Diğer',
  ];

  @override
  void dispose() {
    _weightController.dispose();
    _lengthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked != null && mounted) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<String?> _uploadPhoto(File file) async {
    try {
      final userId = SupabaseService.auth.currentUser?.id ?? 'unknown';
      final fileName =
          'fish_logs/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupabaseService.storage.from('fish-photos').upload(fileName, file);
      return SupabaseService.storage
          .from('fish-photos')
          .getPublicUrl(fileName);
    } catch (_) {
      return null;
    }
  }

  /// Mevcut hava durumunu snapshot olarak Map'e çevirir.
  Map<String, dynamic>? _buildWeatherSnapshot() {
    final weatherData = ref.read(istanbulWeatherProvider).valueOrNull;
    final weather = weatherData?.current;
    if (weather == null) return null;
    return {
      'temperature': weather.tempCelsius,
      'windspeed': weather.windKmh,
      'wave_height': weather.waveHeight,
      'weather_code': weather.weatherCode,
      'lat': weatherData!.lat,
      'lng': weatherData.lng,
      'recorded_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFishType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen balık türü seçin',
              style: TextStyle(fontSize: 16)),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.auth.currentUser?.id ?? '';

      String? photoUrl;
      if (_selectedImage != null) {
        photoUrl = await _uploadPhoto(_selectedImage!);
      }

      final weatherSnapshot = _buildWeatherSnapshot();

      await FishLogRepository().createLog(
        userId: userId,
        species: _selectedFishType!,
        weightKg: _weightController.text.isNotEmpty
            ? double.tryParse(_weightController.text)
            : null,
        lengthCm: _lengthController.text.isNotEmpty
            ? double.tryParse(_lengthController.text)
            : null,
        photoUrl: photoUrl,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        isPrivate: _isPrivate,
        released: _isReleased,
        weatherSnapshot: weatherSnapshot,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt eklendi! 🎣',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt eklenemedi, tekrar deneyin',
                style: TextStyle(fontSize: 16)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Shared input decoration ─────────────────────────────
  InputDecoration _fieldDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 16, color: Color(0xFF8EA0B5)),
      filled: true,
      fillColor: const Color(0xFF132236),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF24415F), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF24415F), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.teal, width: 2),
      ),
    );
  }

  static const _labelStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Text(
          '🎣 Yeni Balık Kaydı',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Anlık hava durumu özeti ───────────────────
            _WeatherBanner(),
            const SizedBox(height: 16),

            // ── Fotoğraf seç ──────────────────────────────
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF132236),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.muted.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedImage == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 56, color: Color(0xFF8EA0B5)),
                          SizedBox(height: 8),
                          Text(
                            'Fotoğraf Ekle',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8EA0B5),
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // ── Balık türü ────────────────────────────────
            const Text('Balık Türü *', style: _labelStyle),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF132236),
                border: Border.all(color: AppColors.teal, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFishType,
                  dropdownColor: const Color(0xFF132236),
                  hint: const Text(
                    'Balık seçin...',
                    style: TextStyle(fontSize: 16, color: AppColors.muted),
                  ),
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down,
                      size: 32, color: AppColors.muted),
                  items: _fishTypes
                      .map(
                        (fish) => DropdownMenuItem(
                          value: fish,
                          child: Text(
                            fish,
                            style: const TextStyle(
                                fontSize: 16, color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _selectedFishType = val),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Ağırlık ve Uzunluk ────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ağırlık (kg)', style: _labelStyle),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white),
                        decoration: _fieldDecoration(hint: '0.0'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Uzunluk (cm)', style: _labelStyle),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _lengthController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white),
                        decoration: _fieldDecoration(hint: '0.0'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Geri bıraktım toggle ──────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isReleased
                    ? const Color(0xFF0B1C33)
                    : const Color(0xFF132236),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isReleased
                      ? AppColors.teal
                      : AppColors.muted.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.water, size: 32, color: AppColors.teal),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Geri bıraktım 🐟',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 1.3,
                    child: Switch(
                      value: _isReleased,
                      onChanged: (val) =>
                          setState(() => _isReleased = val),
                      activeThumbColor: AppColors.teal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Gizli kayıt toggle ────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isPrivate
                    ? const Color(0xFF0B1C33)
                    : const Color(0xFF132236),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isPrivate
                      ? AppColors.accent
                      : AppColors.muted.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 32, color: AppColors.accent),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Gizli kayıt',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 1.3,
                    child: Switch(
                      value: _isPrivate,
                      onChanged: (val) =>
                          setState(() => _isPrivate = val),
                      activeThumbColor: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Not alanı ─────────────────────────────────
            const Text('Not (isteğe bağlı)', style: _labelStyle),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(fontSize: 16, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nasıl bir gündü? Ne yedirdin?',
                hintStyle: const TextStyle(
                    fontSize: 16, color: Color(0xFF8EA0B5)),
                filled: true,
                fillColor: const Color(0xFF132236),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF24415F), width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF24415F), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.teal, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── KAYDET butonu ─────────────────────────────
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save, size: 28),
                label: Text(
                  _isLoading ? 'Kaydediliyor...' : 'KAYDET',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Kayıt formunun üstünde gösterilen küçük hava durumu özet kartı.
class _WeatherBanner extends ConsumerWidget {
  const _WeatherBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(istanbulWeatherProvider);

    return weatherAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (data) {
        final w = data.current;
        if (w == null) return const SizedBox.shrink();

        final temp = w.tempCelsius.toStringAsFixed(1);
        final wind = w.windKmh.toStringAsFixed(0);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2F47),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              const Text('☁️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.gpsUsed ? 'Konumunuzdaki Hava' : 'İstanbul Havası',
                      style: const TextStyle(
                        color: Color(0xFF8EA0B5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🌡 $temp°C  |  💨 $wind km/s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Otomatik kaydedilecek',
                style: TextStyle(
                  color: Color(0xFF8EA0B5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
