import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:balikci_app/core/constants/app_constants.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/fish_log_model.dart';
import 'package:balikci_app/data/repositories/fish_log_repository.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';

// cleaned: liste/istatistik provider'larına autoDispose eklendi, read/watch sadeleştirildi

/// FishLogRepository provider.
final fishLogRepositoryProvider = Provider<FishLogRepository>((ref) {
  return FishLogRepository();
});

/// Giriş yapmış kullanıcının günlük kayıtları.
final myFishLogsProvider = FutureProvider.autoDispose<List<FishLogModel>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final repo = ref.read(fishLogRepositoryProvider);
  return repo.getLogs(user.id, limit: AppConstants.pageSize * 3);
});

/// Giriş yapmış kullanıcının günlük istatistikleri.
final fishLogStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return {
      'totalLogs': 0,
      'topSpecies': <Map<String, dynamic>>[],
      'bestSpotId': null,
      'totalWeightKg': 0.0,
    };
  }
  final repo = ref.read(fishLogRepositoryProvider);
  return repo.getStats(user.id);
});

/// Balık günlük işlemleri — kayıt ekleme vb.
class FishLogNotifier extends AsyncNotifier<void> {
  late final FishLogRepository _repo;
  final ImagePicker _picker = ImagePicker();

  @override
  void build() {
    _repo = ref.watch(fishLogRepositoryProvider);
  }

  Future<void> addLog({
    String? spotId,
    required String species,
    double? weightKg,
    double? lengthCm,
    String? notes,
    bool isPrivate = false,
    bool released = false,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw Exception('Günlük kaydı eklemek için önce giriş yapmalısın.');
    }

    state = const AsyncLoading();
    try {
      // Opsiyonel fotoğraf seçimi
      String? photoPathInBucket;

      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        if (fileSize > AppConstants.maxPhotoSizeBytes) {
          throw Exception(
            'Fotoğraf çok büyük. Lütfen 2MB altında bir fotoğraf seç.',
          );
        }

        final ext = pickedFile.path.split('.').last.toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
        final storagePath = 'fish_logs/${user.id}/$fileName';

        await SupabaseService.storage
            .from(AppConstants.photoBucket)
            .upload(storagePath, file);

        photoPathInBucket = storagePath;
      }

      // Hava snapshot'ı: basitçe en yakın weather_cache kaydını al.
      Map<String, dynamic>? weatherSnapshot;
      // Not: Mera/konum bilgisi olmadan hava snapshot'ı alınamaz;
      // ileride spot konumu veya kullanıcı konumu ile genişletilebilir.
      // Şimdilik boş bırakıyoruz.

      await _repo.createLog(
        userId: user.id,
        spotId: spotId,
        species: species,
        weightKg: weightKg,
        lengthCm: lengthCm,
        notes: notes,
        photoUrl: photoPathInBucket,
        weatherSnapshot: weatherSnapshot,
        isPrivate: isPrivate,
        released: released,
      );

      // Liste ve istatistik provider'larını tazele
      ref.invalidate(myFishLogsProvider);
      ref.invalidate(fishLogStatsProvider);

      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }
}

final fishLogNotifierProvider = AsyncNotifierProvider<FishLogNotifier, void>(
  FishLogNotifier.new,
);
