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
import 'package:balikci_app/data/repositories/checkin_repository.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Balık Bildirimi')),
      body: _loadingSpot
          ? const Center(child: CircularProgressIndicator())
          : spot == null
          ? const Center(child: Text('Mera bulunamadi.'))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    Text(spot.name, style: AppTextStyles.h2),
                    const SizedBox(height: 8),
                    Text(
                      'Konum dogrulama: GPS ±${AppConstants.checkinRadiusMeters}m',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 16),

                    _SegmentSelector(
                      label: 'Balık yoğunluğu',
                      options: const ['yok', 'az', 'normal', 'yoğun'],
                      displayLabels: const ['Yok', 'Az', 'Normal', 'Yoğun'],
                      value: _fishDensity,
                      onChanged: (v) => setState(() => _fishDensity = v),
                    ),
                    _SegmentSelector(
                      label: 'Kalabalık',
                      options: const ['boş', 'az', 'normal', 'yoğun'],
                      displayLabels: const ['Boş', 'Az', 'Normal', 'Yoğun'],
                      value: _crowdLevel,
                      onChanged: (v) => setState(() => _crowdLevel = v),
                    ),

                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _pickPhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Fotoğraf seç'),
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
                    ElevatedButton(
                      onPressed: canSubmit ? _submitCheckin : null,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Konumu Doğrula ve Bildir'),
                    ),

                    const SizedBox(height: 12),
                    if (_createdCheckin != null) ...[
                      const SizedBox(height: 4),
                      _CheckinResultCard(checkin: _createdCheckin!),
                      const SizedBox(height: 12),
                      _VoteSection(
                        checkinId: _createdCheckin!.id,
                        onHidden: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Bildirim gizlendi, haritaya dönülüyor.'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                          final router = GoRouter.of(context);
                          Future.delayed(
                            const Duration(seconds: 1),
                            () { if (mounted) router.pop(); },
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    TextButton(
                      onPressed: () => context.pop(false),
                      child: const Text('Iptal'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Segment Selector ──────────────────────────────────────────────────────────

class _SegmentSelector extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> displayLabels;
  final String value;
  final ValueChanged<String> onChanged;

  const _SegmentSelector({
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
          style: AppTextStyles.caption.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(options.length, (i) {
            final isSelected = options[i] == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(options[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: EdgeInsets.only(right: i < options.length - 1 ? 4 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryLight : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.muted.withValues(alpha: 0.4),
                      width: isSelected ? 1.5 : 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    displayLabels[i],
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.muted,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
      ],
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
              Text(
                'Doğrulanma',
                style: AppTextStyles.caption.copyWith(color: AppColors.muted),
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
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.muted)),
        Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
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
        '⏳ EXIF bekleniyor',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Oy Bölümü ─────────────────────────────────────────────────────────────────

class _VoteSection extends StatefulWidget {
  final String checkinId;
  final VoidCallback? onHidden;
  const _VoteSection({required this.checkinId, this.onHidden});

  @override
  State<_VoteSection> createState() => _VoteSectionState();
}

class _VoteSectionState extends State<_VoteSection> {
  final _repo = CheckinRepository();
  bool _voting = false;
  bool? _myVote;
  bool _hidden = false;
  int _trueCount = 0;
  int _falseCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final counts = await _repo.getVoteCounts(widget.checkinId);
    if (!mounted) return;
    setState(() {
      _trueCount = counts[true] ?? 0;
      _falseCount = counts[false] ?? 0;
    });
  }

  Future<void> _vote(bool vote) async {
    if (_voting || _myVote != null) return;
    final voterId = SupabaseService.auth.currentUser?.id;
    if (voterId == null) return;
    setState(() => _voting = true);
    try {
      await _repo.castVote(
        checkinId: widget.checkinId,
        voterId: voterId,
        voteValue: vote,
      );
      setState(() {
        _myVote = vote;
        if (vote) {
          _trueCount++;
        } else {
          _falseCount++;
        }
      });
      final wasHidden = await _repo.evaluateAndHide(widget.checkinId);
      if (!mounted) return;
      if (wasHidden) {
        setState(() => _hidden = true);
        widget.onHidden?.call();
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _trueCount + _falseCount;
    final falseRatio = total > 0 ? _falseCount / total : 0.0;
    final trueRatio = total > 0 ? _trueCount / total : 0.0;

    if (_hidden) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.visibility_off, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bu bildirim yeterli yanlış oy aldığı için gizlendi.',
              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
            ),
          ),
        ]),
      );
    }

    final alreadyVoted = _myVote != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bu raporu doğruluyor musun?',
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _VoteChip(
              label: 'Doğru',
              icon: Icons.check_circle_outline,
              color: AppColors.primary,
              selected: _myVote == true,
              disabled: _voting || alreadyVoted,
              onTap: () => _vote(true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _VoteChip(
              label: 'Yanlış',
              icon: Icons.cancel_outlined,
              color: AppColors.danger,
              selected: _myVote == false,
              disabled: _voting || alreadyVoted,
              onTap: () => _vote(false),
            ),
          ),
        ]),
        if (total > 0) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Doğru: $_trueCount',
                style: AppTextStyles.caption.copyWith(color: AppColors.primary),
              ),
              Text(
                'Yanlış: $_falseCount',
                style: AppTextStyles.caption.copyWith(color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: trueRatio,
              minHeight: 6,
              backgroundColor: AppColors.danger.withValues(alpha: 0.2),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            falseRatio >= 0.5
                ? '${(falseRatio * 100).toStringAsFixed(0)}% yanlış — %70 eşiğinde gizlenir.'
                : 'Topluluk bu raporu doğruluyor.',
            style: AppTextStyles.caption.copyWith(
              color: falseRatio >= 0.5 ? AppColors.danger : AppColors.muted,
            ),
          ),
        ],
        if (alreadyVoted) ...[
          const SizedBox(height: 6),
          Text(
            'Oyunuz kaydedildi.',
            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}

class _VoteChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _VoteChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: selected ? color : AppColors.muted.withValues(alpha: 0.4),
            width: selected ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: disabled && !selected ? AppColors.muted : color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: disabled && !selected ? AppColors.muted : color,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
