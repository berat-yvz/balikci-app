import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/features/checkin/vote_widget.dart';

/// Mera detay alt sheet — mera seçilince haritadan açılır.
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

  @override
  void initState() {
    super.initState();
    _loadCheckins();
  }

  Future<void> _loadCheckins() async {
    setState(() => _loadingCheckins = true);
    try {
      final items = await _checkinRepo.getCheckinsForSpot(widget.spot.id);
      if (!mounted) return;
      setState(() => _checkins = items.take(5).toList());
    } finally {
      if (mounted) setState(() => _loadingCheckins = false);
    }
  }

  Future<void> _openDirections(BuildContext context) async {
    final label = Uri.encodeComponent(widget.spot.name);
    final geo = Uri.parse(
      'geo:${widget.spot.lat},${widget.spot.lng}'
      '?q=${widget.spot.lat},${widget.spot.lng}($label)',
    );
    final maps = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${widget.spot.lat},${widget.spot.lng}',
    );
    bool launched = false;
    try {
      launched = await launchUrl(geo, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (launched) return;
    try {
      launched = await launchUrl(maps, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (launched) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Harita uygulaması açılamadı'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  Future<void> _openCheckin(BuildContext context) async {
    final result =
        await GoRouter.of(context).push<bool>('/checkin/${widget.spot.id}');
    if (!mounted) return;
    if (result == true) await _loadCheckins();
  }

  void _openEdit(BuildContext context) {
    final router = GoRouter.of(context);
    final spot = widget.spot;
    Navigator.of(context).pop();
    Future.microtask(() => router.push('/map/edit-spot', extra: spot));
  }

  // ── Yardımcı dönüşümler ──────────────────────────────────────────────────

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

  /// Balık yoğunluğu → (emoji, etiket, renk)
  (String, String, Color) _fishDisplay(String? value) => switch (value) {
    'yoğun' => ('🐟🐟🐟', 'YOĞUN',  AppColors.success),
    'normal' => ('🐟🐟',   'NORMAL', AppColors.teal),
    'az'     => ('🐟',     'AZ',     AppColors.accent),
    'yok'    => ('❌',     'YOK',    AppColors.danger),
    _        => ('—',      'BİLGİ YOK', AppColors.muted),
  };

  (String, Color) _crowdDisplay(String? value) => switch (value) {
    'yoğun' => ('Çok kalabalık', Colors.redAccent),
    'normal' => ('Normal kalabalık', Colors.orangeAccent),
    'az'     => ('Sakin', AppColors.success),
    'boş'    => ('Boş', Colors.lightBlueAccent),
    _        => ('Bilinmiyor', Colors.grey),
  };

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.auth.currentUser?.id;
    final isOwner = uid != null && uid == widget.spot.userId;
    final latest = _checkins.isNotEmpty ? _checkins.first : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16, 12, 16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            // ── Tutamaç ────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Başlık + gizlilik ──────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(widget.spot.name, style: AppTextStyles.h2),
                ),
                const SizedBox(width: 8),
                _PrivacyBadge(level: widget.spot.privacyLevel),
              ],
            ),
            if (widget.spot.type != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.spot.type!,
                style: AppTextStyles.caption.copyWith(color: AppColors.muted),
              ),
            ],
            if (widget.spot.description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                widget.spot.description!,
                style: AppTextStyles.body.copyWith(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 18),

            // ── Son Durum Kartı ────────────────────────
            if (_loadingCheckins)
              const _LoadingCard()
            else
              _SonDurumCard(
                checkin: latest,
                fishDisplay: _fishDisplay(latest?.fishDensity),
                crowdDisplay: _crowdDisplay(latest?.crowdLevel),
                formatAgo: _formatAgo,
              ),
            const SizedBox(height: 12),

            // ── Oy Widget (sadece son bildirim için) ───
            if (!_loadingCheckins && latest != null) ...[
              VoteWidget(
                checkin: latest,
                ownerUserId: latest.userId,
                onHidden: () {
                  setState(() => _checkins = _checkins
                      .where((c) => c.id != latest.id)
                      .toList());
                },
              ),
              const SizedBox(height: 16),
            ],

            // ── Balık Var! CTA ─────────────────────────
            _CheckinCTA(onTap: () => _openCheckin(context)),
            const SizedBox(height: 20),

            // ── Bildirim Geçmişi ──────────────────────
            if (!_loadingCheckins) ...[
              Text(
                'Son Bildirimler (${_checkins.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              if (_checkins.isEmpty)
                const Text(
                  'Henüz bildirim yok. İlk bildirimi sen yap! 🎣',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                )
              else
                ..._checkins.map(
                  (c) => _HistoryCard(
                    checkin: c,
                    fishDisplay: _fishDisplay(c.fishDensity),
                    crowdDisplay: _crowdDisplay(c.crowdLevel),
                    initials: _initials(c.username),
                    formatAgo: _formatAgo,
                  ),
                ),
            ],

            const SizedBox(height: 12),

            // ── Footer butonları ──────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isOwner)
                  TextButton(
                    onPressed: () => _openEdit(context),
                    child: const Text('Düzenle'),
                  ),
                TextButton(
                  onPressed: () => _openDirections(context),
                  child: const Text('Yol Tarifi'),
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

// ── Alt Widget'lar ────────────────────────────────────────────────────────────

class _PrivacyBadge extends StatelessWidget {
  final String privacyLevel;
  const _PrivacyBadge({required this.level}) : privacyLevel = level;
  // ignore: unused_field
  final String level;

  static (String, Color) _meta(String level) => switch (level) {
    'public'  => ('🌍 Herkese Açık', AppColors.success),
    'friends' => ('👥 Takipçiler',   AppColors.secondary),
    'private' => ('🔒 Gizli',        AppColors.muted),
    'vip'     => ('⭐ VIP',          AppColors.accent),
    _         => (level,             AppColors.muted),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _meta(privacyLevel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFF132236),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SonDurumCard extends StatelessWidget {
  final CheckinModel? checkin;
  final (String, String, Color) fishDisplay;
  final (String, Color) crowdDisplay;
  final String Function(DateTime) formatAgo;

  const _SonDurumCard({
    required this.checkin,
    required this.fishDisplay,
    required this.crowdDisplay,
    required this.formatAgo,
  });

  @override
  Widget build(BuildContext context) {
    final (fishEmoji, fishLabel, fishColor) = fishDisplay;
    final (crowdLabel, crowdColor) = crowdDisplay;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF132236),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: checkin != null
              ? fishColor.withValues(alpha: 0.35)
              : Colors.white10,
        ),
      ),
      child: checkin == null
          ? const Row(
              children: [
                Text('🎣', style: TextStyle(fontSize: 28)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Henüz bildirim yok.\nBu meradan ilk bildirimi sen yap!',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık satırı
                Row(
                  children: [
                    const Text(
                      'SON DURUM',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatAgo(checkin!.createdAt),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    if (checkin!.isStale) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '⏳ Eski olabilir',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Ana balık göstergesi
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      fishEmoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BALIK: $fishLabel',
                          style: TextStyle(
                            color: fishColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          crowdLabel,
                          style: TextStyle(
                            color: crowdColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (checkin!.exifVerified) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          '✓ Doğrulandı',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }
}

class _CheckinCTA extends StatelessWidget {
  final VoidCallback onTap;
  const _CheckinCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        icon: const Text('🎣', style: TextStyle(fontSize: 20)),
        label: const Text(
          'Balık Var! Bildir',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final CheckinModel checkin;
  final (String, String, Color) fishDisplay;
  final (String, Color) crowdDisplay;
  final String initials;
  final String Function(DateTime) formatAgo;

  const _HistoryCard({
    required this.checkin,
    required this.fishDisplay,
    required this.crowdDisplay,
    required this.initials,
    required this.formatAgo,
  });

  @override
  Widget build(BuildContext context) {
    final (fishEmoji, fishLabel, fishColor) = fishDisplay;
    final (crowdLabel, _) = crowdDisplay;
    final userLabel = checkin.username ?? 'Anonim';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.22),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // İçerik
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      userLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatAgo(checkin.createdAt),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$fishEmoji $fishLabel',
                      style: TextStyle(
                        color: fishColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      crowdLabel,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Oy özeti
          if (checkin.trueVotes + checkin.falseVotes > 0) ...[
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  '✓${checkin.trueVotes}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '✗${checkin.falseVotes}',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
