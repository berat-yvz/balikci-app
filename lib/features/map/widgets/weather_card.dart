import 'package:flutter/material.dart';

/// Harita üzerindeki hava kartı widget'ı — H9 sprint'te implemente edilecek.
class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Text('Hava Durumu — H9 Sprint'),
      ),
    );
  }
}
