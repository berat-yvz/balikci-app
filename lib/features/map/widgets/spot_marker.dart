import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';

/// Mera pin widget.
class SpotMarker extends StatelessWidget {
  final String privacyLevel;
  final int activeCheckinCount;
  final bool hasStaleCheckins;

  const SpotMarker({
    super.key,
    required this.privacyLevel,
    this.activeCheckinCount = 0,
    this.hasStaleCheckins = false,
  });

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
    final opacity = hasStaleCheckins ? 0.5 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ikon rengini ayrı wrapper içinde veriyoruz (Opacity + Stack ile birlikte).
          Positioned.fill(
            child: Icon(
              Icons.location_pin,
              size: 36,
              color: _resolveColor(),
            ),
          ),
          if (activeCheckinCount > 0)
            Positioned(
              right: -6,
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF185FA5).withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  activeCheckinCount > 9 ? '9+' : activeCheckinCount.toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
