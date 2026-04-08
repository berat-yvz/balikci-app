import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/app_constants.dart';
import 'package:balikci_app/core/services/location_service.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/core/services/score_service.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';
import 'package:balikci_app/data/repositories/notification_repository.dart';
import 'package:balikci_app/data/repositories/spot_repository.dart';
import 'package:image_picker/image_picker.dart';

/// Check-in ekranı — H5 sprint'i, H6 UI/UX iyileştirmeleri.
class CheckinScreen extends StatefulWidget {
  final String spotId;
  const CheckinScreen({super.key, required this.spotId});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final _spotRepo = SpotRepository();
  final _checkinRepo = CheckinRepository();

  SpotModel? _spot;
  CheckinModel? _createdCheckin;
  bool _loadingSpot = true;
  bool _submitting = false;

  XFile? _pickedPhoto;

  // DB kısıtları: crowd_level IN ('yoğun','normal','az','boş')
  String _crowdLevel = 'normal';
  // DB kısıtları: fish_density IN ('yoğun','normal','az','yok')
  String _fishDensity = 'normal';

  @override
  void initState() {
    super.initState();
    _loadSpot();
  }

  Future<void> _loadSpot() async {
    setState(() => _loadingSpot = true);
    final spot = await _spotRepo.getSpotById(widget.spotId);
    if (!mounted) return;
    setState(() {
      _spot = spot;
      _loadingSpot = false;
    });
  }

