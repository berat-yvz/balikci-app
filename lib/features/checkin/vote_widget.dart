import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';

/// Oylama widget'ı — INSERT/DELETE + optimistic UI.
class VoteWidget extends StatefulWidget {
  final String checkinId;
  final Map<bool, int> initialVoteCounts; // {true: n, false: n}
  final String currentUserId;

  const VoteWidget({
    super.key,
    required this.checkinId,
    required this.initialVoteCounts,
    required this.currentUserId,
  });

  @override
  State<VoteWidget> createState() => _VoteWidgetState();
}

class _VoteWidgetState extends State<VoteWidget> {
  final _repo = CheckinRepository();

  bool _voting = false;
  bool _hasVotedTrue = false;
  bool _hasVotedFalse = false;

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
      final response = await SupabaseService.client
          .from('checkin_votes')
          .select('vote')
          .eq('checkin_id', widget.checkinId)
          .eq('voter_id', widget.currentUserId)
          .maybeSingle();

      final vote = response?['vote'];
      if (!mounted) return;
      setState(() {
        _hasVotedTrue = vote == true;
        _hasVotedFalse = vote == false;
      });
    } catch (_) {
      // Oy yüklenemezse sadece butonları varsayılan (boş) bırakırız.
    }
  }

  Future<void> _submitOptimistic({required bool nextVote}) async {
    if (_voting) return;

    // Aynı oyu tekrar basma => unvote.
    final isSameAsCurrent =
        (nextVote == true && _hasVotedTrue) ||
        (nextVote == false && _hasVotedFalse);

    // Optimistic öncesi snapshot
    final prevHasVotedTrue = _hasVotedTrue;
    final prevHasVotedFalse = _hasVotedFalse;
    final prevTrueCount = _trueCount;
    final prevFalseCount = _falseCount;

    setState(() {
      _voting = true;

      if (isSameAsCurrent) {
        if (nextVote) {
          _trueCount = (_trueCount - 1).clamp(0, 1 << 30);
          _hasVotedTrue = false;
        } else {
          _falseCount = (_falseCount - 1).clamp(0, 1 << 30);
          _hasVotedFalse = false;
        }
      } else {
        // Mevcut oy varsa önce geri al, sonra yeni oy.
        // optimistic: eski sayımdan düş, yeni sayımda artır
        if (_hasVotedTrue) _trueCount = (_trueCount - 1).clamp(0, 1 << 30);
        if (_hasVotedFalse) {
          _falseCount = (_falseCount - 1).clamp(0, 1 << 30);
        }

        if (nextVote) {
          _trueCount = _trueCount + 1;
          _hasVotedTrue = true;
          _hasVotedFalse = false;
        } else {
          _falseCount = _falseCount + 1;
          _hasVotedFalse = true;
          _hasVotedTrue = false;
        }
      }
    });

    try {
      // Backend işlemi (unvote/insert).
      if (isSameAsCurrent) {
        await _repo.unvote(
          checkinId: widget.checkinId,
          voterId: widget.currentUserId,
        );
      } else {
        // Mevcut oy varsa unvote, sonra yeni oy insert
        if (_hasVotedTrue || _hasVotedFalse || isSameAsCurrent == false) {
          // Bu branch'te isSameAsCurrent false; şu an state optimistik
          // güncellendiği için, backend'de önce unvote gerekir.
          await _repo.unvote(
            checkinId: widget.checkinId,
            voterId: widget.currentUserId,
          );
        }
        await _repo.vote(
          checkinId: widget.checkinId,
          voterId: widget.currentUserId,
          vote: nextVote,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextVote ? 'Balıklı oy verildi' : 'Balıksız oy verildi'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasVotedTrue = prevHasVotedTrue;
          _hasVotedFalse = prevHasVotedFalse;
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
    final trueActive = _hasVotedTrue;
    final falseActive = _hasVotedFalse;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _VoteButton(
                active: trueActive,
                disabled: _voting,
                emoji: '👍',
                label: 'Balıklı',
                count: _trueCount,
                onPressed: () => _submitOptimistic(nextVote: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VoteButton(
                active: falseActive,
                disabled: _voting,
                emoji: '👎',
                label: 'Balıksız',
                count: _falseCount,
                onPressed: () => _submitOptimistic(nextVote: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Oyla: %${((_trueCount + _falseCount) == 0 ? 0 : (_trueCount * 100 / (_trueCount + _falseCount))).toStringAsFixed(0)} Balıklı',
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
    final bg = active ? AppColors.primary : Colors.white;
    final fg = active ? Colors.white : AppColors.primary;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: active
              ? BorderSide.none
              : BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
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
