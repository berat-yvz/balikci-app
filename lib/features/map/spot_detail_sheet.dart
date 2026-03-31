import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/features/checkin/vote_widget.dart';

/// Mera detay alt sheet (H3 read-only + H4 sahip düzenleme).
class SpotDetailSheet extends StatefulWidget {
  final SpotModel spot;
  const SpotDetailSheet({super.key, required this.spot});

  @override
  State<SpotDetailSheet> createState() => _SpotDetailSheetState();
}

class _SpotDetailSheetState extends State<SpotDetailSheet> {
  final _checkinRepo = CheckinRepository();
  List<CheckinModel> _checkins = const [];
  bool _loadingCheckins = true;
  final Map<String, Map<bool, int>> _voteCountsByCheckinId = {};

  @override
  void initState() {
    super.initState();
    _loadCheckins();
  }

  Future<void> _openDirections(BuildContext context) async {
    final label = Uri.encodeComponent(widget.spot.name);
    final geo = Uri.parse(
      'geo:${widget.spot.lat},${widget.spot.lng}?q=${widget.spot.lat},${widget.spot.lng}($label)',
    );
    final maps = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${widget.spot.lat},${widget.spot.lng}',
    );
    try {
      if (await launchUrl(geo, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    try {
      if (await launchUrl(maps, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Harita acilamadi'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _openEdit(BuildContext context) {
    final router = GoRouter.of(context);
    final s = widget.spot;
    Navigator.of(context).pop();
    Future.microtask(() => router.push('/map/edit-spot', extra: s));
  }

  Future<void> _openCheckin(BuildContext context) async {
    final router = GoRouter.of(context);
    final s = widget.spot;
    final result = await router.push<bool>('/checkin/${s.id}');
    if (!mounted) return;
    if (result == true) {
      await _loadCheckins();
    }
  }

  Future<void> _loadCheckins() async {
    setState(() => _loadingCheckins = true);
    try {
      final items = await _checkinRepo.getCheckinsForSpot(widget.spot.id);
      final limited = items.take(5).toList();
      final voteMap = <String, Map<bool, int>>{};
      for (final c in limited) {
        voteMap[c.id] = await _checkinRepo.getVoteCounts(c.id);
      }
      if (!mounted) return;
      setState(() {
        _checkins = limited;
        _voteCountsByCheckinId
          ..clear()
          ..addAll(voteMap);
      });
    } finally {
      if (mounted) setState(() => _loadingCheckins = false);
    }
  }

  String _formatAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    return '${diff.inHours} saat önce';
  }

  String _initials(String? username) {
    final raw = (username ?? 'Kullanıcı').trim();
    if (raw.isEmpty) return 'KU';
    final parts = raw.split(RegExp(r'\s+'));
    final a = parts.first.isNotEmpty ? parts.first[0] : 'K';
    final b = parts.length > 1
        ? (parts.last.isNotEmpty ? parts.last[0] : 'U')
        : (raw.length > 1 ? raw[1] : 'U');
    return (a + b).toUpperCase();
  }

  (String, Color) _crowdMeta(String? value) {
    switch (value) {
      case 'yoğun':
        return ('Kalabalık: Yoğun', Colors.redAccent);
      case 'normal':
        return ('Kalabalık: Normal', Colors.orangeAccent);
      case 'az':
        return ('Kalabalık: Az', AppColors.success);
      case 'boş':
        return ('Kalabalık: Boş', Colors.lightBlueAccent);
      default:
        return ('Kalabalık: Bilinmiyor', Colors.grey);
    }
  }

  (String, Color) _fishMeta(String? value) {
    switch (value) {
      case 'yoğun':
        return ('Balık: Yoğun', AppColors.success);
      case 'normal':
        return ('Balık: Normal', AppColors.teal);
      case 'az':
        return ('Balık: Az', Colors.orangeAccent);
      case 'yok':
        return ('Balık: Yok', AppColors.danger);
      default:
        return ('Balık: Bilinmiyor', Colors.grey);
    }
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _exifBadge(bool? exif) {
    final (label, bgColor, borderColor) = switch (exif) {
      true => (
        '✓ doğrulandı',
        AppColors.success.withValues(alpha: 0.15),
        AppColors.success,
      ),
      false => (
        '✗ eşleşmedi',
        AppColors.danger.withValues(alpha: 0.15),
        AppColors.danger,
      ),
      _ => (
        '⏳ bekliyor',
        AppColors.warning.withValues(alpha: 0.15),
        AppColors.warning,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor.withValues(alpha: 0.45)),
      ),
      child: Text(
        'EXIF: $label',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  bool? _exifStatusForList(CheckinModel checkin) {
    if (checkin.photoUrl == null) return null;
    if (checkin.exifVerified) return true;
    final age = DateTime.now().difference(checkin.createdAt);
    if (age.inMinutes < 10) return null;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.auth.currentUser?.id;
    final isOwner = uid != null && uid == widget.spot.userId;
    final latest = _checkins.isNotEmpty ? _checkins.first : null;
    final latestCrowd = latest == null ? null : _crowdMeta(latest.crowdLevel);
    final latestFish = latest == null ? null : _fishMeta(latest.fishDensity);

    return Container(
      height: 560,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(widget.spot.name, style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Gizlilik: ${widget.spot.privacyLevel}',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 4),
            if (widget.spot.type != null)
              Text('Tur: ${widget.spot.type}', style: AppTextStyles.body),
            const SizedBox(height: 4),
            Text(
              'Konum: ${widget.spot.lat.toStringAsFixed(5)}, ${widget.spot.lng.toStringAsFixed(5)}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 12),
            Text(
              widget.spot.description?.trim().isNotEmpty == true
                  ? widget.spot.description!
                  : 'Aciklama yok.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            const Text(
              'Son Durum Özeti',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingCheckins)
              const Center(child: CircularProgressIndicator())
            else if (latest == null)
              const Text(
                'Henüz bilgi yok',
                style: TextStyle(color: Colors.grey),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(latestCrowd!.$1, latestCrowd.$2),
                  _chip(latestFish!.$1, latestFish.$2),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Son rapor ${_formatAgo(latest.createdAt)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Son Check-in\'ler (${_checkins.length})',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingCheckins)
              const Center(child: CircularProgressIndicator())
            else if (_checkins.isEmpty)
              const Text(
                "Henüz check-in yok. İlk check-in'i sen yap! 🎣",
                style: TextStyle(color: Colors.white70),
              )
            else
              ..._checkins.map((checkin) {
                final userLabel = checkin.username ?? 'Kullanıcı';
                final crowd = _crowdMeta(checkin.crowdLevel);
                final fish = _fishMeta(checkin.fishDensity);
                final voteCounts =
                    _voteCountsByCheckinId[checkin.id] ??
                    const {true: 0, false: 0};
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: const Color(0xFF132236),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.25,
                              ),
                              child: Text(
                                _initials(userLabel),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _formatAgo(checkin.createdAt),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chip(crowd.$1, crowd.$2),
                            _chip(fish.$1, fish.$2),
                            if (checkin.photoUrl != null)
                              _exifBadge(_exifStatusForList(checkin)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        VoteWidget(
                          checkinId: checkin.id,
                          checkinOwnerId: checkin.userId,
                          initialVoteCounts: voteCounts,
                          currentUserId: uid ?? '',
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isOwner)
                  TextButton(
                    onPressed: () => _openEdit(context),
                    child: const Text('Duzenle'),
                  ),
                TextButton(
                  onPressed: () => _openCheckin(context),
                  child: const Text('Check-in'),
                ),
                TextButton(
                  onPressed: () => _openDirections(context),
                  child: const Text('Yol tarifi'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kapat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
