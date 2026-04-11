import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/shared/providers/connectivity_provider.dart';

/// Ana shell — 4 sekme + merkez Check-in FAB.
/// Sekme sırası: Harita(0) | Hava(1) | [FAB] | Günlük(2) | Profil(3)
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0; // harita varsayılan

  // 0=Harita, 1=Hava, 2=Günlük, 3=Profil
  int _indexFromPath(String path) {
    if (path.startsWith(AppRoutes.weather)) return 1;
    if (path.startsWith(AppRoutes.fishLog)) return 2;
    if (path.startsWith(AppRoutes.profile)) return 3;
    return 0; // harita (home)
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.weather);
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
            // Offline banner — sarı, sayfanın üstünde
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
        // ADIM 2: Merkez Check-in FAB
        floatingActionButton: SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            onPressed: () => context.go(AppRoutes.home),
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            elevation: 6,
            shape: const CircleBorder(),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phishing, size: 28, color: Colors.white),
                Text(
                  'Check-in',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          color: const Color(0xFF0D1B2E),
          elevation: 8,
          notchMargin: 8,
          shape: const CircularNotchedRectangle(),
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 64,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Sol 2 sekme
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _NavItem(
                          icon: Icons.map_outlined,
                          activeIcon: Icons.map,
                          label: 'Harita',
                          index: 0,
                          currentIndex: _currentIndex,
                          onTap: () => _onTabTapped(0),
                        ),
                        _NavItem(
                          icon: Icons.cloud_outlined,
                          activeIcon: Icons.cloud,
                          label: 'Hava',
                          index: 1,
                          currentIndex: _currentIndex,
                          onTap: () => _onTabTapped(1),
                        ),
                      ],
                    ),
                  ),
                  // FAB için boşluk
                  const SizedBox(width: 80),
                  // Sağ 2 sekme
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
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
                ],
              ),
            ),
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
