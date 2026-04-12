import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_screen.dart';
import 'package:balikci_app/features/knots/knots_screen.dart';

// TODO(Balıkçım Faz 1): KnotsScreen, düğüm ve takım Balıkçım’da iki ayrı sekmede
// [KnotsScreenLayout.knotsOnly] / [tackleOnly] ile gömülü; her örnek kendi state’inde
// veriyi yüklüyor. İleride tek yükleme için paylaşımlı provider veya üst seviye
// [KnotsScreen] + [IndexedStack] ile birleştirilebilir.

/// Balıkçım — rehber sekmeleri (balık bilgisi, tahmin, düğümler, takım, ipuçları).
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
    _tabController = TabController(length: 5, vsync: this);
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
        title: const Text('Balıkçım'),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: AppTextStyles.caption.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(
                      height: 56,
                      iconMargin: EdgeInsets.zero,
                      icon: Icon(Icons.set_meal, size: 28),
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
                      icon: Icon(Icons.link, size: 28),
                      text: 'Düğümler',
                    ),
                    Tab(
                      height: 56,
                      iconMargin: EdgeInsets.zero,
                      icon: Icon(Icons.kitchen_outlined, size: 28),
                      text: 'Takım & Yem',
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
                const _PlaceholderTab(
                  icon: Icons.wb_sunny,
                  title: 'Günlük Tahmin',
                  subtitle:
                      'Bugün balık çıkar mı?\nHava ve gelgit analizi yakında!',
                  color: AppColors.accent,
                ),
                const KnotsScreen(layout: KnotsScreenLayout.knotsOnly),
                const KnotsScreen(layout: KnotsScreenLayout.tackleOnly),
                const _PlaceholderTab(
                  icon: Icons.lightbulb,
                  title: 'İpucu & Sözlük',
                  subtitle:
                      'Av mevzuatı, teknik terimler\nve mevsim kuralları yakında!',
                  color: AppColors.secondary,
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
            Icon(icon, size: 72, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontSize: 15,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
