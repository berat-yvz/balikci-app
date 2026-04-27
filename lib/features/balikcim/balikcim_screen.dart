import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/balikcim/daily_forecast/daily_forecast_screen.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_screen.dart';
import 'package:balikci_app/features/knots/knots_screen.dart';

/// Balıkçım — rehber sekmeleri (balık bilgisi, tahmin, düğümler & takım, ipuçları).
class BalikcimScreen extends ConsumerStatefulWidget {
  const BalikcimScreen({super.key});

  @override
  ConsumerState<BalikcimScreen> createState() => _BalikcimScreenState();
}

class _BalikcimScreenState extends ConsumerState<BalikcimScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: Text(
          'Balıkçım 🎣',
          style: AppTextStyles.h3.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          ColoredBox(
            color: AppColors.navy,
            child: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: SizedBox(
                height: 56,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(
                      color: AppColors.accent,
                      width: 3,
                    ),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: AppTextStyles.caption.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: AppTextStyles.caption.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: const [
                    Tab(
                      height: 56,
                      iconMargin: EdgeInsets.zero,
                      icon: Icon(Icons.set_meal_outlined, size: 28),
                      text: 'Balık Bilgisi',
                    ),
                    Tab(
                      height: 56,
                      iconMargin: EdgeInsets.zero,
                      icon: Icon(Icons.wb_sunny_outlined, size: 28),
                      text: 'Tahmin',
                    ),
                    Tab(
                      height: 56,
                      iconMargin: EdgeInsets.zero,
                      icon: Icon(Icons.link_outlined, size: 28),
                      text: 'Düğümler',
                    ),
                    Tab(
                      height: 56,
                      iconMargin: EdgeInsets.zero,
                      icon: Icon(Icons.lightbulb_outline, size: 28),
                      text: 'İpuçları',
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const FishEncyclopediaScreen(),
                const DailyForecastScreen(),
                const KnotsScreen(),
                const _PlaceholderTab(
                  icon: Icons.lightbulb_outline,
                  title: 'İpuçları',
                  subtitle:
                      'Av mevzuatı, teknik terimler ve mevsim kuralları\nyakında burada!',
                  color: AppColors.accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: color),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontSize: 17,
                color: Colors.white70,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
