import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/notification_model.dart';
import 'package:balikci_app/shared/providers/notification_provider.dart';

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotifications = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final repo = ref.read(notificationRepositoryProvider);
              try {
                await repo.markAllAsRead();
                ref.invalidate(myNotificationsProvider);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tümünü okuma işlemi başarısız: $e'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            icon: const Icon(Icons.done_all_outlined),
            label: const Text('Tümünü Oku'),
          ),
        ],
      ),
      body: asyncNotifications.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const _NotificationEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myNotificationsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _NotificationTile(
                  notification: n,
                  onTap: () async {
                    final repo = ref.read(notificationRepositoryProvider);
                    final router = GoRouter.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      if (!n.read) {
                        await repo.markAsRead(n.id);
                        ref.invalidate(myNotificationsProvider);
                      }

                      final spotId = _extractSpotId(n.data);
                      if (spotId != null) {
                        router.push('/checkin/$spotId');
                      }
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Bildirim açılırken hata oluştu: $e'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Bildirimler alınamadı: $e',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ),
    );
  }

  String? _extractSpotId(Map<String, dynamic> data) {
    final spotId1 = data['spotId'];
    if (spotId1 is String && spotId1.isNotEmpty) return spotId1;
    final spotId2 = data['spot_id'];
    if (spotId2 is String && spotId2.isNotEmpty) return spotId2;
    return null;
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  String _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('checkin')) return '🎣';
    if (t.contains('vote')) return '👍';
    if (t.contains('rank')) return '🏆';
    if (t.contains('follow')) return '👤';
    return '🔔';
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    final icon = _iconForType(notification.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF132236),
            borderRadius: BorderRadius.circular(14),
            border: unread
                ? Border.all(color: AppColors.accent.withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: unread
                    ? AppColors.accent.withValues(alpha: 0.22)
                    : AppColors.primaryLight,
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 15,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(notification.createdAt),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(painter: _BellPainter()),
            ),
            const SizedBox(height: 16),
            Text('Henüz bildirim yok', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Yeni gelişmeleri kaçırmamak için takip etmeye devam et.',
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BellPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    // çan gövdesi
    final rect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - 10),
      width: size.width * 0.55,
      height: size.height * 0.42,
    );
    canvas.drawArc(rect, math.pi, math.pi, false, paint);

    // alt yay
    canvas.drawLine(
      Offset(center.dx - rect.width / 2, rect.bottom),
      Offset(center.dx + rect.width / 2, rect.bottom),
      paint,
    );

    // zil sapı
    canvas.drawLine(
      Offset(center.dx, rect.top - 10),
      Offset(center.dx, rect.top + 6),
      paint,
    );

    // çan içi küçük çizgi
    canvas.drawCircle(
      Offset(center.dx, rect.bottom + 18),
      6,
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
