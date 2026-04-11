import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/shared/providers/connectivity_provider.dart';

/// Ana shell — 5 sekme, harita ortada vurgulu.
/// Sıra: Hava(0) | Sıralama(1) | Harita(2) | Günlük(3) | Profil(4)
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 2; // harita varsayılan

  int _indexFromPath(String path) {
    if (path.startsWith(AppRoutes.weather)) return 0;
    if (path.startsWith(AppRoutes.rank)) return 1;
    if (path == AppRoutes.home) return 2;
    if (path.startsWith(AppRoutes.fishLog)) return 3;
    if (path.startsWith(AppRoutes.profile) ||
        path.startsWith(AppRoutes.settings) ||
        path.startsWith(AppRoutes.notifications)) {
      return 4;
    }
    return 2;
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go(AppRoutes.weather);
      case 1:
        context.go(AppRoutes.rank);
      case 2:
        context.go(AppRoutes.home);
      case 3:
        context.go(AppRoutes.fishLog);
      case 4:
        context.go(AppRoutes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    _currentIndex = _indexFromPath(path);

    final isOnline = ref.watch(isOnlineProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        } else {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            // Offline banner
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isOnline ? 0 : 40,
              color: AppColors.warning,
              child: isOnline
                  ? const SizedBox.shrink()
                  : SafeArea(
                      bottom: false,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Çevrimdışısın — bazı özellikler sınırlı',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            Expanded(child: widget.child),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          color: const Color(0xFF0D1B2E),
          elevation: 12,
          shadowColor: Colors.black54,
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          height: 78,
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavItem(
                        icon: Icons.cloud_outlined,
                        activeIcon: Icons.cloud,
                        label: 'Hava',
                        index: 0,
                        currentIndex: _currentIndex,
                        onTap: () => _onTabTapped(0),
                        compact: true,
                      ),
                      _NavItem(
                        icon: Icons.leaderboard_outlined,
                        activeIcon: Icons.leaderboard,
                        label: 'Sıra',
                        index: 1,
                        currentIndex: _currentIndex,
                        onTap: () => _onTabTapped(1),
                        compact: true,
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: _MapNavItem(
                    isActive: _currentIndex == 2,
                    onTap: () => _onTabTapped(2),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavItem(
                        icon: Icons.menu_book_outlined,
                        activeIcon: Icons.menu_book,
                        label: 'Günlük',
                        index: 3,
                        currentIndex: _currentIndex,
                        onTap: () => _onTabTapped(3),
                        compact: true,
                      ),
                      _NavItem(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: 'Profil',
                        index: 4,
                        currentIndex: _currentIndex,
                        onTap: () => _onTabTapped(4),
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Orta harita — yükseltilmiş daire, gölge, daha büyük ikon.
class _MapNavItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _MapNavItem({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 88,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? AppColors.primary
                      : const Color(0xFF1B3A52),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primaryLight.withValues(alpha: 0.5)
                        : Colors.white24,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: isActive ? 0.45 : 0.2,
                      ),
                      blurRadius: isActive ? 14 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.map_rounded,
                  color: isActive ? Colors.white : Colors.white70,
                  size: 30,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Harita',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isActive ? AppColors.primary : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;
  final bool compact;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    final iconSize = compact ? 22.0 : 26.0;
    final fontSize = compact ? 10.0 : 11.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: compact ? 56 : 64,
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : Colors.white54,
              size: iconSize,
            ),
            SizedBox(height: compact ? 2 : 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                color: isActive ? AppColors.primary : Colors.white54,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