  double _distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLng = (lng2 - lng1) * (math.pi / 180.0);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    if (photo == null) return;
    setState(() => _pickedPhoto = photo);
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera);
    if (!mounted) return;
    if (photo == null) return;
    setState(() => _pickedPhoto = photo);
  }

  Future<void> _submitCheckin() async {
    final uid = SupabaseService.auth.currentUser?.id;
    final spot = _spot;
    if (uid == null || spot == null) return;

    setState(() => _submitting = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;

      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konum alınamadı. Izin veya GPS kontrol edin.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      final distMeters = _distanceMeters(
        lat1: spot.lat,
        lng1: spot.lng,
        lat2: pos.latitude,
        lng2: pos.longitude,
      );

      if (distMeters > AppConstants.checkinRadiusMeters) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Konum mera'dan fazla uzak (yaklasik ${distMeters.toStringAsFixed(0)}m).",
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      final created = await _checkinRepo.addCheckin({
        'user_id': uid,
        'spot_id': widget.spotId,
        'crowd_level': _crowdLevel,
        'fish_density': _fishDensity,
        'photo_url': null,
        'exif_verified': false,
        'is_active': true,
      });

      if (created == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirim gönderilemedi'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      if (_pickedPhoto != null) {
        final parts = _pickedPhoto!.path.split('.');
        final ext = parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
        final photoPath = 'checkins/${created.id}/photo.$ext';

        await SupabaseService.storage
            .from(AppConstants.photoBucket)
            .upload(photoPath, File(_pickedPhoto!.path));

        await _checkinRepo.updateCheckinPhotoUrl(
          checkinId: created.id,
          photoUrl: photoPath,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bildirim gönderildi ✓'),
          backgroundColor: AppColors.primary,
        ),
      );

      setState(() {
        _createdCheckin = created;
      });

      // Kullanıcıya check-in puanı ver (EXIF doğrulaması yoksa unverified)
      unawaited(ScoreService.award(uid, ScoreSource.checkinUnverified));

      // Mera sahibi farklı biriyse ona bildirim gönder
      if (spot.userId != uid) {
        unawaited(
          NotificationRepository().sendNotification(
            userId: spot.userId,
            title: '🎣 Meranızda Balık Var!',
            body: '${spot.name} merasında yeni bildirim geldi.',
            data: {'type': 'checkin', 'spot_id': spot.id},
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bildirim gönderilemedi: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spot = _spot;
    final canSubmit = !_loadingSpot && spot != null && !_submitting;

    // ── Başarı durumu ──────────────────────────────────────────────────────
    if (_createdCheckin != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bildirim Gönderildi ✓')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('✅', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 20),
                const Text(
                  'Bildiriminiz İletildi!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Haritada aktif olarak görünüyor.\nDiğer balıkçılar sizi görüyor.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _CheckinResultCard(checkin: _createdCheckin!),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => context.pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text(
                      'Haritaya Dön',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Balık Bildirimi'),
        bottom: spot == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '📍 ${spot.name}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
      ),
      body: _loadingSpot
          ? const Center(child: CircularProgressIndicator())
          : spot == null
          ? const Center(child: Text('Mera bulunamadı.'))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    // Konum bilgi satırı
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.teal,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Mera yakınında olduğunuz otomatik kontrol edilecek.',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.foam.withValues(alpha: 0.80),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Balık yoğunluğu — 2×2 grid
                    _GridSelector(
                      label: 'Balık Yoğunluğu',
                      options: const ['yok', 'az', 'normal', 'yoğun'],
                      displayLabels: const [
                        '❌\nBalık Yok',
                        '🐟\nAz Balık',
                        '🐟🐟\nNormal',
                        '🐟🐟🐟\nÇok Balık',
                      ],
                      value: _fishDensity,
                      onChanged: (v) => setState(() => _fishDensity = v),
                    ),
                    const SizedBox(height: 4),

                    // Kalabalık — 2×2 grid
                    _GridSelector(
                      label: 'Kalabalık Durumu',
                      options: const ['boş', 'az', 'normal', 'yoğun'],
                      displayLabels: const [
                        '🏖️\nBoş',
                        '👤\nSakin',
                        '👥\nNormal',
                        '👥👥\nKalabalık',
                      ],
                      value: _crowdLevel,
                      onChanged: (v) => setState(() => _crowdLevel = v),
                    ),
                    const SizedBox(height: 8),

                    // Fotoğraf
                    Text(
                      'Fotoğraf Ekle (İsteğe Bağlı)',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _submitting ? null : _pickPhoto,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Galeri'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _submitting ? null : _takePhoto,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Kamera'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_pickedPhoto != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_pickedPhoto!.path),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (_pickedPhoto != null) const SizedBox(height: 20),

                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: canSubmit ? _submitCheckin : null,
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Konumu Doğrula ve Bildir',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.pop(false),
                      child: const Text('İptal'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Grid Selector (2×2) ───────────────────────────────────────────────────────
/// 4 seçeneği 2×2 grid olarak gösterir — 45+ kullanıcı için geniş dokunma alanı.

class _GridSelector extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> displayLabels;
  final String value;
  final ValueChanged<String> onChanged;

  const _GridSelector({
    required this.label,
    required this.options,
    required this.displayLabels,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _GridCell(
              displayLabel: displayLabels[0],
              isSelected: options[0] == value,
              onTap: () => onChanged(options[0]),
            ),
            const SizedBox(width: 8),
            _GridCell(
              displayLabel: displayLabels[1],
              isSelected: options[1] == value,
              onTap: () => onChanged(options[1]),
            ),
            const SizedBox(width: 8),
            _GridCell(
              displayLabel: displayLabels[2],
              isSelected: options[2] == value,
              onTap: () => onChanged(options[2]),
            ),
            const SizedBox(width: 8),
            _GridCell(
              displayLabel: displayLabels[3],
              isSelected: options[3] == value,
              onTap: () => onChanged(options[3]),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _GridCell extends StatelessWidget {
  final String displayLabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _GridCell({
    required this.displayLabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 76,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.muted.withValues(alpha: 0.30),
              width: isSelected ? 2.0 : 1.0,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              displayLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isSelected ? AppColors.primary : AppColors.muted,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Check-in Sonuç Kartı ──────────────────────────────────────────────────────

class _CheckinResultCard extends StatelessWidget {
  final CheckinModel checkin;
  const _CheckinResultCard({required this.checkin});

  Color _densityColor(String? val) => switch (val) {
        'yoğun' => AppColors.primary,
        'normal' => const Color(0xFF378ADD),
        'az' => AppColors.accent,
        _ => AppColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          _ResultRow(
            label: 'Balık yoğunluğu',
            value: checkin.fishDensity ?? '-',
            dotColor: _densityColor(checkin.fishDensity),
          ),
          const Divider(height: 16, thickness: 0.5),
          _ResultRow(
            label: 'Kalabalık',
            value: checkin.crowdLevel ?? '-',
            dotColor: AppColors.muted,
          ),
          const Divider(height: 16, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Doğrulanma',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF0F6E56),
                  fontWeight: FontWeight.w600,
                ),
              ),
              _VerifiedBadge(exifVerified: checkin.exifVerified),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color dotColor;
  const _ResultRow({
    required this.label,
    required this.value,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF0F6E56),
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ]),
      ],
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  final bool exifVerified;
  const _VerifiedBadge({required this.exifVerified});

  @override
  Widget build(BuildContext context) {
    if (exifVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Text(
          '✓ Doğrulandı',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        '⏳ Doğrulama bekleniyor',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

