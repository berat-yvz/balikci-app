import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';

/// Düğüm filtre widget'ı — H11 sprint'te implemente edilecek.
class KnotFilterWidget extends StatelessWidget {
  // cleaned: boş placeholder yerine minimum çalışan filtre iskeleti eklendi
  const KnotFilterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.filter_alt_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Filtre seçenekleri yakında eklenecek.',
                style: AppTextStyles.caption.copyWith(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
