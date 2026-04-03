import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _signingOut = false;

  Future<void> _confirmAndSignOut() async {
    if (_signingOut) return;

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Çıkış Yap'),
          content: const Text('Hesabından çıkış yapmak istediğine emin misin?'),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Çıkış Yap'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) return;

    setState(() => _signingOut = true);
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (!mounted) return;
      context.go(AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Çıkış yapılamadı: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.notifications_outlined, color: Colors.white70),
            title: Text('Bildirimler'),
            subtitle: Text('Bildirim tercihlerini düzenle'),
          ),
          const Divider(height: 32),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: Colors.white70),
            title: Text('Gizlilik'),
            subtitle: Text('Hesap ve görünürlük ayarları'),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Hesap',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.4),
              ),
            ),
            child: ListTile(
              leading: Icon(Icons.logout, color: AppColors.danger),
              title: Text(
                'Çıkış Yap',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: _signingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.danger,
                      ),
                    )
                  : const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: _signingOut ? null : _confirmAndSignOut,
            ),
          ),
        ],
      ),
    );
  }
}
