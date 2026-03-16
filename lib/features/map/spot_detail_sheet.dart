import 'package:flutter/material.dart';

/// Mera detay alt sheet — H3 sprint'te implemente edilecek.
class SpotDetailSheet extends StatelessWidget {
  final String spotId;
  const SpotDetailSheet({super.key, required this.spotId});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 300,
      child: Center(child: Text('Mera Detayı — H3 Sprint')),
    );
  }
}
