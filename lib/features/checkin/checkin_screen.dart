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

/// Balık yoğunluğu — DB: fish_density
const _checkinDensityOptions = [
  ('yok', '❌', 'Balık Yok'),
  ('az', '🐟', 'Az'),
  ('normal', '🐟🐟', 'Normal'),
  ('yoğun', '🐟🐟🐟', 'Çok Balık'),
];

/// Kalabalık — DB: crowd_level
const _checkinCrowdOptions = [
  ('boş', '🏖️', 'Boş'),
  ('az', '👤', 'Sakin'),
  ('normal', '👥', 'Normal'),
  ('yoğun', '👥👥', 'Kalabalık'),
];

Widget _buildCheckinOptionsGrid({
  required double maxWidth,
  required List<(String, String, String)> options,
  required String selectedValue,
  required void Function(String) onSelect,
  required Color accentColor,
}) {
  const gap = 8.0;
  final cols = maxWidth >= 400 ? 4 : 2;
  final tileW = (maxWidth - gap * (cols - 1)) / cols;
  return Wrap(
    spacing: gap,
    runSpacing: gap,
    children: [
      for (final o in options)
        SizedBox(
          width: tileW,
          child: _CheckinOptionTile(
            emoji: o.$2,
            label: o.$3,
            isSelected: selectedValue == o.$1,
            onTap: () => onSelect(o.$1),
            accentColor: accentColor,
          ),
        ),
    ],
  );
}

class _CheckinOptionTile extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accentColor;

  const _CheckinOptionTile({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.20)
                : AppColors.foam.withValues(alpha: 0.05),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : AppColors.muted.withValues(alpha: 0.35),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  height: 1.2,
                  color: isSelected ? accentColor : AppColors.muted,
                  fontWeight:
                      isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      final pos = await LocationService.getCurrentPosition(
        purpose: LocationPurpose.checkin,
      );
      if (!mounted) return;

      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.gps_off, color: AppColors.foam),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Konum alınamadı. GPS açık mı?',
                    style: AppTextStyles.body.copyWith(color: AppColors.foam),
                  ),
                ),
              ],
            ),
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
              style: AppTextStyles.body.copyWith(color: AppColors.foam),
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      final payload = <String, dynamic>{
        'user_id': uid,
        'spot_id': widget.spotId,
        'crowd_level': _crowdLevel,
        'fish_density': _fishDensity,
        'is_active': true,
        if (_selectedFishTypes.isNotEmpty)
          'fish_species': List<String>.from(_selectedFishTypes),
      };

      final connResult = await Connectivity().checkConnectivity();
      final isOnline = connResult.any((r) => r != ConnectivityResult.none);

      if (!isOnline) {
        await SyncService.instance.enqueue('insert', 'checkins', payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📡 Çevrimdışısın — bildirim kuyruğa alındı.',
              style: AppTextStyles.body.copyWith(color: AppColors.foam),
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
          SnackBar(
            content: Text(
              'Bildirim gönderilemedi',
              style: AppTextStyles.body.copyWith(color: AppColors.foam),
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

      // Push / edge çağrıları UI isolate’ini meşgul etmesin — bir sonraki event loop turunda çalışsın.
      unawaited(
        Future(() async {
          try {
            if (spot.userId != uid) {
              await NotificationRepository().sendNotification(
                userId: spot.userId,
                title: '🎣 Meranızda Balık Var!',
                body: '${spot.name} merasında yeni bildirim geldi.',
                data: {'type': 'checkin', 'spot_id': spot.id},
              );
            }
          } catch (_) {}

          try {
            final favRepo = FavoriteRepository();
            final userIds = await favRepo.getUsersWhoFavorited(spot.id);
            final notifRepo = NotificationRepository();
            for (final favUserId in userIds) {
              if (favUserId == uid || favUserId == spot.userId) continue;
              try {
                await notifRepo.sendNotification(
                  userId: favUserId,
                  title: '🎣 Favori Meranızda Balık Var!',
                  body: '${spot.name} merasında balık bildirimi geldi.',
                  data: {'type': 'checkin', 'spot_id': spot.id},
                );
              } catch (_) {}
            }
          } catch (_) {}

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
        }),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bildirim gönderilemedi: $e',
            style: AppTextStyles.body.copyWith(color: AppColors.foam),
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
      backgroundColor: AppColors.navy.withValues(alpha: 0.55),
      body: SafeArea(
        child: Column(
          children: [
            // Küçük tutamaç — tam genişlik, açık dokunma alanı
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.pop(false),
                child: const SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 40,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _loadingSpot
                    ? const Center(child: CircularProgressIndicator())
                    : _spot == null
                    ? Center(
                        child: Text(
                          'Mera bulunamadı.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.foam,
                          ),
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

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buraya Balık Tutuldu!',
                            style: AppTextStyles.h2.copyWith(
                              color: AppColors.foam,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    spot.name,
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Ne Balığı Tutuldu?',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _CheckinScreenState._fishTypeOptions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final type =
                              _CheckinScreenState._fishTypeOptions[index];
                          final isSelected = selectedFishTypes.contains(type);
                          return FilterChip(
                            label: Text(
                              type,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppColors.foam
                                    : AppColors.muted,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) => onFishTypeToggle(type),
                            selectedColor: AppColors.secondary,
                            backgroundColor: cardBg,
                            checkmarkColor: AppColors.foam,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.secondary
                                  : AppColors.muted.withValues(alpha: 0.35),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Balık Yoğunluğu',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, c) {
                              return _buildCheckinOptionsGrid(
                                maxWidth: c.maxWidth,
                                options: _checkinDensityOptions,
                                selectedValue: fishDensity,
                                onSelect: onDensityChanged,
                                accentColor: AppColors.primary,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.foam,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Devam Et',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.foam,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 22,
                            color: AppColors.foam,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: IconButton(
                              onPressed: onBack,
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.muted,
                                size: 28,
                              ),
                              tooltip: 'Geri',
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Kalabalık Durumu',
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.foam,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          return _buildCheckinOptionsGrid(
                            maxWidth: c.maxWidth,
                            options: _checkinCrowdOptions,
                            selectedValue: crowdLevel,
                            onSelect: onCrowdChanged,
                            accentColor: AppColors.secondary,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: submitting ? null : onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: AppColors.foam,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: submitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.foam,
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.share_rounded,
                                  size: 22,
                                  color: AppColors.foam,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Paylaş!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.foam,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                    child: Center(
                      child: Text(
                        '✅',
                        style: AppTextStyles.h1.copyWith(
                          fontSize: 56,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Bildiriminiz İletildi!',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.foam,
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  spot != null
                      ? '${spot!.name} merası haritada aktif görünüyor.'
                      : 'Haritada aktif olarak görünüyor.',
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Diğer balıkçılar sizi görüyor.',
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
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
                      if (checkin.fishSpecies.isNotEmpty) ...[
                        Divider(
                          height: 16,
                          thickness: 0.5,
                          color: AppColors.foam.withValues(alpha: 0.08),
                        ),
                        _ResultRow(
                          label: 'Balık Türleri',
                          value: checkin.fishSpecies.join(', '),
                        ),
                      ],
                      Divider(
                          height: 16,
                          thickness: 0.5,
                          color: AppColors.foam.withValues(alpha: 0.08)),
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
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onBack,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.foam,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.map_outlined, size: 28),
                    label: Text(
                      'Haritaya Dön',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foam,
                      ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: AppColors.foam,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
