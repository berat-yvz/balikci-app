import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/balikcim/daily_forecast/daily_forecast_screen.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_screen.dart';

/// Balıkçım — rehber sekmeleri (balık bilgisi, tahmin, ipuçları).
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
    _tabController = TabController(length: 3, vsync: this);
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
          'Balıkçım',
          style: AppTextStyles.h3.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.foam,
          ),
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.foam,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          dividerColor: AppColors.surface,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.primary, width: 3),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: AppColors.foam,
          unselectedLabelColor: AppColors.muted,
          labelStyle: AppTextStyles.caption.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: AppTextStyles.caption.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(
              height: 56,
              iconMargin: EdgeInsets.zero,
              icon: Icon(Icons.set_meal_outlined, size: 26),
              text: 'Balık Bilgisi',
            ),
            Tab(
              height: 56,
              iconMargin: EdgeInsets.zero,
              icon: Icon(Icons.phishing, size: 26),
              text: 'Balıkçım',
            ),
            Tab(
              height: 56,
              iconMargin: EdgeInsets.zero,
              icon: Icon(Icons.lightbulb_outline, size: 26),
              text: 'İpuçları',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          FishEncyclopediaScreen(),
          DailyForecastScreen(),
          _PlaceholderTab(
            icon: Icons.lightbulb_outline,
            title: 'İpuçları & Mevzuat',
            subtitle:
                'Av mevzuatı, tür bazlı minimum boy\nkuralları ve mevsim yasakları çok yakında!',
            color: AppColors.accent,
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
    return ColoredBox(
      color: AppColors.navy,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 72, color: color),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.foam,
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
                  fontSize: 16,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
