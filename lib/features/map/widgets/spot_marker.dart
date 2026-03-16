import 'package:flutter/material.dart';

/// Mera pin widget — H3 sprint'te privacy_level renklerine göre implemente edilecek.
class SpotMarker extends StatelessWidget {
  final String privacyLevel;
  const SpotMarker({super.key, required this.privacyLevel});

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.location_pin, size: 32);
  }
}
