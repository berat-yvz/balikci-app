import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';

/// Yükleme göstergesi — tüm ekranlarda tutarlı kullanılır.
class LoadingWidget extends StatelessWidget {
  final String? message;
  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}
