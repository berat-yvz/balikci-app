import 'package:flutter/material.dart';

/// Oylama widget'ı — H6 sprint'te implemente edilecek.
class VoteWidget extends StatelessWidget {
  final String checkinId;
  const VoteWidget({super.key, required this.checkinId});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline),
        SizedBox(width: 8),
        Icon(Icons.cancel_outlined),
      ],
    );
  }
}
