import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/knot_model.dart';

class KnotsScreen extends StatefulWidget {
  // cleaned: Supabase yerine local JSON tabanlı tam rehber ekranı eklendi
  const KnotsScreen({super.key});

  @override
  State<KnotsScreen> createState() => _KnotsScreenState();
}

class _KnotsScreenState extends State<KnotsScreen> {
  String _category = 'tumu';
  List<KnotModel> _allKnots = const [];
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
    _loadKnots();
  }

  Future<void> _loadKnots() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await rootBundle.loadString('assets/knots/knots_data.json');
      final decoded = jsonDecode(raw) as List<dynamic>;
      final knots = decoded
          .whereType<Map<String, dynamic>>()
          .map(KnotModel.fromJson)
          .toList(growable: false);
      if (!mounted) return;
      setState(() => _allKnots = knots);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<KnotModel> get _filtered {
    if (_category == 'tumu') return _allKnots;
    return _allKnots.where((k) => k.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Düğüm Rehberi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                'Düğümler yüklenemedi: $_error',
                style: AppTextStyles.body.copyWith(color: Colors.white70),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _chips.map((chip) {
                      final selected = _category == chip.$2;
                      return FilterChip(
                        label: Text(chip.$1),
                        selected: selected,
                        onSelected: (_) => setState(() => _category = chip.$2),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _filtered.isEmpty
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
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final knot = _filtered[index];
                            return _KnotCard(
                              knot: knot,
                              onTap: () =>
                                  context.push('/knots/detail', extra: knot),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

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
