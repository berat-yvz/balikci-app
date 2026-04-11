import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/app_constants.dart';
import 'package:balikci_app/core/services/location_service.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/services/sync_service.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/core/services/score_service.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';
import 'package:balikci_app/data/repositories/favorite_repository.dart';
import 'package:balikci_app/data/repositories/notification_repository.dart';
import 'package:balikci_app/data/repositories/spot_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Check-in ekranı — 2 sayfalı akış, hedef kitleye göre optimize.
class CheckinScreen extends StatefulWidget {
  final String spotId;
  const CheckinScreen({super.key, required this.spotId});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen>
    with SingleTickerProviderStateMixin {
  final _spotRepo = SpotRepository();
  final _checkinRepo = CheckinRepository();

  SpotModel? _spot;
  CheckinModel? _createdCheckin;
  bool _loadingSpot = true;
  bool _submitting = false;
  int _currentPage = 0;

  // Sayfa 1 seçimleri
  final List<String> _selectedFishTypes = [];

  // DB kısıtları: fish_density IN ('yoğun','normal','az','yok')
  String _fishDensity = 'normal';
  // DB kısıtları: crowd_level IN ('yoğun','normal','az','boş')
  String _crowdLevel = 'normal';

  // Başarı animasyonu
  late AnimationController _successAnimController;
  late Animation<double> _successScaleAnim;

  static const _fishTypeOptions = [
    'Levrek',
    'Çipura',
    'İstavroz',
    'Lüfer',
    'Kefal',
    'Palamut',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    _loadSpot();
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScaleAnim = CurvedAnimation(
      parent: _successAnimController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _successAnimController.dispose();
    super.dispose();
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
            content: Row(children: [
              Icon(Icons.gps_off, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Konum alınamadı. GPS açık mı?',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ]),
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
              'Meradan çok uzaksın (~${distMeters.toStringAsFixed(0)} m). '
              '${AppConstants.checkinRadiusMeters} m yaklaşman gerek.',
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      final payload = {
        'user_id': uid,
        'spot_id': widget.spotId,
        'crowd_level': _crowdLevel,
        'fish_density': _fishDensity,
        'is_active': true,
      };

      final connResult = await Connectivity().checkConnectivity();
      final isOnline = connResult.any((r) => r != ConnectivityResult.none);

      if (!isOnline) {
        await SyncService.instance.enqueue('insert', 'checkins', payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '📡 Çevrimdışısın — bildirim kuyruğa alındı.',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 4),
          ),
        );
        context.pop(true);
        return;
      }

      final created = await _checkinRepo.addCheckin(payload);

      if (created == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bildirim gönderilemedi',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      if (!mounted) return;
      unawaited(HapticFeedback.heavyImpact());

      setState(() => _createdCheckin = created);
      unawaited(_successAnimController.forward());

      unawaited(ScoreService.award(uid, ScoreSource.checkinUnverified));

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

      unawaited(() async {
        try {
          final favRepo = FavoriteRepository();
          final userIds = await favRepo.getUsersWhoFavorited(spot.id);
          final notifRepo = NotificationRepository();
          for (final favUserId in userIds) {
            if (favUserId == uid || favUserId == spot.userId) continue;
            await notifRepo.sendNotification(
              userId: favUserId,
              title: '🎣 Favori Meranızda Balık Var!',
              body: '${spot.name} merasında balık bildirimi geldi.',
              data: {'type': 'checkin', 'spot_id': spot.id},
            );
          }
        } catch (_) {}
      }());

      unawaited(() async {
        try {
          await SupabaseService.client.functions.invoke(
            'nearby-checkin-notifier',
            body: {
              'user_id': uid,
              'spot_id': spot.id,
              'lat': spot.lat,
              'lng': spot.lng,
              'spot_name': spot.name,
            },
          );
        } catch (_) {}
      }());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bildirim gönderilemedi: $e',
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Başarı ekranı
    if (_createdCheckin != null) {
      return _SuccessScreen(
        checkin: _createdCheckin!,
        spot: _spot,
        scaleAnim: _successScaleAnim,
        onBack: () => context.pop(true),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black54,
      body: SafeArea(
        child: Column(
          children: [
            // Küçük tutamaç göstergesi
            GestureDetector(
              onTap: () => context.pop(false),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0B1C33),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: _loadingSpot
                    ? const Center(child: CircularProgressIndicator())
                    : _spot == null
                    ? const Center(
                        child: Text(
                          'Mera bulunamadı.',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      )
                    : _currentPage == 0
                    ? _Page1(
                        spot: _spot!,
                        selectedFishTypes: _selectedFishTypes,
                        fishDensity: _fishDensity,
                        onFishTypeToggle: (type) {
                          setState(() {
                            if (_selectedFishTypes.contains(type)) {
                              _selectedFishTypes.remove(type);
                            } else {
                              _selectedFishTypes.add(type);
                            }
                          });
                        },
                        onDensityChanged: (v) =>
                            setState(() => _fishDensity = v),
                        onNext: () => setState(() => _currentPage = 1),
                      )
                    : _Page2(
                        crowdLevel: _crowdLevel,
                        submitting: _submitting,
                        onCrowdChanged: (v) =>
                            setState(() => _crowdLevel = v),
                        onBack: () => setState(() => _currentPage = 0),
                        onSubmit: _submitCheckin,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sayfa 1: Balık türü + yoğunluk ───────────────────────────────────────────

class _Page1 extends StatelessWidget {
  final SpotModel spot;
  final List<String> selectedFishTypes;
  final String fishDensity;
  final void Function(String) onFishTypeToggle;
  final void Function(String) onDensityChanged;
  final VoidCallback onNext;

  const _Page1({
    required this.spot,
    required this.selectedFishTypes,
    required this.fishDensity,
    required this.onFishTypeToggle,
    required this.onDensityChanged,
    required this.onNext,
  });

  static const _densityOptions = [
    ('yok', '❌', 'Balık Yok'),
    ('az', '🐟', 'Az'),
    ('normal', '🐟🐟', 'Normal'),
    ('yoğun', '🐟🐟🐟', 'Çok Balık'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Buraya Balık Tutuldu!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              // Konum chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        spot.name,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ne Balığı Tutuldu?',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        // Balık türleri — yatay kaydırmalı
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _CheckinScreenState._fishTypeOptions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final type = _CheckinScreenState._fishTypeOptions[index];
              final isSelected = selectedFishTypes.contains(type);
              return FilterChip(
                label: Text(
                  type,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) => onFishTypeToggle(type),
                selectedColor: AppColors.secondary,
                backgroundColor: const Color(0xFF132236),
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.secondary
                      : Colors.white24,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Balık Yoğunluğu',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: _densityOptions.map((opt) {
                  final (value, emoji, label) = opt;
                  final isSelected = fishDensity == value;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => onDensityChanged(value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 72,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.20)
                                : Colors.white.withValues(alpha: 0.05),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white24,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                emoji,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.white54,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Devam Et',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 22),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sayfa 2: Kalabalık + Not + Paylaş ────────────────────────────────────────

class _Page2 extends StatelessWidget {
  final String crowdLevel;
  final bool submitting;
  final void Function(String) onCrowdChanged;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _Page2({
    required this.crowdLevel,
    required this.submitting,
    required this.onCrowdChanged,
    required this.onBack,
    required this.onSubmit,
  });

  static const _crowdOptions = [
    ('boş', '🏖️', 'Boş'),
    ('az', '👤', 'Sakin'),
    ('normal', '👥', 'Normal'),
    ('yoğun', '👥👥', 'Kalabalık'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Geri + başlık
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 20, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white70, size: 26),
                tooltip: 'Geri',
              ),
              const Text(
                'Kalabalık Durumu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: _crowdOptions.map((opt) {
                  final (value, emoji, label) = opt;
                  final isSelected = crowdLevel == value;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => onCrowdChanged(value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 72,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.secondary.withValues(alpha: 0.20)
                                : Colors.white.withValues(alpha: 0.05),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.secondary
                                  : Colors.white24,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(emoji,
                                  style: const TextStyle(fontSize: 18)),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? AppColors.secondary
                                      : Colors.white54,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: submitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share_rounded, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Paylaş!',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Başarı Ekranı ─────────────────────────────────────────────────────────────

class _SuccessScreen extends StatelessWidget {
  final CheckinModel checkin;
  final SpotModel? spot;
  final Animation<double> scaleAnim;
  final VoidCallback onBack;

  const _SuccessScreen({
    required this.checkin,
    required this.spot,
    required this.scaleAnim,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Bildirim Gönderildi'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: onBack,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: scaleAnim,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withValues(alpha: 0.15),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.5),
                          width: 3),
                    ),
                    child: const Center(
                      child: Text('✅', style: TextStyle(fontSize: 56)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Bildiriminiz İletildi!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  spot != null
                      ? '${spot!.name} merası haritada aktif görünüyor.'
                      : 'Haritada aktif olarak görünüyor.',
                  style: const TextStyle(color: Colors.white60, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Diğer balıkçılar sizi görüyor.',
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Sonuç kartı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.30)),
                  ),
                  child: Column(
                    children: [
                      _ResultRow(
                        label: 'Balık Yoğunluğu',
                        value: checkin.fishDensity ?? '-',
                      ),
                      const Divider(
                          height: 16, thickness: 0.5, color: Colors.white12),
                      _ResultRow(
                        label: 'Kalabalık',
                        value: checkin.crowdLevel ?? '-',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: onBack,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.map_outlined, size: 22),
                    label: const Text(
                      'Haritaya Dön',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
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

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
