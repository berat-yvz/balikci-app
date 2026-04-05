import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';
import 'package:balikci_app/shared/widgets/rank_badge.dart';
import 'package:balikci_app/shared/widgets/loading_widget.dart';
import 'package:balikci_app/shared/widgets/error_widget.dart';

class RankScreen extends ConsumerWidget {
  const RankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final asyncUsers = ref.watch(leaderboardProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sıralama'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Genel'),
              Tab(text: 'Bölge'),
              Tab(text: 'Haftalık'),
            ],
          ),
        ),
        body: asyncUsers.when(
          data: (users) {
            return TabBarView(
              children: [
                _LeaderboardTab(users: users, currentUserId: currentUserId),
                _LeaderboardTab(users: users, currentUserId: currentUserId),
                _LeaderboardTab(users: users, currentUserId: currentUserId),
              ],
            );
          },
          loading: () =>
              const LoadingWidget(message: 'Sıralamalar yükleniyor...'),
          error: (e, _) => AppErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(leaderboardProvider),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTab extends ConsumerWidget {
  final List<UserModel> users;
  final String? currentUserId;

  const _LeaderboardTab({required this.users, required this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaderboardProvider);
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, idx) {
          final u = users[idx];
          final rank = idx + 1;
          final isCurrent = currentUserId != null && currentUserId == u.id;
          return _LeaderboardRow(user: u, rank: rank, highlight: isCurrent);
        },
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final UserModel user;
  final int rank;
  final bool highlight;

  const _LeaderboardRow({
    required this.user,
    required this.rank,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.10)
            : const Color(0xFF12233A),
        borderRadius: BorderRadius.circular(14),
        border: highlight
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.35))
            : null,
      ),
      child: Row(
        children: [
          RankBadge(rank: user.rank, size: RankBadgeSize.small),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rank. ${user.username}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Toplam puan: ${user.totalScore}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text('${user.totalScore}', style: AppTextStyles.h3),
        ],
      ),
    );
  }
}
