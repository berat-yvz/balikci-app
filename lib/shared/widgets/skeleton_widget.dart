import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';

/// Yükleme sırasında liste satırı iskelet göstergesi.
/// Shimmer paketi gerektirmez — AnimatedOpacity ile titreşim efekti.
class SkeletonListTile extends StatefulWidget {
  final bool hasLeadingCircle;
  final bool hasTrailing;

  const SkeletonListTile({
    super.key,
    this.hasLeadingCircle = false,
    this.hasTrailing = false,
  });

  @override
  State<SkeletonListTile> createState() => _SkeletonListTileState();
}

class _SkeletonListTileState extends State<SkeletonListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        final color = AppColors.muted.withValues(alpha: _opacity.value);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (widget.hasLeadingCircle) ...[
                _SkeletonBox(width: 40, height: 40, borderRadius: 20, color: color),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(
                      width: double.infinity,
                      height: 14,
                      color: color,
                    ),
                    const SizedBox(height: 6),
                    _SkeletonBox(width: 120, height: 11, color: color),
                  ],
                ),
              ),
              if (widget.hasTrailing) ...[
                const SizedBox(width: 12),
                _SkeletonBox(width: 48, height: 14, color: color),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color color;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 6,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Birden fazla iskelet satırı — liste yüklenirken kullan.
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final bool hasLeadingCircle;
  final bool hasTrailing;

  const SkeletonList({
    super.key,
    this.itemCount = 7,
    this.hasLeadingCircle = false,
    this.hasTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => SkeletonListTile(
        hasLeadingCircle: hasLeadingCircle,
        hasTrailing: hasTrailing,
      ),
    );
  }
}
