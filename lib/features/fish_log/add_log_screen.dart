import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/location_service.dart';
import 'package:balikci_app/core/services/weather_service.dart';
import 'package:balikci_app/data/local/database.dart';
import 'package:balikci_app/data/repositories/fish_log_repository.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/sync_provider.dart';

/// Günlük kayıt ekleme ekranı.
class AddLogScreen extends ConsumerStatefulWidget {
  final String? spotId;

  const AddLogScreen({super.key, this.spotId});

  @override
  ConsumerState<AddLogScreen> createState() => _AddLogScreenState();
}

class _AddLogScreenState extends ConsumerState<AddLogScreen> {
  // cleaned: offline-first kayıt + queue entegrasyonu eklendi
  final _formKey = GlobalKey<FormState>();
  final _speciesController = TextEditingController();
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isPrivate = false;
  bool _released = false;
  bool _saving = false;
  final _picker = ImagePicker();
  String? _selectedPhotoPath;

  static const _suggestedSpecies = <String>[
    'Levrek',
    'Çipura',
    'Hamsi',
    'Lüfer',
    'Palamut',
    'Karagöz',
    'İstavrit',
    'Barbun',
    'Kefal',
    'Kalkan',
  ];

  @override
  void dispose() {
    _speciesController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıt için önce giriş yapmalısın.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final species = _speciesController.text.trim();
    final weight = _weightController.text.trim().isEmpty
        ? null
        : double.tryParse(_weightController.text.trim());
    final length = _lengthController.text.trim().isEmpty
        ? null
        : double.tryParse(_lengthController.text.trim());
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    setState(() => _saving = true);
    try {
      final db = AppDatabase.instance;
      final repo = FishLogRepository();
      final syncService = ref.read(syncServiceProvider);
      final online = await _isOnline();
      final id = _uuidV4();
      final now = DateTime.now();

      Map<String, dynamic>? weatherSnapshot;
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final weather = await WeatherService.getWeatherForLocation(
          lat: position.latitude,
          lng: position.longitude,
        );
        if (weather != null) {
          weatherSnapshot = {
            'temperature': weather.temperature,
            'windspeed': weather.windspeed,
            'wave_height': weather.waveHeight,
            'humidity': weather.humidity,
            'region_key': weather.regionKey,
            'fetched_at': weather.fetchedAt.toIso8601String(),
          };
        }
      }

      String? finalPhotoUrl = _selectedPhotoPath;
      if (online && _selectedPhotoPath != null) {
        final file = File(_selectedPhotoPath!);
        if (await file.exists()) {
          final ext = _selectedPhotoPath!.split('.').last.toLowerCase();
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
          final storagePath = 'fish_logs/${user.id}/$fileName';
          await repo.uploadPhoto(file: file, storagePath: storagePath);
          finalPhotoUrl = storagePath;
        }
      }

      await db
          .into(db.localFishLogs)
          .insert(
            LocalFishLogsCompanion.insert(
              id: id,
              userId: user.id,
              spotId: Value(widget.spotId),
              species: species,
              weight: Value(weight),
              length: Value(length),
              photoUrl: Value(finalPhotoUrl),
              isPrivate: _isPrivate,
              isSynced: Value(online),
              createdAt: now,
            ),
          );

      final payload = {
        'id': id,
        'user_id': user.id,
        'spot_id': widget.spotId,
        'species': species,
        'weight': weight,
        'length': length,
        'notes': notes,
        'photo_url': finalPhotoUrl,
        'weather_snapshot': weatherSnapshot,
        'is_private': _isPrivate,
        'released': _released,
        'created_at': now.toIso8601String(),
      };

      if (online) {
        await repo.createLog(
          userId: user.id,
          spotId: widget.spotId,
          species: species,
          weightKg: weight,
          lengthCm: length,
          notes: notes,
          photoUrl: finalPhotoUrl,
          weatherSnapshot: weatherSnapshot,
          isPrivate: _isPrivate,
          released: _released,
        );
      } else {
        await syncService.enqueue('insert', 'fish_logs', payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Günlük kaydı kaydedildi ✓'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Günlük kaydı eklenemedi: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _selectedPhotoPath = picked.path);
  }

  Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int v) => v.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _saving;

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Av Kaydı')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  '📸 Fotoğrafınız EXIF ile doğrulanacak. Konum ve tarih bilgisi puan hesabını etkiler.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    _selectedPhotoPath == null
                        ? 'Fotoğraf Seç'
                        : 'Fotoğraf seçildi',
                  ),
                ),
                const SizedBox(height: 12),
                Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.toLowerCase();
                    if (query.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return _suggestedSpecies.where(
                      (s) => s.toLowerCase().contains(query),
                    );
                  },
                  onSelected: (value) {
                    _speciesController.text = value;
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        controller.text = _speciesController.text;
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: controller.text.length),
                        );
                        _speciesController.addListener(
                          () => controller.text = _speciesController.text,
                        );
                        return TextFormField(
                          controller: _speciesController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Tür (Levrek, Çipura, Hamsi...)',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Lütfen balık türünü yaz.';
                            }
                            return null;
                          },
                        );
                      },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Ağırlık (kg)',
                    hintText: 'Örn: 1.2',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lengthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Boy (cm)',
                    hintText: 'Örn: 35',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notlar (isteğe bağlı)',
                    hintText: 'Yem, takım, hava durumu notları...',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isPrivate,
                  onChanged: (v) {
                    setState(() => _isPrivate = v);
                  },
                  title: const Text('Gizli kayıt'),
                  subtitle: const Text(
                    'Gizli kayıtlar sadece senin profilinde görünür.',
                  ),
                ),
                SwitchListTile(
                  value: _released,
                  onChanged: (v) {
                    setState(() => _released = v);
                  },
                  title: const Text('Balığı geri saldım'),
                  subtitle: const Text('Sürdürülebilirlik puanını arttırır.'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Kaydı Oluştur'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
