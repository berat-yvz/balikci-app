import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';

/// İnternet bağlantısı / sunucu hatası ekranlarında gösterilen ortak hata widget'ı.
///
/// Tüm ekranlarda notification_list_screen referans düzeni kullanılır:
/// ikon → başlık → alt metin → tam genişlik "Tekrar Dene" butonu.
class NetworkErrorWidget extends StatelessWidget {
  final String title;
  final VoidCallback onRetry;

  const NetworkErrorWidget({
    super.key,
    required this.title,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.danger,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'İnternet bağlantınızı kontrol edin.',
              style: TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Tekrar Dene',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
