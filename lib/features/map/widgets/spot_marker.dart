import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';

/// Mera pin widget.
class SpotMarker extends StatelessWidget {
  final String privacyLevel;
  const SpotMarker({super.key, required this.privacyLevel});

  Color _resolveColor() {
    switch (privacyLevel) {
      case 'friends':
        return AppColors.pinFriends;
      case 'private':
        return AppColors.pinPrivate;
      case 'vip':
        return AppColors.pinVip;
      case 'public':
      default:
        return AppColors.pinPublic;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.location_pin,
      size: 36,
      color: _resolveColor(),
    );
  }
}
