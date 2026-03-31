import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';

/// Hava durumu detay ekranı — H9 sprint'te implemente edilecek.
class WeatherScreen extends StatelessWidget {
  // cleaned: placeholder ekran, tema uyumlu iskelete çevrildi
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hava Durumu')),
      body: Center(
        child: Text(
          'Bu bölüm yakında detaylı hava verileriyle güncellenecek.',
          style: AppTextStyles.body.copyWith(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
