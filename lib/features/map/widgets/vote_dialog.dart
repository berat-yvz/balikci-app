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
/// `show` → `true` sadece bildirim bu oturumda gizlendiyse (eşik + `wrongReport` tetikleme).
class VoteDialog extends StatefulWidget {
  final CheckinModel checkin;

  const VoteDialog({super.key, required this.checkin});

  /// `true`: check-in gizlendi. Liste yenileme için [onClosed] her kapanışta çağrılır.
  static Future<bool> show(
    BuildContext context, {
    required CheckinModel checkin,
    Future<void> Function()? onClosed,
  }) async {
    var hidden = false;
    try {
      if (!context.mounted) return false;
      hidden = await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (_) => VoteDialog(checkin: checkin),
          ) ??
          false;
      return hidden;
    } finally {
      await onClosed?.call();
    }
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
        setState(() {
          _myVote = vote;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resyncCountsFromDb() async {
    try {
      final m = await _repo.getVoteCounts(widget.checkin.id);
      if (!mounted) return;
      setState(() {
        _trueCount = m[true] ?? 0;
        _falseCount = m[false] ?? 0;
      });
    } catch (_) {}
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _cast(bool vote) async {
    if (_voting) return;
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) return;

    final prevVote = _myVote;
    final prevTrue = _trueCount;
    final prevFalse = _falseCount;
    final toggling = _myVote == vote;
    final wasVisible = !widget.checkin.isHidden;

    setState(() {
      _voting = true;
      if (prevVote == true) _trueCount = (_trueCount - 1).clamp(0, 99999);
      if (prevVote == false) _falseCount = (_falseCount - 1).clamp(0, 99999);
      if (toggling) {
        _myVote = null;
      } else {
        _myVote = vote;
        if (vote) {
          _trueCount++;
        } else {
          _falseCount++;
        }
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
        var newlyHidden = false;
        try {
          newlyHidden = await _repo.evaluateAndHide(
            widget.checkin.id,
            checkinWasVisible: wasVisible,
          );
        } catch (e) {
          _snack(e.toString().replaceFirst('Exception: ', ''));
          await _resyncCountsFromDb();
        }

        if (!mounted) return;

        if (newlyHidden) {
          final ownerId = widget.checkin.userId;
          if (ownerId != uid) {
            unawaited(
              ScoreService.award(ownerId, ScoreSource.wrongReport),
            );
          }
          setState(() => _hidden = true);
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          if (mounted) Navigator.of(context).pop(true);
          return;
        }

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
      }

      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context).pop(false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _trueCount = prevTrue;
          _falseCount = prevFalse;
          _myVote = prevVote;
        });
        _snack(
          e.toString().replaceFirst('Exception: ', 'Oylama: '),
        );
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.auth.currentUser?.id;
    final isSelf = uid != null && uid == widget.checkin.userId;
    final total = _trueCount + _falseCount;
    final trustPct = total == 0 ? 0.0 : (_trueCount / total).clamp(0.0, 1.0);

    final maxH = MediaQuery.sizeOf(context).height * 0.85;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '🎣  Bu Bildirim Doğru mu?',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.foam,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _CheckinSummaryCard(checkin: widget.checkin),
                const SizedBox(height: 14),
                _TrustBar(
                  trueCount: _trueCount,
                  falseCount: _falseCount,
                  pct: trustPct,
                ),
                const SizedBox(height: 18),
                if (_hidden) ...[
                  const _HiddenBanner(),
                ] else if (_loading) ...[
                  const SizedBox(
                    height: 56,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                ] else if (isSelf) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.muted.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Kendi bildiriminize oy veremezsiniz.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else if (_myVote != null) ...[
                  _VotedState(
                    vote: _myVote!,
                    onUndo: _voting ? null : () => _cast(_myVote!),
                  ),
                ] else ...[
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
                SizedBox(
                  height: 56,
                  child: TextButton(
                    onPressed: () {
                      if (!context.mounted) return;
                      Navigator.of(context).pop(false);
                    },
                    child: Text(
                      'İptal',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
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
        color: AppColors.foam.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.foam.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, color: AppColors.muted, size: 20),
              const SizedBox(width: 8),
              Text(
                _formatAgo(checkin.createdAt),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
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
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.foam,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (checkin.fishSpecies.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        checkin.fishSpecies.join(' · '),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.sand,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.muted,
                  fontSize: 15,
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
              style: AppTextStyles.caption.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            Text(
              total == 0 ? 'Henüz oy yok' : '%${(pct * 100).round()} güven',
              style: AppTextStyles.caption.copyWith(
                color: total == 0
                    ? AppColors.muted
                    : (pct >= 0.6 ? AppColors.success : AppColors.warning),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            Text(
              '$falseCount yanlış ✗',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w800,
                fontSize: 15,
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
          foregroundColor: AppColors.foam,
          disabledBackgroundColor: color.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: AppColors.foam,
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
            style: AppTextStyles.body.copyWith(
              color: vote ? AppColors.success : AppColors.danger,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: TextButton(
            onPressed: onUndo,
            child: Text(
              'Oyumu geri al',
              style: AppTextStyles.body.copyWith(
                color: AppColors.muted,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HiddenBanner extends StatelessWidget {
  const _HiddenBanner();

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
      child: Text(
        '⚠️ Bu bildirim topluluk oylamasıyla gizlendi.',
        style: AppTextStyles.body.copyWith(
          color: AppColors.warning,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
