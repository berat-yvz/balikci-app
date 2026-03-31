import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';

/// Oylama widget'ı — INSERT/DELETE + optimistic UI.
class VoteWidget extends StatefulWidget {
  final String checkinId;
  final Map<bool, int> initialVoteCounts; // {true: n, false: n}
  final String currentUserId;
  final String checkinOwnerId;

  const VoteWidget({
    super.key,
    required this.checkinId,
    required this.initialVoteCounts,
    required this.currentUserId,
    required this.checkinOwnerId,
  });

  @override
  State<VoteWidget> createState() => _VoteWidgetState();
}

class _VoteWidgetState extends State<VoteWidget> {
  final _repo = CheckinRepository();

  bool _voting = false;
  bool? _myVote;

  late int _trueCount;
  late int _falseCount;

  @override
  void initState() {
    super.initState();
    _trueCount = widget.initialVoteCounts[true] ?? 0;
    _falseCount = widget.initialVoteCounts[false] ?? 0;
    _loadMyExistingVote();
  }

  Future<void> _loadMyExistingVote() async {
    try {
      final vote = await _repo.getUserVote(widget.checkinId, widget.currentUserId);
      if (!mounted) return;
      setState(() {
        _myVote = vote;
      });
    } catch (_) {
      // Oy yüklenemezse sadece butonları varsayılan (boş) bırakırız.
    }
  }

  Future<void> _submitOptimistic({required bool nextVote}) async {
    if (_voting) return;
    final isOwner = widget.checkinOwnerId == widget.currentUserId;
    final isGuest = widget.currentUserId.isEmpty;
    if (isOwner || isGuest) return;

    // Aynı oyu tekrar basma => unvote.
    final isSameAsCurrent = _myVote == nextVote;
    final prevVote = _myVote;

    // Optimistic öncesi snapshot
    final prevTrueCount = _trueCount;
    final prevFalseCount = _falseCount;

    setState(() {
      _voting = true;

      if (isSameAsCurrent) {
        if (nextVote) {
          _trueCount = (_trueCount - 1).clamp(0, 1 << 30);
        } else {
          _falseCount = (_falseCount - 1).clamp(0, 1 << 30);
        }
        _myVote = null;
      } else {
        // Mevcut oy varsa önce geri al, sonra yeni oy.
        // optimistic: eski sayımdan düş, yeni sayımda artır
        if (_myVote == true) _trueCount = (_trueCount - 1).clamp(0, 1 << 30);
        if (_myVote == false) {
          _falseCount = (_falseCount - 1).clamp(0, 1 << 30);
        }

        if (nextVote) {
          _trueCount = _trueCount + 1;
          _myVote = true;
        } else {
          _falseCount = _falseCount + 1;
          _myVote = false;
        }
      }
    });

    try {
      await _repo.castVote(
        checkinId: widget.checkinId,
        voterId: widget.currentUserId,
        voteValue: nextVote,
      );
      if (!mounted) return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _myVote = prevVote;
          _trueCount = prevTrueCount;
          _falseCount = prevFalseCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Oylama başarısız: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _voting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trueActive = _myVote == true;
    final falseActive = _myVote == false;
    final isOwner = widget.checkinOwnerId == widget.currentUserId;
    final isGuest = widget.currentUserId.isEmpty;
    final total = _trueCount + _falseCount;
    final successRatio = total == 0 ? 0.0 : _trueCount / total;
    final successPercent = (successRatio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isOwner)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              "Kendi check-in'ine oy veremezsiniz",
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ),
        if (isGuest)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Oy verebilmek için giriş yapın',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _VoteButton(
                active: trueActive,
                disabled: _voting || isOwner || isGuest,
                emoji: '✓',
                label: 'Doğru',
                count: _trueCount,
                onPressed: () => _submitOptimistic(nextVote: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VoteButton(
                active: falseActive,
                disabled: _voting || isOwner || isGuest,
                emoji: '✗',
                label: 'Yanlış',
                count: _falseCount,
                onPressed: () => _submitOptimistic(nextVote: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: successRatio,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(AppColors.success),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$_trueCount doğru, $_falseCount yanlış — %$successPercent doğru',
          style: AppTextStyles.caption.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  final bool active;
  final bool disabled;
  final String emoji;
  final String label;
  final int count;
  final VoidCallback onPressed;

  const _VoteButton({
    required this.active,
    required this.disabled,
    required this.emoji,
    required this.label,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.primary : AppColors.surface;
    final fg = Colors.white;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
      ),
      onPressed: disabled ? null : onPressed,
      child: Text(
        '$emoji $label ($count)',
        style: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.w900,
          color: fg,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
