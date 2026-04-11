import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/notification_service.dart';

/// Bildirim ayarları — FCM izin durumu + token senkron.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  AuthorizationStatus? _status;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final s =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (mounted) setState(() => _status = s.authorizationStatus);
    } catch (_) {}
  }

  Future<void> _requestPermission() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (!mounted) return;
      setState(() => _status = settings.authorizationStatus);

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await NotificationService.syncFcmToken();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirimler etkinleştirildi ✓'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Bildirim Ayarları')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Durum kartı
          _StatusCard(status: _status),
          const SizedBox(height: 20),

          // İzin butonu / bilgi
          if (_status == null)
            const Center(child: CircularProgressIndicator())
          else if (_status == AuthorizationStatus.authorized ||
              _status == AuthorizationStatus.provisional) ...[
            _InfoRow(
              icon: Icons.check_circle_outline,
              iconColor: AppColors.success,
              title: 'Bildirimler açık',
              subtitle:
                  'Mera güncellemeleri, oy bildirimleri ve puan değişikliklerini anlık alırsın.',
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.notifications_outlined,
              iconColor: AppColors.teal,
              title: 'Hangi bildirimleri alırsın?',
              subtitle:
                  '• Merana yeni bildirim gelince\n• Birisi bildirini doğru bulunca\n• Rütben yükselince\n• Birisi seni takip edince',
            ),
          ] else ...[
            _InfoRow(
              icon: Icons.notifications_off_outlined,
              iconColor: AppColors.warning,
              title: 'Bildirimler kapalı',
              subtitle:
                  'Meralardaki güncellemeleri kaçırabilirsin. Bildirimleri açmak için aşağıdaki butona bas.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _requesting ? null : _requestPermission,
                icon: _requesting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.notifications_active_outlined),
                label: const Text('Bildirimlere İzin Ver'),
              ),
            ),
            if (_status == AuthorizationStatus.denied) ...[
              const SizedBox(height: 12),
              Text(
                'İzin daha önce reddedildiyse sistem ayarlarından açman gerekebilir.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.muted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final AuthorizationStatus? status;

  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (status) {
      AuthorizationStatus.authorized => (
          Icons.notifications_active,
          'Bildirimler Açık',
          AppColors.success,
        ),
      AuthorizationStatus.provisional => (
          Icons.notifications_paused,
          'Sınırlı Bildirim',
          AppColors.warning,
        ),
      AuthorizationStatus.denied => (
          Icons.notifications_off,
          'Bildirimler Kapalı',
          AppColors.danger,
        ),
      _ => (Icons.notifications_none, 'Durum Bilinmiyor', AppColors.muted),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bildirim izni durumu',
                style: AppTextStyles.caption.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.muted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
