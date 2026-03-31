import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';

/// EXIF doğrulama durumu rozeti.
/// - `null`  : doğrulanıyor (pending)
/// - `true`  : doğrulandı (ok)
/// - `false` : eşleşmedi (fail)
class ExifBadge extends StatelessWidget {
  final bool? exifVerified;

  const ExifBadge({super.key, required this.exifVerified});

  @override
  Widget build(BuildContext context) {
    final pending = exifVerified == null;
    final ok = exifVerified == true;
    final fail = exifVerified == false;

    final (bg, fg, icon, text) = switch (true) {
      _ when pending =>
        (AppColors.primaryLight, AppColors.primary, '⏳', 'EXIF doğrulanıyor...'),
      _ when ok =>
        (Colors.green.withValues(alpha: 0.16), Colors.green.shade800, '✅', 'EXIF doğrulandı (+bonus puan)'),
      _ when fail =>
        (AppColors.danger.withValues(alpha: 0.14), AppColors.danger, '❌', 'EXIF eşleşmedi'),
      _ => (AppColors.primaryLight, AppColors.primary, '⏳', 'EXIF doğrulanıyor...'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

