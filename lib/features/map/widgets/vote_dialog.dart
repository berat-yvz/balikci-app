import 'dart:async';

import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/score_service.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';
import 'package:balikci_app/data/repositories/notification_repository.dart';

/// 45+ hedef kitleye uygun büyük-butonlu oy popup'ı.
///
/// showDialog ile açılır; kullanıcı oy verince veya İptal'e basınca kapanır.
class VoteDialog extends StatefulWidget {
  final CheckinModel checkin;

  const VoteDialog({super.key, required this.checkin});

  /// Kolaylık metodu — doğrudan `showDialog` sarar.
  static Future<void> show(
    BuildContext context, {
    required CheckinModel checkin,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => VoteDialog(checkin: checkin),
    );
  }

  @override
  State<VoteDialog> createState() => _VoteDialogState();
}

class _VoteDialogState extends State<VoteDialog> {
  final _repo = CheckinRepository();

  bool _loading = true;
  bool _voting = false;
  bool? _myVote;
  late int _trueCount;
  late int _falseCount;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _trueCount = widget.checkin.trueVotes;
    _falseCount = widget.checkin.falseVotes;
    _loadMyVote();
  }

  Future<void> _loadMyVote() async {
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final vote = await _repo.getUserVote(widget.checkin.id, uid);
      if (mounted) {
        setState(() { _myVote = vote; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cast(bool vote) async {
    if (_voting) return;
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) return;

    final prevVote = _myVote;
    final prevTrue = _trueCount;
    final prevFalse = _falseCount;
    final toggling = _myVote == vote;

    setState(() {
      _voting = true;
      if (prevVote == true) _trueCount = (_trueCount - 1).clamp(0, 99999);
      if (prevVote == false) _falseCount = (_falseCount - 1).clamp(0, 99999);
      if (toggling) {
        _myVote = null;
      } else {
        _myVote = vote;
        if (vote) { _trueCount++; } else { _falseCount++; }
      }
    });

    try {
      await _repo.castVote(
        checkinId: widget.checkin.id,
        voterId: uid,
        voteValue: vote,
      );
      if (!mounted) return;

      if (!toggling) {
        final wasHidden = await _repo.evaluateAndHide(widget.checkin.id);
        if (!mounted) return;
        if (wasHidden) {
          setState(() => _hidden = true);
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          if (mounted) Navigator.of(context).pop();
          return;
        }

        // Pozitif oy: bildirim sahibine puan + bildirim ver
        final ownerId = widget.checkin.userId;
        if (vote && ownerId != uid) {
          unawaited(ScoreService.award(ownerId, ScoreSource.correctVote));
          unawaited(
            NotificationRepository().sendNotification(
              userId: ownerId,
              title: '👍 Bildiriminiz Doğru Bulundu',
              body: 'Bir balıkçı bildiriminizi doğru olarak değerlendirdi.',
              data: {'type': 'vote', 'spot_id': widget.checkin.spotId},
            ),
          );
        }
        // Yanlış oy: bildirim sahibinin puanını düş
        if (!vote && ownerId != uid) {
          unawaited(ScoreService.award(ownerId, ScoreSource.wrongReport));
        }
      }

      // Oy başarılı → kısa bekleme sonra kapat
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _trueCount = prevTrue;
          _falseCount = prevFalse;
          _myVote = prevVote;
          _voting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.auth.currentUser?.id;
    final isSelf = uid == widget.checkin.userId;
    final total = _trueCount + _falseCount;
    final trustPct = total == 0 ? 0.0 : (_trueCount / total).clamp(0.0, 1.0);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık
            Text(
              '🎣  Bu Bildirim Doğru mu?',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.foam,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Check-in özet kartı
            _CheckinSummaryCard(checkin: widget.checkin),
            const SizedBox(height: 14),

            // Güven çubuğu
            _TrustBar(
              trueCount: _trueCount,
              falseCount: _falseCount,
              pct: trustPct,
            ),
            const SizedBox(height: 18),

            // İçerik durumuna göre
            if (_hidden) ...[
              _HiddenBanner(),
            ] else if (_loading) ...[
              const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator()),
              ),
            ] else if (isSelf) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Kendi bildiriminize oy veremezsiniz.',
                  style: TextStyle(color: AppColors.muted, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else if (_myVote != null) ...[
              // Oy verilmiş — sonuç göster + geri al
              _VotedState(
                vote: _myVote!,
                onUndo: _voting ? null : () => _cast(_myVote!),
              ),
            ] else ...[
              // Oy ver butonları
              Row(
                children: [
                  Expanded(
                    child: _VoteBtn(
                      label: '✓  DOĞRU',
                      color: AppColors.success,
                      onPressed: _voting ? null : () => _cast(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _VoteBtn(
                      label: '✗  YANLIŞ',
                      color: AppColors.danger,
                      onPressed: _voting ? null : () => _cast(false),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'İptal',
                style: TextStyle(color: AppColors.muted, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Yardımcı widget'lar ───────────────────────────────────────────────────────

class _CheckinSummaryCard extends StatelessWidget {
  final CheckinModel checkin;
  const _CheckinSummaryCard({required this.checkin});

  String _fishLabel(String? d) => switch (d) {
    'yoğun' => '🐟🐟🐟 Çok Balık',
    'normal' => '🐟🐟 Normal',
    'az' => '🐟 Az Balık',
    'yok' => '❌ Balık Yok',
    _ => '🐟 Bilinmiyor',
  };

  String _crowdLabel(String? c) => switch (c) {
    'yoğun' => '👥👥 Çok Kalabalık',
    'normal' => '👥 Normal',
    'az' => '👤 Sakin',
    'boş' => '🏖️ Boş',
    _ => '👥 Bilinmiyor',
  };

  String _formatAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, color: AppColors.muted, size: 16),
              const SizedBox(width: 8),
              Text(
                _formatAgo(checkin.createdAt),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fishLabel(checkin.fishDensity),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (checkin.fishSpecies.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        checkin.fishSpecies.join(' · '),
                        style: const TextStyle(
                          color: AppColors.sand,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                _crowdLabel(checkin.crowdLevel),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustBar extends StatelessWidget {
  final int trueCount;
  final int falseCount;
  final double pct;

  const _TrustBar({
    required this.trueCount,
    required this.falseCount,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    final total = trueCount + falseCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '✓ $trueCount doğru',
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              total == 0 ? 'Henüz oy yok' : '%${(pct * 100).round()} güven',
              style: TextStyle(
                color: total == 0
                    ? AppColors.muted
                    : (pct >= 0.6 ? AppColors.success : AppColors.warning),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$falseCount yanlış ✗',
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total == 0 ? 0.0 : pct,
            backgroundColor: AppColors.danger.withValues(alpha: 0.28),
            valueColor: AlwaysStoppedAnimation<Color>(
              pct >= 0.6 ? AppColors.success : AppColors.warning,
            ),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}

class _VoteBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _VoteBtn({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _VotedState extends StatelessWidget {
  final bool vote;
  final VoidCallback? onUndo;

  const _VotedState({required this.vote, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (vote ? AppColors.success : AppColors.danger)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (vote ? AppColors.success : AppColors.danger)
                  .withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            vote
                ? '✓  Bu bildirimi doğru buldunuz'
                : '✗  Bu bildirimi yanlış buldunuz',
            style: TextStyle(
              color: vote ? AppColors.success : AppColors.danger,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onUndo,
          child: const Text(
            'Oyumu geri al',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _HiddenBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: const Text(
        '⚠️ Bu bildirim topluluk oylamasıyla gizlendi.',
        style: TextStyle(
          color: AppColors.warning,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
