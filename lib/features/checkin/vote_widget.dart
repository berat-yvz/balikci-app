import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';
import 'package:balikci_app/data/repositories/notification_repository.dart';

/// Birleşik oylama widget'ı.
///
/// - [checkin]: oy sayılarını (trueVotes/falseVotes) içeren model.
/// - [ownerUserId]: check-in sahibinin ID'si — kendi bildirimine oy veremez.
/// - init'te DB'den kullanıcının mevcut oyunu çeker.
/// - Oy verilince optimistik güncelleme yapar; hata olursa geri alır.
/// - Aynı butona tekrar basmak oyu geri alır (toggle).
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

  Future<void> _castOrToggle(bool vote) async {
    if (_voting) return;
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) return;

    // Mevcut durumu yedekle (hata rollback için)
    final prevVote = _myVote;
    final prevTrue = _trueCount;
    final prevFalse = _falseCount;
    final toggling = _myVote == vote; // aynı oya basıldı = geri al

    // Optimistik güncelleme
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
        final wasHidden = await _repo.evaluateAndHide(widget.checkin.id);
        if (!mounted) return;
        if (wasHidden) {
          setState(() => _hidden = true);
          widget.onHidden?.call();
        }

        // Pozitif oy verilince check-in sahibini bilgilendir
        final ownerId = widget.ownerUserId;
        if (vote && ownerId != null && ownerId != uid) {
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
    } catch (_) {
      // Rollback
      if (mounted) {
        setState(() {
          _trueCount = prevTrue;
          _falseCount = prevFalse;
          _myVote = prevVote;
        });
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 28,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hidden) return const _HiddenBanner();

    final currentUid = SupabaseService.auth.currentUser?.id;
    final isSelf = currentUid != null && currentUid == widget.ownerUserId;
    final total = _trueCount + _falseCount;
    final trueRatio = total > 0 ? _trueCount / total : 0.0;
    final communityDoubt = trueRatio < 0.5 && total >= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Güven çubuğu (oy varsa) ──────────────────
        if (total > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '✓ $_trueCount doğru',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '✗ $_falseCount yanlış',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
            style: TextStyle(
              color: communityDoubt ? AppColors.warning : AppColors.muted,
              fontSize: 12,
              fontWeight:
                  communityDoubt ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),
        ] else ...[
          const Text(
            'Henüz oy kullanılmadı. İlk sen oyla!',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
        ],

        // ── Oy butonları / sonuç ─────────────────────
        if (isSelf)
          const Text(
            'Kendi bildirimine oy veremezsin.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          )
        else if (_myVote == null) ...[
          const Text(
            'Bu bildirim doğru mu?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
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
                size: 20,
                color:
                    _myVote == true ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 7),
              Text(
                _myVote == true ? 'Doğru oyladınız' : 'Yanlış oyladınız',
                style: TextStyle(
                  color:
                      _myVote == true ? AppColors.success : AppColors.danger,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _voting ? null : () => _castOrToggle(_myVote!),
                child: const Text(
                  'Geri al',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Yardımcı widget'lar ──────────────────────────────────────────────────────

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
      child: const Row(
        children: [
          Icon(Icons.visibility_off, size: 16, color: AppColors.danger),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Yeterli yanlış oy geldi — bu bildirim gizlendi.',
              style: TextStyle(color: AppColors.danger, fontSize: 13),
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
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 52,
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
            style: TextStyle(
              color: disabled ? AppColors.muted : color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
