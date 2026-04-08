import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/theme.dart';
import '../../../data/local/database.dart';
import '../../../shared/providers/fish_log_provider.dart';

final fishLogsProvider = FutureProvider<List<FishLog>>((ref) async {
  return ref.read(fishLogRepositoryProvider).getLogs();
});

class LogListScreen extends ConsumerWidget {
  const LogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(fishLogsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Text(
          '🎣 Balık Günlüğüm',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, size: 28, color: Colors.white),
            tooltip: 'İstatistikler',
            onPressed: () => context.push('/fish-log/stats'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 28, color: Colors.white),
            onPressed: () => ref.invalidate(fishLogsProvider),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: AppColors.danger),
              const SizedBox(height: 16),
              const Text(
                'Kayıtlar yüklenemedi',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(fishLogsProvider),
                child: const Text('Tekrar Dene',
                    style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🐟', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  const Text(
                    'Henüz kayıt yok',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'İlk balığını kaydet!',
                    style: TextStyle(
                        fontSize: 15, color: Color(0xFF8EA0B5)),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await context.push('/fish-log/add');
                        ref.invalidate(fishLogsProvider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 28),
                      label: const Text(
                        'Yeni Kayıt Ekle',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(fishLogsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return _LogCard(
                  log: log,
                  onDeleted: () => ref.invalidate(fishLogsProvider),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _LogCard extends ConsumerWidget {
  final FishLog log;
  final VoidCallback onDeleted;

  const _LogCard({required this.log, required this.onDeleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF132236),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.teal.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fotoğraf varsa göster
          if (log.photoUrl != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                log.photoUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context2, err, stack) => Container(
                  height: 180,
                  color: const Color(0xFF0B1C33),
                  child: const Icon(Icons.image_not_supported,
                      size: 48, color: AppColors.muted),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tür + rozetler
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.fishType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (log.isReleased)
                      _Badge(label: '🔄 Bırakıldı'),
                    if (log.isPrivate) ...[
                      const SizedBox(width: 6),
                      _Badge(label: '🔒 Gizli'),
                    ],
                    if (!log.synced) ...[
                      const SizedBox(width: 6),
                      const Tooltip(
                        message: 'Senkronize edilmedi',
                        child: Icon(Icons.cloud_off,
                            color: AppColors.muted, size: 22),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Ağırlık ve uzunluk
                Row(
                  children: [
                    if (log.weightKg != null) ...[
                      const Icon(Icons.monitor_weight_outlined,
                          size: 20, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        '${log.weightKg!.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (log.lengthCm != null) ...[
                      const Icon(Icons.straighten,
                          size: 20, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        '${log.lengthCm!.toStringAsFixed(1)} cm',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),

                // Not
                if (log.notes != null && log.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    log.notes!,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 8),

                // Tarih + sil butonu
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 18, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(log.caughtAt),
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.muted),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(context, ref),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger),
                      icon: const Icon(Icons.delete_outline, size: 22),
                      label: const Text('Sil',
                          style: TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı Sil',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: const Text('Bu kayıt silinecek. Emin misiniz?',
            style: TextStyle(fontSize: 17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: const Text('Sil',
                style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(fishLogRepositoryProvider).deleteLog(log.id);
      onDeleted();
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1C33),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
