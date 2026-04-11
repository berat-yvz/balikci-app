import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/fish_log_model.dart';
import 'package:balikci_app/shared/providers/fish_log_provider.dart';
import 'package:balikci_app/shared/widgets/empty_state_widget.dart';
import 'package:balikci_app/shared/widgets/error_widget.dart';
import 'package:balikci_app/shared/widgets/skeleton_widget.dart';

/// Av istatistikleri ekranı — Riverpod ile yönetilen.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(myFishLogsProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('İstatistiklerim')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(AppRoutes.fishLogAdd);
          ref.invalidate(myFishLogsProvider);
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 26),
        label: const Text(
          'Yeni Kayıt',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      body: logsAsync.when(
        loading: () => const SkeletonList(
          itemCount: 5,
          hasLeadingCircle: false,
          hasTrailing: false,
        ),
        error: (e, _) => AppErrorWidget(
          message: 'İstatistikler yüklenemedi',
          onRetry: () => ref.invalidate(myFishLogsProvider),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return EmptyStateWidget.noFishLogs(
              buttonLabel: 'İlk Balığını Ekle',
              onButtonPressed: () async {
                await context.push(AppRoutes.fishLogAdd);
                ref.invalidate(myFishLogsProvider);
              },
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myFishLogsProvider),
            child: _StatsBody(logs: logs),
          );
        },
      ),
    );
  }
}

// ── Yardımcı hesaplamalar ─────────────────────────────────────────────────────

int _total(List<FishLogModel> logs) => logs.length;

int _released(List<FishLogModel> logs) =>
    logs.where((l) => l.released).length;

int _sustainPercent(List<FishLogModel> logs) {
  final total = _total(logs);
  return total == 0 ? 0 : (_released(logs) / total * 100).round();
}

List<MapEntry<String, int>> _topSpecies(List<FishLogModel> logs) {
  final map = <String, int>{};
  for (final l in logs) {
    map[l.species] = (map[l.species] ?? 0) + 1;
  }
  return (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(3)
      .toList();
}

Map<String, int> _monthlyCounts(List<FishLogModel> logs) {
  final now = DateTime.now();
  final result = <String, int>{};
  for (var i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i);
    final key = DateFormat('MMM', 'tr_TR').format(month);
    result[key] = 0;
  }
  for (final log in logs) {
    final key = DateFormat('MMM', 'tr_TR').format(log.createdAt);
    if (result.containsKey(key)) result[key] = result[key]! + 1;
  }
  return result;
}

// ── İçerik widget'ı ───────────────────────────────────────────────────────────

class _StatsBody extends StatelessWidget {
  final List<FishLogModel> logs;
  const _StatsBody({required this.logs});

  @override
  Widget build(BuildContext context) {
    final total = _total(logs);
    final released = _released(logs);
    final sustainPct = _sustainPercent(logs);
    final topSpecies = _topSpecies(logs);
    final monthly = _monthlyCounts(logs);
    final maxMonthly = monthly.values.fold(0, (a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Özet kartları ──────────────────────────────
        Row(children: [
          _StatCard(label: 'Toplam av', value: '$total'),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Salınan',
            value: '$released',
            color: AppColors.secondary,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Sürdür. %',
            value: '$sustainPct',
            color: sustainPct >= 50 ? AppColors.primary : AppColors.accent,
          ),
        ]),
        const SizedBox(height: 20),

        // ── En çok tutulan türler ──────────────────────
        if (topSpecies.isNotEmpty) ...[
          Text(
            'En çok tutulan türler',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ...topSpecies.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final species = entry.value.key;
            final count = entry.value.value;
            final pct = total > 0 ? count / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '$rank.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.muted),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            species,
                            style: AppTextStyles.caption
                                .copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '$count av',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor:
                              AppColors.muted.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            );
          }),
          const SizedBox(height: 20),
        ],

        // ── Aylık bar grafik ───────────────────────────
        Text(
          'Son 6 ay',
          style: AppTextStyles.caption
              .copyWith(color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: monthly.entries.map((e) {
              final barPct = maxMonthly == 0 ? 0.0 : e.value / maxMonthly;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (e.value > 0)
                        Text(
                          '${e.value}',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12, // 10 → 12 (hedef kitle)
                            color: AppColors.primary,
                          ),
                        ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: barPct * 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.key,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12, // 10 → 12 (hedef kitle)
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // ── Sürdürülebilirlik kartı ────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Row(children: [
            const Text('🌊', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sürdürülebilirlik skoru',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$sustainPct% · $released / $total balık salındı',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 80), // FAB için boşluk
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatCard({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.foam;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF132236),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.muted.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Column(children: [
          Text(
            value,
            style: AppTextStyles.h2.copyWith(color: c, fontSize: 24),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}
