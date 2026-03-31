import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/knot_model.dart';
import 'package:balikci_app/data/repositories/knot_repository.dart';
import 'package:balikci_app/shared/widgets/loading_widget.dart';
import 'package:balikci_app/shared/widgets/error_widget.dart';

class KnotsScreen extends ConsumerStatefulWidget {
  const KnotsScreen({super.key});

  @override
  ConsumerState<KnotsScreen> createState() => _KnotsScreenState();
}

class _KnotsScreenState extends ConsumerState<KnotsScreen> {
  String? _typeFilter;

  static const _chips = <Map<String, String?>>[
    {'label': 'Tümü', 'type': null},
    {'label': 'Olta', 'type': 'olta'},
    {'label': 'Ağ', 'type': 'ag'},
    {'label': 'Tekne', 'type': 'tekne'},
    {'label': 'Temel', 'type': 'temel'},
  ];

  @override
  Widget build(BuildContext context) {
    final repo = KnotRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Düğüm Rehberi')),
      body: FutureBuilder<List<KnotModel>>(
        future: repo.getKnots(typeFilter: _typeFilter),
        builder: (context, snapshot) {
          final knots = snapshot.data ?? const <KnotModel>[];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget(message: 'Düğümler yükleniyor...');
          }
          if (snapshot.hasError) {
            return AppErrorWidget(
              message: snapshot.error.toString(),
              onRetry: () => setState(() {}),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _chips.map((c) {
                    final type = c['type'];
                    final selected =
                        (type == null && _typeFilter == null) ||
                        (type != null && _typeFilter == type);
                    return FilterChip(
                      label: Text(c['label']!),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _typeFilter = type);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: knots.isEmpty
                    ? const Center(child: Text('Bu filtreye uygun düğüm yok.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: knots.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final knot = knots[index];
                          return _KnotCard(
                            knot: knot,
                            onTap: () {
                              context.push('/knots/${knot.id}');
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
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
    final stars = List<Widget>.generate(
      knot.difficulty.clamp(1, 5),
      (_) => const Icon(Icons.star, size: 16, color: Colors.amber),
    );
    final emptyStars = List<Widget>.generate(
      5 - knot.difficulty.clamp(1, 5),
      (_) => const Icon(Icons.star_border, size: 16, color: Colors.amber),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
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
            Text(knot.name, style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(knot.type),
                  backgroundColor: AppColors.primaryLight,
                ),
                Row(children: [...stars, ...emptyStars]),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              knot.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
