import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/balikcim/daily_forecast/daily_forecast_screen.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_screen.dart';

/// Balıkçım — günlük özet tahmin ve balık bilgisi sekmeleri.
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
    _tabController = TabController(length: 2, vsync: this);
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
              icon: Icon(Icons.phishing, size: 26),
              text: 'Özet',
            ),
            Tab(
              height: 56,
              iconMargin: EdgeInsets.zero,
              icon: Icon(Icons.set_meal_outlined, size: 26),
              text: 'Balık Bilgisi',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DailyForecastScreen(),
          FishEncyclopediaScreen(),
        ],
      ),
    );
  }
}
