import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';

/// Oylama widget'ı — H6 sprint.
/// Oy gönderir, %70+ yanlış eşiği aşılırsa check-in'i gizler
/// ve [onHidden] callback'ini çağırır.
class VoteWidget extends StatefulWidget {
  final String checkinId;

  /// Check-in gizlendiğinde parent widget'ı bilgilendir.
  final VoidCallback? onHidden;

  const VoteWidget({
    super.key,
    required this.checkinId,
    this.onHidden,
  });

  @override
  State<VoteWidget> createState() => _VoteWidgetState();
}

class _VoteWidgetState extends State<VoteWidget> {
  final _repo = CheckinRepository();
  bool _voting = false;
  bool? _myVote; // kullanıcının oyladığı değer (null = henüz oy yok)
  bool _hidden = false;

  Future<void> _vote(bool vote) async {
    if (_voting || _myVote != null) return;
    final voterId = SupabaseService.auth.currentUser?.id;
    if (voterId == null) return;

    setState(() => _voting = true);
    try {
      await _repo.castVote(
        checkinId: widget.checkinId,
        voterId: voterId,
        voteValue: vote,
      );
      setState(() => _myVote = vote);

      // Oy gönderildikten sonra eşik kontrolü yap
      final wasHidden = await _repo.evaluateAndHide(widget.checkinId);

      if (!mounted) return;

      if (wasHidden) {
        setState(() => _hidden = true);
        widget.onHidden?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirim yeterli yanlış oy aldı ve gizlendi.'),
            backgroundColor: AppColors.danger,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vote ? '✓ Doğru oy verildi' : '✗ Yanlış oy verildi'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Oy gönderilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.visibility_off, size: 16, color: AppColors.danger),
            SizedBox(width: 6),
            Text(
              'Bu bildirim gizlendi.',
              style: TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final alreadyVoted = _myVote != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bu raporu doğruluyor musun?',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _VoteButton(
              label: 'Doğru',
              icon: Icons.check_circle_outline,
              color: AppColors.primary,
              selected: _myVote == true,
              disabled: _voting || alreadyVoted,
              onTap: () => _vote(true),
            ),
            const SizedBox(width: 12),
            _VoteButton(
              label: 'Yanlış',
              icon: Icons.cancel_outlined,
              color: AppColors.danger,
              selected: _myVote == false,
              disabled: _voting || alreadyVoted,
              onTap: () => _vote(false),
            ),
          ],
        ),
        if (alreadyVoted)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Oyunuz kaydedildi.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _VoteButton({
    required this.label,
    required this.icon,
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: selected ? color : Colors.grey.shade400,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: disabled && !selected ? Colors.grey : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: disabled && !selected ? Colors.grey : color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
