import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/app_constants.dart';
import 'package:balikci_app/core/services/map_cache_service.dart';
import 'package:balikci_app/features/map/providers/map_cache_provider.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _signingOut = false;
  bool _clearingCache = false;

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

  Future<void> _confirmAndClearCache() async {
    if (_clearingCache) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Harita önbelleği silinsin mi?'),
          content: const Text(
            'İnternetsiz bölgelerde harita yeniden yüklenene kadar görünmeyebilir.',
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Temizle'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) return;

    setState(() => _clearingCache = true);
    try {
      await MapCacheService.clearCache();
      if (!mounted) return;
      ref.invalidate(mapCacheSizeProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Harita önbelleği temizlendi'),
          backgroundColor: AppColors.primary,
        ),
      );
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cacheAsync = ref.watch(mapCacheSizeProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_outlined, color: AppColors.teal),
            title: const Text('Bildirimler',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Bildirim tercihlerini düzenle'),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => context.push(AppRoutes.notificationsSettings),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined,
                color: Colors.white70),
            title: const Text('Gizlilik',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Yakında'),
            enabled: false,
          ),
          const SizedBox(height: 32),

          // ── Harita Önbelleği ────────────────────────────────────────────
          const Divider(),
          const SizedBox(height: 8),
          Text(
            '🗺️ Harita Önbelleği',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          cacheAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Hesaplanıyor...',
                style: AppTextStyles.caption.copyWith(color: AppColors.muted),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (cacheSizeMb) => Card(
              color: const Color(0xFF1A2E42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 28,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Harita Önbelleği',
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.foam,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${cacheSizeMb.toStringAsFixed(1)} MB'
                            ' / ${AppConstants.fmtcMaxCacheMb} MB',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (cacheSizeMb /
                                    AppConstants.fmtcMaxCacheMb)
                                .clamp(0.0, 1.0),
                            backgroundColor: AppColors.surface,
                            color: AppColors.primary,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gittiğin yerlerin haritası cihazına kaydedilir. '
            'İnternetsiz bölgelerde haritayı görmeni sağlar.',
            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.5),
                ),
              ),
              onPressed: _clearingCache ? null : _confirmAndClearCache,
              icon: _clearingCache
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(Icons.delete_outline, size: 24),
              label: const Text(
                'Önbelleği Temizle',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Hesap ───────────────────────────────────────────────────────
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
