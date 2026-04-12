import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/data/repositories/spot_repository.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/favorite_provider.dart';

/// Profil istatistiğinden: kullanıcının eklediği meralar.
/// Kendi listende seçim → düzenleme; başka profilde → haritada aç.
class UserSpotsListScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserSpotsListScreen({super.key, required this.userId});

  @override
  ConsumerState<UserSpotsListScreen> createState() =>
      _UserSpotsListScreenState();
}

class _UserSpotsListScreenState extends ConsumerState<UserSpotsListScreen> {
  final _repo = SpotRepository();
  late Future<List<SpotModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getSpotsByUserId(widget.userId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repo.getSpotsByUserId(widget.userId);
    });
    await _future;
  }

  void _onSpotTap(SpotModel spot) {
    final me = ref.read(currentUserProvider)?.id;
    if (me != null && me == widget.userId) {
      context.push(AppRoutes.mapEditSpot, extra: spot).then((_) {
        if (mounted) _reload();
      });
    } else {
      context.go(AppRoutes.home, extra: spot.id);
    }
  }

  Future<void> _openEdit(SpotModel spot) async {
    await context.push<bool>(AppRoutes.mapEditSpot, extra: spot);
    if (mounted) await _reload();
  }

  Future<void> _confirmDelete(SpotModel spot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Merayı sil'),
        content: Text('"${spot.name}" kalıcı olarak silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteSpot(spot.id);
      ref.invalidate(favoriteSpotsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mera silindi'),
          backgroundColor: AppColors.success,
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mera silinemedi: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Eklenen meralar')),
      body: FutureBuilder<List<SpotModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Liste yüklenemedi: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            );
          }
          final spots = snapshot.data ?? [];
          final me = ref.watch(currentUserProvider)?.id;
          final isSelf = me != null && me == widget.userId;

          if (spots.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Henüz mera eklenmemiş.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.muted,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: spots.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = spots[i];
                final type = s.type;
                return ListTile(
                  title: Text(
                    s.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    type != null && type.isNotEmpty ? type : s.privacyLevel,
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  trailing: isSelf
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              tooltip: 'Düzenle',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              onPressed: () => _openEdit(s),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.danger.withValues(alpha: 0.9),
                              ),
                              tooltip: 'Sil',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              onPressed: () => _confirmDelete(s),
                            ),
                          ],
                        )
                      : const Icon(
                          Icons.chevron_right,
                          color: Colors.white38,
                        ),
                  onTap: () => _onSpotTap(s),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
