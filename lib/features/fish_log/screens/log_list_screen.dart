import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/shared/widgets/empty_state_widget.dart';
import 'package:balikci_app/shared/widgets/error_widget.dart';
import 'package:balikci_app/shared/widgets/loading_widget.dart';
import '../../../data/local/database.dart';
import '../../../shared/providers/fish_log_provider.dart';

final fishLogsProvider = FutureProvider<List<FishLog>>((ref) async {
  return ref.read(fishLogRepositoryProvider).getLogs();
});

/// ADIM 6: Balık günlüğü listesi — swipe-to-delete, tür bazlı ikon, ağırlık büyük.
class LogListScreen extends ConsumerWidget {
  const LogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(fishLogsProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Balık Günlüğüm'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, size: 28),
            tooltip: 'İstatistikler',
            onPressed: () => context.push('/fish-log/stats'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 28),
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(fishLogsProvider),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () =>
            const LoadingWidget(message: 'Kayıtlar yükleniyor...'),
        error: (e, _) => AppErrorWidget(
          message: 'Kayıtlar yüklenemedi',
          onRetry: () => ref.invalidate(fishLogsProvider),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return EmptyStateWidget.noFishLogs(
              buttonLabel: 'İlk Balığını Ekle',
              onButtonPressed: () async {
                await context.push('/fish-log/add');
                ref.invalidate(fishLogsProvider);
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(fishLogsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return _SwipableLogCard(
                  log: log,
                  onDeleted: () => ref.invalidate(fishLogsProvider),
                );
              },
            ),
          );
        },
      ),
      // Balık ekle FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/fish-log/add');
          ref.invalidate(fishLogsProvider);
        },
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 26),
        label: const Text(
          'Balık Ekle',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// ADIM 6: Swipe-to-delete destekli kart.
class _SwipableLogCard extends ConsumerWidget {
  final FishLog log;
  final VoidCallback onDeleted;

  const _SwipableLogCard({required this.log, required this.onDeleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 32),
            SizedBox(height: 4),
            Text(
              'Sil',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Kaydı Sil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            content: Text(
              '${log.fishType} kaydı silinecek. Emin misiniz?',
              style: const TextStyle(fontSize: 17),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal', style: TextStyle(fontSize: 16)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                child: const Text('Sil',
                    style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await ref.read(fishLogRepositoryProvider).deleteLog(log.id);
        onDeleted();
      },
      child: _LogCard(log: log, onDeleted: onDeleted),
    );
  }
}

class _LogCard extends ConsumerWidget {
  final FishLog log;
  final VoidCallback onDeleted;

  const _LogCard({required this.log, required this.onDeleted});

  String _fishEmoji(String fishType) {
    return switch (fishType.toLowerCase()) {
      'levrek' => '🐟',
      'çipura' => '🐠',
      'palamut' => '🐡',
      'lüfer' => '🐟',
      'kefal' => '🐟',
      'alabalık' => '🐡',
      'hamsi' => '🐟',
      _ => '🎣',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: const Color(0xFF132236),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.teal.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fotoğraf
            if (log.photoUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  log.photoUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, err, stack) => Container(
                    height: 100,
                    color: const Color(0xFF0B1C33),
                    child: const Center(
                        child: Icon(Icons.image_not_supported,
                            size: 40, color: AppColors.muted)),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ADIM 6: Sol tarafta balık ikonu (tür bazlı)
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Center(
                      child: Text(
                        _fishEmoji(log.fishType),
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                log.fishType,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // ADIM 6: Ağırlık büyük 20sp bold
                            if (log.weightKg != null)
                              Text(
                                '${log.weightKg!.toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // ADIM 6: Konum ve tarih ikinci satır, 14sp muted
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 14, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(log.caughtAt),
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.muted),
                            ),
                            if (log.lengthCm != null) ...[
                              const SizedBox(width: 12),
                              const Icon(Icons.straighten,
                                  size: 14, color: AppColors.muted),
                              const SizedBox(width: 4),
                              Text(
                                '${log.lengthCm!.toStringAsFixed(0)} cm',
                                style: const TextStyle(
                                    fontSize: 14, color: AppColors.muted),
                              ),
                            ],
                          ],
                        ),
                        // Rozetler
                        if (log.isReleased || log.isPrivate || !log.synced) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (log.isReleased)
                                _Badge(label: '🔄 Bırakıldı'),
                              if (log.isPrivate)
                                _Badge(label: '🔒 Gizli'),
                              if (!log.synced)
                                const Tooltip(
                                  message: 'Senkronize edilmedi',
                                  child: Icon(Icons.cloud_off,
                                      color: AppColors.muted, size: 20),
                                ),
                            ],
                          ),
                        ],
                        // Not
                        if (log.notes != null && log.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            log.notes!,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white60),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1C33),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
