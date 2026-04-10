import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/knot_model.dart';
import 'package:balikci_app/data/models/tackle_model.dart';

class KnotsScreen extends StatefulWidget {
  const KnotsScreen({super.key});

  @override
  State<KnotsScreen> createState() => _KnotsScreenState();
}

class _KnotsScreenState extends State<KnotsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String _knotCategory = 'tumu';
  List<KnotModel> _allKnots = const [];
  List<TackleModel> _allTackle = const [];
  bool _loading = true;
  String? _error;

  static const _chips = <(String label, String value)>[
    ('Tümü', 'tumu'),
    ('Kanca', 'kanca'),
    ('Birleştirme', 'birlestirme'),
    ('Lider', 'lider'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final knotRaw =
          await rootBundle.loadString('assets/knots/knots_data.json');
      final tackleRaw =
          await rootBundle.loadString('assets/tackle/tackle_data.json');

      final knots = (jsonDecode(knotRaw) as List)
          .whereType<Map<String, dynamic>>()
          .map(KnotModel.fromJson)
          .toList(growable: false);

      final tackle = (jsonDecode(tackleRaw) as List)
          .whereType<Map<String, dynamic>>()
          .map(TackleModel.fromJson)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _allKnots = knots;
        _allTackle = tackle;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<KnotModel> get _filteredKnots {
    if (_knotCategory == 'tumu') return _allKnots;
    return _allKnots.where((k) => k.category == _knotCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Düğüm & Takım Rehberi'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.connecting_airports), text: 'Düğümler'),
            Tab(icon: Icon(Icons.phishing), text: 'Takımlar'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                'Veriler yüklenemedi: $_error',
                style: AppTextStyles.body.copyWith(color: Colors.white70),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildKnotsTab(), _buildTackleTab()],
            ),
    );
  }

  Widget _buildKnotsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _chips.map((chip) {
              final selected = _knotCategory == chip.$2;
              return FilterChip(
                label: Text(chip.$1),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _knotCategory = chip.$2),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _filteredKnots.isEmpty
              ? const Center(
                  child: Text('Bu filtrede düğüm bulunamadı.'),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                  itemCount: _filteredKnots.length,
                  itemBuilder: (context, index) {
                    final knot = _filteredKnots[index];
                    return _KnotCard(
                      knot: knot,
                      onTap: () =>
                          context.push(AppRoutes.knotsDetail, extra: knot),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTackleTab() {
    if (_allTackle.isEmpty) {
      return const Center(
        child: Text('Takım önerileri bulunamadı.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _allTackle.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _TackleCard(tackle: _allTackle[index]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Knot card widget
// ---------------------------------------------------------------------------

class _KnotCard extends StatelessWidget {
  final KnotModel knot;
  final VoidCallback onTap;

  const _KnotCard({required this.knot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final difficulty = knot.difficulty.clamp(1, 5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              knot.title,
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                knot.category,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (i) {
                return Icon(
                  i < difficulty ? Icons.star : Icons.star_border,
                  size: 16,
                  color: AppColors.primary,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tackle card widget
// ---------------------------------------------------------------------------

class _TackleCard extends StatelessWidget {
  final TackleModel tackle;

  const _TackleCard({required this.tackle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            tackle.title,
            style: AppTextStyles.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _InfoChip(
                icon: Icons.calendar_today_outlined,
                label: tackle.season,
              ),
              _InfoChip(
                icon: Icons.tune_outlined,
                label: tackle.technique,
              ),
            ],
          ),
          children: tackle.items.map((item) => _TackleItemRow(item: item)).toList(),
        ),
      ),
    );
  }
}

class _TackleItemRow extends StatelessWidget {
  final TackleItem item;
  const _TackleItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.detail,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 13,
                      color: AppColors.accent.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.tip,
                        style: TextStyle(
                          color: AppColors.accent.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white54),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
