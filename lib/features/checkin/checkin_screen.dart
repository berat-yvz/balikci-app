import 'dart:math' as math;
import 'dart:io';
import 'dart:async';

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
import 'package:balikci_app/features/checkin/vote_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:balikci_app/shared/widgets/exif_badge.dart';

/// Check-in ekranı — H5 sprint'i.
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
  Map<bool, int> _voteCounts = const {true: 0, false: 0};
  bool? _exifVerifiedStatus;
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
    // Haversine distance
    const r = 6371000.0; // meters
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
            content: Text('Check-in olusturulamadi'),
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

        // EXIF doğrulaması tetikleniyor; pending olarak gösterelim.
        setState(() => _exifVerifiedStatus = null);
        unawaited(_pollCheckinExifVerified(created.id));
      }

      final voteCounts = await _checkinRepo.getVoteCounts(created.id);
      final trueCount = voteCounts[true] ?? 0;
      final falseCount = voteCounts[false] ?? 0;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check-in yapildi ✓'),
          backgroundColor: AppColors.primary,
        ),
      );

      setState(() {
        _createdCheckin = created;
        _voteCounts = {true: trueCount, false: falseCount};
      });
      if (!mounted) return;
      context.pop(true);
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Check-in olusturulamadi: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pollCheckinExifVerified(String checkinId) async {
    const attempts = 10; // 10 x 3 sn = 30 sn
    const interval = Duration(seconds: 3);

    for (var i = 0; i < attempts; i++) {
      try {
        final response = await SupabaseService.client
            .from('checkins')
            .select('exif_verified')
            .eq('id', checkinId)
            .maybeSingle();

        final verified = response?['exif_verified'];
        if (verified == true) {
          if (!mounted) return;
          setState(() => _exifVerifiedStatus = true);
          return;
        }
      } catch (_) {
        // Hata alırsak bir deneme daha yapacağız.
      }

      if (i == attempts - 1) break;
      await Future.delayed(interval);
    }

    // 30 sn içinde true dönmediyse eşleşmedi kabul et.
    if (!mounted) return;
    setState(() => _exifVerifiedStatus = false);
  }

  @override
  Widget build(BuildContext context) {
    final spot = _spot;
    final canSubmit = !_loadingSpot && spot != null && !_submitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Check-in')),
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

                    DropdownButtonFormField<String>(
                      initialValue: _crowdLevel,
                      decoration: const InputDecoration(
                        labelText: 'Kalabalik (4 seviye)',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'yoğun', child: Text('Yogun')),
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(value: 'az', child: Text('Az')),
                        DropdownMenuItem(value: 'boş', child: Text('Bos')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _crowdLevel = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _fishDensity,
                      decoration: const InputDecoration(
                        labelText: 'Balik yogunlugu (4 seviye)',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'yoğun', child: Text('Yogun')),
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(value: 'az', child: Text('Az')),
                        DropdownMenuItem(value: 'yok', child: Text('Yok')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _fishDensity = v);
                      },
                    ),

                    const SizedBox(height: 16),
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
                          : const Text('Konum dogrula ve check-in yap'),
                    ),

                    const SizedBox(height: 12),
                    if (_createdCheckin != null) ...[
                      Text('Oylama', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Text(
                        'Bu check-in için Dogru/Yanlis oyu verin.',
                        style: AppTextStyles.body,
                      ),
                      if (_pickedPhoto != null) ...[
                        const SizedBox(height: 12),
                        ExifBadge(exifVerified: _exifVerifiedStatus),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 12),
                      VoteWidget(
                        checkinId: _createdCheckin!.id,
                        checkinOwnerId: _createdCheckin!.userId,
                        initialVoteCounts: _voteCounts,
                        currentUserId: SupabaseService.auth.currentUser!.id,
                      ),
                      const SizedBox(height: 20),
                    ],
                    TextButton(
                      onPressed: () {
                        // Geri: route stack'inden çık.
                        context.pop(false);
                      },
                      child: const Text('Iptal'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
