import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:balikci_app/app/app_routes.dart';

class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 4; // harita varsayılan

  int _indexFromPath(String path) {
    if (path.startsWith(AppRoutes.fishLog)) return 0;
    if (path.startsWith(AppRoutes.rank)) return 1;
    if (path.startsWith(AppRoutes.weather)) return 2;
    if (path.startsWith(AppRoutes.profile)) return 3;
    return 4; // harita (home)
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go(AppRoutes.fishLog);
      case 1:
        context.go(AppRoutes.rank);
      case 2:
        context.go(AppRoutes.weather);
      case 3:
        context.go(AppRoutes.profile);
      case 4:
        context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rota değişimlerinde (back button vs.) index'i senkronize tut
    final path = GoRouterState.of(context).uri.path;
    _currentIndex = _indexFromPath(path);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        body: widget.child,
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF0D1B2E),
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book,
                label: 'Günlük',
                index: 0,
                currentIndex: _currentIndex,
                onTap: () => _onTabTapped(0),
              ),
              _NavItem(
                icon: Icons.emoji_events_outlined,
                activeIcon: Icons.emoji_events,
                label: 'Sıralama',
                index: 1,
                currentIndex: _currentIndex,
                onTap: () => _onTabTapped(1),
              ),
              // Ortada boşluk (FAB için)
              const SizedBox(width: 64),
              _NavItem(
                icon: Icons.waves_outlined,
                activeIcon: Icons.waves,
                label: 'Hava',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onTabTapped(4),
        backgroundColor: const Color(0xFF0F6E56),
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.map, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? const Color(0xFF0F6E56) : Colors.white54,
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? const Color(0xFF0F6E56) : Colors.white54,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
