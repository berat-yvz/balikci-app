import 'package:flutter/material.dart';

/// Düğüm detayı — H11 sprint'te implemente edilecek.
class KnotDetailScreen extends StatelessWidget {
  final String knotId;
  const KnotDetailScreen({super.key, required this.knotId});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Düğüm Detayı — H11')));
}
