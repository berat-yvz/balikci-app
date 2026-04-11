import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/shared/providers/connectivity_provider.dart';

/// Ana shell — 4 düz sekme.
/// Sekme sırası: Hava(0) | Harita(1) | Günlük(2) | Profil(3)
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 1; // harita varsayılan

  // 0=Hava, 1=Harita, 2=Günlük, 3=Profil
  int _indexFromPath(String path) {
    if (path.startsWith(AppRoutes.weather)) return 0;
    if (path.startsWith(AppRoutes.fishLog)) return 2;
    if (path.startsWith(AppRoutes.profile)) return 3;
    return 1; // harita (home)
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go(AppRoutes.weather);
      case 1:
        context.go(AppRoutes.home);
      case 2:
        context.go(AppRoutes.fishLog);
      case 3:
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
        if (!didPop) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
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
          elevation: 8,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 64,
            child: SafeArea(
              top: false,
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
                  ),
                  _MapNavItem(
                    isActive: _currentIndex == 1,
                    onTap: () => _onTabTapped(1),
                  ),
                  _NavItem(
                    icon: Icons.menu_book_outlined,
                    activeIcon: Icons.menu_book,
                    label: 'Günlük',
                    index: 2,
                    currentIndex: _currentIndex,
                    onTap: () => _onTabTapped(2),
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profil',
                    index: 3,
                    currentIndex: _currentIndex,
                    onTap: () => _onTabTapped(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Merkez Harita butonu — diğer nav öğeleriyle aynı yükseklikte,
/// hafifçe daha belirgin (büyük ikon + renk vurgu).
class _MapNavItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _MapNavItem({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 34,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isActive ? Icons.map : Icons.map_outlined,
                color: isActive ? AppColors.primary : Colors.white54,
                size: 28,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Harita',
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppColors.primary : Colors.white54,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.normal,
              ),
            ),
          ],
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

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : Colors.white54,
              size: 26,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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
