import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';

/// Check-in listesi — H5 sprint'te implemente edilecek.
class CheckinList extends StatelessWidget {
  // cleaned: placeholder liste, kullanıcıya durum anlatan iskelet ile güncellendi
  final String spotId;
  const CheckinList({super.key, required this.spotId});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Check-in Listesi',
              style: AppTextStyles.h3.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu mera için check-in kayıtları yakında burada listelenecek.',
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
