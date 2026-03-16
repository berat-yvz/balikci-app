import 'package:flutter/material.dart';

/// Hava kartı widget'ı — H9 sprint'te implemente edilecek.
class WeatherCardWidget extends StatelessWidget {
  const WeatherCardWidget({super.key});
  @override
  Widget build(BuildContext context) =>
      const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Hava')));
}
