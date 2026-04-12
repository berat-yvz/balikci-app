import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/score_service.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';
import 'package:balikci_app/data/repositories/notification_repository.dart';

/// Birleşik oylama widget'ı.
///
/// - [checkin]: oy sayılarını (trueVotes/falseVotes) içeren model.
/// - [ownerUserId]: bildirim için (isteğe bağlı); kendi kendine oy [checkin.userId] ile engellenir.
class VoteWidget extends StatefulWidget {
  final CheckinModel checkin;
  final String? ownerUserId;
  final VoidCallback? onHidden;

  const VoteWidget({
    super.key,
    required this.checkin,
    this.ownerUserId,
    this.onHidden,
  });

  @override
  State<VoteWidget> createState() => _VoteWidgetState();
}

class _VoteWidgetState extends State<VoteWidget> {
  final _repo = CheckinRepository();

  bool _loading = true;
  bool _voting = false;
  bool? _myVote;
  bool _hidden = false;
  late int _trueCount;
  late int _falseCount;

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

  Future<void> _castOrToggle(bool vote) async {
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
      if (prevVote == true) _trueCount = (_trueCount - 1).clamp(0, 9999);
      if (prevVote == false) _falseCount = (_falseCount - 1).clamp(0, 9999);
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
          final ownerId = widget.ownerUserId ?? widget.checkin.userId;
          if (ownerId != uid) {
            await ScoreService.award(ownerId, ScoreSource.wrongReport);
          }
          setState(() => _hidden = true);
          widget.onHidden?.call();
        } else if (vote) {
          final ownerId = widget.ownerUserId ?? widget.checkin.userId;
          if (ownerId != uid) {
            await NotificationRepository().sendNotification(
              userId: ownerId,
              title: '👍 Bildiriminiz Doğru Bulundu',
              body: 'Bir balıkçı bildiriminizi doğru olarak değerlendirdi.',
              data: {
                'type': 'vote',
                'spot_id': widget.checkin.spotId,
              },
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _trueCount = prevTrue;
          _falseCount = prevFalse;
          _myVote = prevVote;
        });
        _snack(e.toString().replaceFirst('Exception: ', 'Oylama: '));
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 32,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (_hidden) return const _HiddenBanner();

    final currentUid = SupabaseService.auth.currentUser?.id;
    final isSelf =
        currentUid != null && currentUid == widget.checkin.userId;
    final total = _trueCount + _falseCount;
    final trueRatio = total > 0 ? _trueCount / total : 0.0;
    final communityDoubt = trueRatio < 0.5 && total >= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (total > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '✓ $_trueCount doğru',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.success,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '✗ $_falseCount yanlış',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.danger,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _TrustBar(trueRatio: trueRatio),
          const SizedBox(height: 5),
          Text(
            communityDoubt
                ? '⚠️ Topluluk bu raporu sorguluyor'
                : '👍 Topluluk bu raporu doğruluyor',
            style: AppTextStyles.caption.copyWith(
              color: communityDoubt ? AppColors.warning : AppColors.muted,
              fontSize: 14,
              fontWeight:
                  communityDoubt ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
        ] else ...[
          Text(
            'Henüz oy kullanılmadı. İlk sen oyla!',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.muted,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (isSelf)
          Text(
            'Kendi bildiriminize oy veremezsiniz.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.muted,
              fontSize: 15,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          )
        else if (_myVote == null) ...[
          Text(
            'Bu bildirim doğru mu?',
            style: AppTextStyles.body.copyWith(
              color: AppColors.foam,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _VoteBtn(
                  label: '✓  DOĞRU',
                  color: AppColors.success,
                  selected: false,
                  disabled: _voting,
                  onTap: () => _castOrToggle(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VoteBtn(
                  label: '✗  YANLIŞ',
                  color: AppColors.danger,
                  selected: false,
                  disabled: _voting,
                  onTap: () => _castOrToggle(false),
                ),
              ),
            ],
          ),
        ] else
          Row(
            children: [
              Icon(
                _myVote == true
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 30,
                color:
                    _myVote == true ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _myVote == true ? 'Doğru oyladınız' : 'Yanlış oyladınız',
                  style: AppTextStyles.body.copyWith(
                    color:
                        _myVote == true ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                height: 56,
                child: TextButton(
                  onPressed:
                      _voting ? null : () => _castOrToggle(_myVote!),
                  child: Text(
                    'Geri al',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.muted,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_off, size: 22, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Yeterli yanlış oy geldi — bu bildirim gizlendi.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.danger,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustBar extends StatelessWidget {
  final double trueRatio;
  const _TrustBar({required this.trueRatio});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        children: [
          Container(
            height: 10,
            color: AppColors.danger.withValues(alpha: 0.25),
          ),
          FractionallySizedBox(
            widthFactor: trueRatio.clamp(0.0, 1.0),
            child: Container(height: 10, color: AppColors.success),
          ),
        ],
      ),
    );
  }
}

class _VoteBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _VoteBtn({
    required this.label,
    required this.color,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 56,
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : color.withValues(alpha: 0.07),
            border: Border.all(
              color: disabled
                  ? AppColors.muted.withValues(alpha: 0.3)
                  : color.withValues(alpha: selected ? 1.0 : 0.65),
              width: selected ? 2.0 : 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: disabled ? AppColors.muted : color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
