import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/knot_model.dart';

class KnotDetailScreen extends StatefulWidget {
  // cleaned: extra ile KnotModel alan, öğrenildi toggle'ı olan detay ekranı yazıldı
  final KnotModel knot;
  const KnotDetailScreen({super.key, required this.knot});

  @override
  State<KnotDetailScreen> createState() => _KnotDetailScreenState();
}

class _KnotDetailScreenState extends State<KnotDetailScreen> {
  bool _learned = false;

  @override
  void initState() {
    super.initState();
    _loadLearned();
  }

  Future<void> _loadLearned() async {
    final prefs = await SharedPreferences.getInstance();
    final learned = prefs.getStringList('learned_knots') ?? <String>[];
    if (!mounted) return;
    setState(() => _learned = learned.contains(widget.knot.id));
  }

  Future<void> _toggleLearned() async {
    final prefs = await SharedPreferences.getInstance();
    final learned = (prefs.getStringList('learned_knots') ?? <String>[])
        .toSet();
    if (_learned) {
      learned.remove(widget.knot.id);
    } else {
      learned.add(widget.knot.id);
    }
    await prefs.setStringList('learned_knots', learned.toList());
    if (!mounted) return;
    setState(() => _learned = !_learned);
  }

  @override
  Widget build(BuildContext context) {
    final knot = widget.knot;
    final diff = knot.difficulty.clamp(1, 5);
    return Scaffold(
      appBar: AppBar(title: Text(knot.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(knot.category),
              ),
              const SizedBox(width: 12),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < diff ? Icons.star : Icons.star_border,
                    color: AppColors.primary,
                    size: 18,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: knot.useCases
                .map(
                  (use) => Chip(
                    label: Text(use),
                    backgroundColor: AppColors.surface,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Adımlar',
            style: AppTextStyles.h3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(knot.steps.length, (idx) {
            final step = knot.steps[idx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step,
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _toggleLearned,
            style: ElevatedButton.styleFrom(
              backgroundColor: _learned ? AppColors.success : AppColors.primary,
            ),
            child: Text(_learned ? 'Öğrendim ✓' : 'Öğrendim ✓'),
          ),
        ],
      ),
    );
  }
}
