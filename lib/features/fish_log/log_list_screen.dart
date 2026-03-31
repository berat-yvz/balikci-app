import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/fish_log_model.dart';
import 'package:balikci_app/shared/providers/fish_log_provider.dart';
import 'package:balikci_app/shared/widgets/empty_state_widget.dart';
import 'package:balikci_app/shared/widgets/error_widget.dart';
import 'package:balikci_app/shared/widgets/exif_badge.dart';
import 'package:balikci_app/shared/widgets/loading_widget.dart';

class LogListScreen extends ConsumerStatefulWidget {
  const LogListScreen({super.key});

  @override
  ConsumerState<LogListScreen> createState() => _LogListScreenState();
}

class _LogListScreenState extends ConsumerState<LogListScreen> {
  final Map<String, bool?> _exifStatusByLogId = {};
  final Set<String> _pollingStarted = {};

  Future<void> _pollFishLogExif(String logId) async {
    const attempts = 10; // 10 x 3 sn = 30 sn
    const interval = Duration(seconds: 3);

    for (var i = 0; i < attempts; i++) {
      try {
        final response = await SupabaseService.client
            .from('fish_logs')
            .select('exif_verified')
            .eq('id', logId)
            .maybeSingle();

        final verified = response?['exif_verified'];
        if (verified == true) {
          if (!mounted) return;
          setState(() => _exifStatusByLogId[logId] = true);
          return;
        }
      } catch (_) {
        // Sürece devam edeceğiz.
      }

      if (i == attempts - 1) break;
      await Future.delayed(interval);
    }

    if (!mounted) return;
    setState(() => _exifStatusByLogId[logId] = false);
  }

  void _ensurePollingForLogs(List<FishLogModel> logs) {
    for (final log in logs) {
      if (log.photoUrl == null) continue;
      if (_pollingStarted.contains(log.id)) continue;
      _pollingStarted.add(log.id);

      // Pending UI
      setState(() => _exifStatusByLogId[log.id] = null);
      unawaited(_pollFishLogExif(log.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncLogs = ref.watch(myFishLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Balık Günlüğüm'),
        actions: [
          IconButton(
            tooltip: 'İstatistikler',
            icon: const Icon(Icons.insert_chart_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/logs/stats');
            },
          ),
        ],
      ),
      body: asyncLogs.when(
        data: (logs) {
          // Fotoğraflı yeni kayıtlar için EXIF doğrulamasını arka planda takip et.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _ensurePollingForLogs(logs);
          });

          if (logs.isEmpty) {
            return EmptyStateWidget(
              title: 'Henüz av kaydı yok',
              subtitle: 'İlk balığını kaydetmek için aşağıdaki butona dokun.',
              icon: Icons.menu_book_outlined,
              buttonLabel: 'İlk kaydı oluştur',
              onButtonPressed: () {
                Navigator.of(context).pushNamed('/logs/add');
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _pollingStarted.clear();
              _exifStatusByLogId.clear();
              ref.invalidate(myFishLogsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final log = logs[index];
                final exifStatus =
                    _exifStatusByLogId[log.id] ?? log.exifVerified;
                return _FishLogCard(
                  log: log,
                  exifStatus: log.photoUrl == null ? null : exifStatus,
                );
              },
            ),
          );
        },
        loading: () => const LoadingWidget(message: 'Kayıtlar yükleniyor...'),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(myFishLogsProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed('/logs/add');
        },
        icon: const Icon(Icons.add),
        label: const Text('Yeni Kayıt'),
      ),
    );
  }
}

class _FishLogCard extends StatelessWidget {
  final FishLogModel log;
  final bool? exifStatus;

  const _FishLogCard({required this.log, required this.exifStatus});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${log.createdAt.day.toString().padLeft(2, '0')}.${log.createdAt.month.toString().padLeft(2, '0')}.${log.createdAt.year}';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 64,
              decoration: BoxDecoration(
                color: log.released ? Colors.green : AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(log.species, style: AppTextStyles.h3),
                      const SizedBox(width: 8),
                      if (log.weight != null)
                        Text(
                          '${log.weight!.toStringAsFixed(1)} kg',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  if (log.spotId != null) ...[
                    const SizedBox(height: 4),
                    Text('Mera: ${log.spotId}', style: AppTextStyles.caption),
                  ],
                  if (exifStatus != null) ...[
                    const SizedBox(height: 10),
                    ExifBadge(exifVerified: exifStatus),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        log.isPrivate ? Icons.lock_outline : Icons.public,
                        size: 16,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        log.isPrivate ? 'Gizli kayıt' : 'Herkese açık',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      const Spacer(),
                      if (log.released)
                        Row(
                          children: [
                            const Icon(
                              Icons.recycling,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Balığı saldın',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
