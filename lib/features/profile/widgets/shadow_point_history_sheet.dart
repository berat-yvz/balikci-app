import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/utils/time_utils.dart';
import 'package:balikci_app/shared/providers/shadow_point_provider.dart';

/// Son gölge puan olaylarını gösteren alt sayfa.
class ShadowPointHistorySheet extends ConsumerWidget {
  final String userId;

  const ShadowPointHistorySheet({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentShadowEventsProvider(userId));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Gölge Puan Geçmişin 📍',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foam,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: async.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stack) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Liste yüklenemedi.',
                        style: TextStyle(color: AppColors.muted, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  data: (events) {
                    if (events.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        child: Text(
                          'Henüz gölge puan kazanmadın.\nMera paylaşmaya başla! 🗺️',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: events.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: AppColors.muted.withValues(alpha: 0.35),
                      ),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                AppColors.accent.withValues(alpha: 0.2),
                            child: const Text('📍'),
                          ),
                          title: Text(
                            event.displayText,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.foam,
                            ),
                          ),
                          subtitle: Text(
                            timeAgo(event.createdAt),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                          trailing: Text(
                            '+${event.points}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.dark,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Tamam',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
