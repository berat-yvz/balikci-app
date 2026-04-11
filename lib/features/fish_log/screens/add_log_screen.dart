import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/score_service.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../data/repositories/fish_log_repository.dart';

/// ADIM 5: Balık kayıt formu — sadeleştirilmiş, hedef kitleye göre optimize.
class AddLogScreen extends ConsumerStatefulWidget {
  const AddLogScreen({super.key});

  @override
  ConsumerState<AddLogScreen> createState() => _AddLogScreenState();
}

class _AddLogScreenState extends ConsumerState<AddLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();

  // Opsiyonel alanlar (genişletilebilir bölüm)
  final _lengthController = TextEditingController();
  final _notesController = TextEditingController();
  final _locationNoteController = TextEditingController();

  String? _selectedFishType;
  bool _isPrivate = false;
  bool _isReleased = false;
  bool _isLoading = false;
  bool _showExtra = false; // "Daha Fazla Bilgi Ekle" açık mı?
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
    _locationNoteController.dispose();
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
          content: Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Balık türü seçin', style: TextStyle(fontSize: 16)),
          ]),
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

      final notes = [
        if (_notesController.text.isNotEmpty) _notesController.text,
        if (_locationNoteController.text.isNotEmpty)
          'Konum: ${_locationNoteController.text}',
      ].join(' | ');

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
        notes: notes.isNotEmpty ? notes : null,
        isPrivate: _isPrivate,
        released: _isReleased,
        weatherSnapshot: weatherSnapshot,
      );

      if (!_isPrivate) {
        final source =
            _isReleased ? ScoreSource.releaseExif : ScoreSource.fishLogPublic;
        unawaited(ScoreService.award(userId, source));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text('Kayıt eklendi! 🎣',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Yeni Balık Kaydı'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ── ADIM 5: Fotoğraf alanı en üstte, büyük (200dp), dashed border
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF132236),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.muted.withValues(alpha: 0.5),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 56,
                              color: AppColors.muted.withValues(alpha: 0.8)),
                          const SizedBox(height: 8),
                          const Text(
                            'Fotoğraf Ekle',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Galeriden seç',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  AppColors.muted.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: Colors.white),
                              onPressed: () =>
                                  setState(() => _selectedImage = null),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Balık türü — zorunlu, büyük dropdown
            const _FieldLabel(text: 'Balık Türü *'),
            const SizedBox(height: 8),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF132236),
                border: Border.all(color: AppColors.primary, width: 1.5),
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
                  style: const TextStyle(fontSize: 18, color: Colors.white),
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
                  onChanged: (val) => setState(() => _selectedFishType = val),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Ağırlık — zorunlu, büyük
            const _FieldLabel(text: 'Ağırlık (kg) *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              style: const TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '0.0',
                hintStyle: const TextStyle(
                    fontSize: 22, color: AppColors.muted),
                filled: true,
                fillColor: const Color(0xFF132236),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF24415F), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                suffixText: 'kg',
                suffixStyle: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),

            // ── "Daha Fazla Bilgi Ekle" genişletilebilir bölüm
            GestureDetector(
              onTap: () => setState(() => _showExtra = !_showExtra),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF132236),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.muted.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _showExtra
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.muted,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Daha Fazla Bilgi Ekle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _showExtra
                            ? Colors.white
                            : AppColors.muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'isteğe bağlı',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.muted.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Genişletilebilir bölüm içeriği
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _showExtra
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Uzunluk
                    const _FieldLabel(text: 'Boy (cm)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _lengthController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                          fontSize: 16, color: Colors.white),
                      decoration: _fieldDec(hint: '0.0', suffix: 'cm'),
                    ),
                    const SizedBox(height: 16),

                    // Geri bıraktım
                    _ToggleRow(
                      icon: Icons.water,
                      label: 'Geri bıraktım 🐟',
                      value: _isReleased,
                      onChanged: (v) => setState(() => _isReleased = v),
                      activeColor: AppColors.teal,
                    ),
                    const SizedBox(height: 12),

                    // Gizli kayıt
                    _ToggleRow(
                      icon: Icons.lock_outline,
                      label: 'Gizli kayıt',
                      value: _isPrivate,
                      onChanged: (v) => setState(() => _isPrivate = v),
                      activeColor: AppColors.secondary,
                    ),
                    const SizedBox(height: 16),

                    // Konum notu
                    const _FieldLabel(text: 'Konum Notu'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _locationNoteController,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                          fontSize: 16, color: Colors.white),
                      decoration: _fieldDec(hint: 'Hangi mera, köprü, koy?'),
                    ),
                    const SizedBox(height: 16),

                    // Not
                    const _FieldLabel(text: 'Not'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                          fontSize: 16, color: Colors.white),
                      decoration: _fieldDec(
                          hint: 'Nasıl bir gündü? Ne yedirdin?'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Hava durumu özeti
            _WeatherBanner(),
          ],
        ),
      ),
      // ── ADIM 5: Sticky kaydet butonu altta
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
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
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded, size: 26),
              label: Text(
                _isLoading ? 'Kaydediliyor...' : 'KAYDET',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDec({required String hint, String? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 16, color: Color(0xFF8EA0B5)),
      filled: true,
      fillColor: const Color(0xFF132236),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF24415F), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF24415F), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      suffixText: suffix,
      suffixStyle: const TextStyle(
          color: AppColors.muted, fontSize: 16, fontWeight: FontWeight.w600),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: value ? const Color(0xFF0B1C33) : const Color(0xFF132236),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? activeColor : AppColors.muted.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: activeColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
          Transform.scale(
            scale: 1.2,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: activeColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kayıt formunun altında gösterilen küçük hava durumu özet kartı.
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🌡 $temp°C  |  💨 $wind km/s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Otomatik kaydedilecek',
                style: TextStyle(color: Color(0xFF8EA0B5), fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
