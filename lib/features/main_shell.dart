import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _currentIndexFromPath(String path) {
    if (path.startsWith(AppRoutes.fishLog)) return 1;
    if (path.startsWith(AppRoutes.rank)) return 2;
    if (path.startsWith(AppRoutes.weather)) return 3;
    if (path.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final currentIndex = _currentIndexFromPath(path);
    const tabRoutes = <String>[
      AppRoutes.home,
      AppRoutes.fishLog,
      AppRoutes.rank,
      AppRoutes.weather,
      AppRoutes.profile,
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.navy,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: const Color(0xFF9FB2C9),
        currentIndex: currentIndex,
        onTap: (index) => context.go(tabRoutes[index]),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Harita',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Günlük',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Sıralama',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.water_outlined),
            label: 'Hava',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
