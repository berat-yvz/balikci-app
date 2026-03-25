import 'package:flutter/material.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';

/// Oylama widget'ı — H6 sprint.
class VoteWidget extends StatefulWidget {
  final String checkinId;
  const VoteWidget({super.key, required this.checkinId});

  @override
  State<VoteWidget> createState() => _VoteWidgetState();
}

class _VoteWidgetState extends State<VoteWidget> {
  final _repo = CheckinRepository();
  bool _voting = false;

  Future<void> _vote(bool vote) async {
    if (_voting) return;
    final voterId = SupabaseService.auth.currentUser?.id;
    if (voterId == null) return;

    setState(() => _voting = true);
    try {
      await _repo.vote(
        checkinId: widget.checkinId,
        voterId: voterId,
        vote: vote,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vote ? 'Dogru oy verildi' : 'Yanlis oy verildi'),
        ),
      );
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _voting ? null : () => _vote(true),
          tooltip: 'Dogru',
          icon: const Icon(Icons.check_circle_outline),
        ),
        IconButton(
          onPressed: _voting ? null : () => _vote(false),
          tooltip: 'Yanlis',
          icon: const Icon(Icons.cancel_outlined),
        ),
      ],
    );
  }
}
