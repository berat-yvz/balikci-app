import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/shared/providers/fish_log_provider.dart';
import 'package:balikci_app/shared/widgets/error_widget.dart';
import 'package:balikci_app/shared/widgets/loading_widget.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(fishLogStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Av İstatistikleri'),
      ),
      body: asyncStats.when(
        data: (stats) {
          final total = stats['totalLogs'] as int? ?? 0;
          final totalWeight = (stats['totalWeightKg'] as double? ?? 0)
              .toStringAsFixed(1);
          final topSpecies = (stats['topSpecies'] as List)
              .cast<Map<String, dynamic>>();

          if (total == 0) {
            return const Center(
              child: Text('Henüz istatistik oluşturacak kadar kayıt yok.'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  'Genel Bakış',
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatTile(
                      label: 'Toplam kayıt',
                      value: '$total',
                      icon: Icons.list_alt_outlined,
                    ),
                    const SizedBox(width: 12),
                    _StatTile(
                      label: 'Toplam ağırlık',
                      value: '$totalWeight kg',
                      icon: Icons.scale_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'En Çok Tutulan Türler',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: _SpeciesBarChart(data: topSpecies),
                ),
              ],
            ),
          );
        },
        loading: () =>
            const LoadingWidget(message: 'İstatistikler hesaplanıyor...'),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(fishLogStatsProvider),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeciesBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _SpeciesBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpeciesBarChartPainter(data),
      child: Container(),
    );
  }
}

class _SpeciesBarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  _SpeciesBarChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()..color = AppColors.primary;
    final textPainter = TextPainter(
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );

    final maxCount = data
        .map((e) => e['count'] as int? ?? 0)
        .fold<int>(0, (prev, el) => el > prev ? el : prev);
    if (maxCount == 0) return;

    final barHeight = size.height / (data.length * 1.8);
    final maxBarWidth = size.width * 0.7;

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final species = item['species'] as String? ?? '';
      final count = item['count'] as int? ?? 0;

      final normalized = count / maxCount;
      final barWidth = maxBarWidth * normalized;

      final top = i * barHeight * 1.8 + 8;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, barWidth, barHeight),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, paint);

      // Tür ismi
      textPainter.text = TextSpan(
        text: species,
        style: AppTextStyles.caption.copyWith(color: AppColors.dark),
      );
      textPainter.layout(maxWidth: size.width - barWidth - 8);
      textPainter.paint(
        canvas,
        Offset(barWidth + 8, top),
      );

      // Adet
      textPainter.text = TextSpan(
        text: 'x$count',
        style: AppTextStyles.caption.copyWith(color: AppColors.muted),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(barWidth + 8, top + barHeight / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeciesBarChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

