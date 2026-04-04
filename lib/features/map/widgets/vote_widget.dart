import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

class VoteWidget extends ConsumerStatefulWidget {
  final String checkinId;
  final String checkinUserId;
  final bool isVerified;
  final int trueVotes;
  final int falseVotes;

  const VoteWidget({
    super.key,
    required this.checkinId,
    required this.checkinUserId,
    this.isVerified = false,
    this.trueVotes = 0,
    this.falseVotes = 0,
  });

  @override
  ConsumerState<VoteWidget> createState() => _VoteWidgetState();
}

class _VoteWidgetState extends ConsumerState<VoteWidget> {
  bool _hasVoted = false;
  bool _isOwnCheckin = false;
  bool _isLoading = false;
  late int _trueVotes;
  late int _falseVotes;

  @override
  void initState() {
    super.initState();
    _trueVotes = widget.trueVotes;
    _falseVotes = widget.falseVotes;
    _checkIfVoted();
  }

  Future<void> _checkIfVoted() async {
    try {
      final userId = SupabaseService.auth.currentUser?.id;
      if (userId == null) return;
      if (userId == widget.checkinUserId) {
        if (mounted) {
          setState(() {
            _isOwnCheckin = true;
            _hasVoted = true;
          });
        }
        return;
      }
      final response = await SupabaseService.client
          .from('checkin_votes')
          .select('id')
          .eq('checkin_id', widget.checkinId)
          .eq('voter_id', userId)
          .maybeSingle();
      if (mounted && response != null) setState(() => _hasVoted = true);
    } catch (e) {
      debugPrint('Oy durumu kontrol edilemedi: $e');
    }
  }

  Future<void> _vote(String voteType) async {
    if (_hasVoted || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.auth.currentUser?.id;
      if (userId == null) return;
      await SupabaseService.client
          .from('checkin_votes')
          .insert({
        'checkin_id': widget.checkinId,
        'voter_id': userId,
        'vote_type': voteType,
      });
      setState(() {
        _hasVoted = true;
        if (voteType == 'true') { _trueVotes++; }
        else { _falseVotes++; }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Oyunuz alındı 👍',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Oy verilemedi, tekrar deneyin',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Doğrulanmış rozet
        if (widget.isVerified)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              border: Border.all(color: const Color(0xFFFFC107), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, color: Color(0xFFFFC107), size: 28),
                SizedBox(width: 8),
                Text(
                  'DOĞRULANDI ✓',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF795548),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

        const Text(
          'Bu bilgi doğru mu?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Doğru: $_trueVotes  •  Yanlış: $_falseVotes',
          style: const TextStyle(fontSize: 15, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        if (_hasVoted)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isOwnCheckin ? Colors.blue.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isOwnCheckin
                    ? Colors.blue.shade300
                    : Colors.green.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isOwnCheckin ? Icons.info_outline : Icons.check_circle,
                  color: _isOwnCheckin ? Colors.blue : Colors.green,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  _isOwnCheckin ? 'Kendi bildiriminiz' : 'Oyunuz alındı 👍',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isOwnCheckin ? Colors.blue : Colors.green,
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _vote('true'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle, size: 28),
                    label: const Text(
                      'DOĞRU',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _vote('false'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.cancel, size: 28),
                    label: const Text(
                      'YANLIŞ',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
