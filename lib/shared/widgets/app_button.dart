import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';

/// Uygulamanın tüm primary butonları için ortak widget.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        child: _child,
      );
    }
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: _child,
    );
  }

  Widget get _child => isLoading
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
      : Text(label, style: AppTextStyles.body);
}
