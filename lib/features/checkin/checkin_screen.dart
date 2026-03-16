import 'package:flutter/material.dart';

/// Check-in ekranı — H5 sprint'te implemente edilecek.
/// M-03 Anlık Check-in & Doğrulama — MVP_PLAN.md referans.
class CheckinScreen extends StatelessWidget {
  final String spotId;
  const CheckinScreen({super.key, required this.spotId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Check-in — H5 Sprint')),
    );
  }
}
