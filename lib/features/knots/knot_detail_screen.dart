import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/knot_model.dart';
import 'package:balikci_app/shared/widgets/loading_widget.dart';
import 'package:balikci_app/shared/widgets/error_widget.dart';

class KnotDetailScreen extends ConsumerWidget {
  final String knotId;

  const KnotDetailScreen({super.key, required this.knotId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Düğüm Detayı'),
      ),
      body: FutureBuilder<KnotModel?>(
        future: _fetchKnot(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget(message: 'Düğüm yükleniyor...');
          }
          if (snapshot.hasError) {
            return AppErrorWidget(
              message: snapshot.error.toString(),
              onRetry: () {},
            );
          }

          final knot = snapshot.data;
          if (knot == null) {
            return const Center(child: Text('Düğüm bulunamadı.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  knot.name,
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                      label: Text(knot.type),
                      backgroundColor: AppColors.primaryLight,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _difficultyStars(knot.difficulty),
                    )
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  knot.description,
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                ),
                if (knot.imageUrl != null && knot.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      knot.imageUrl!,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Adımlar',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: knot.steps.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final step = knot.steps[idx];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              step,
                              style: AppTextStyles.body,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<KnotModel?> _fetchKnot() async {
    try {
      final response = await SupabaseService.client
          .from('knots')
          .select()
          .eq('id', knotId)
          .maybeSingle();
      if (response == null) return null;
      return KnotModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Düğüm alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Düğüm alınamadı: $e');
    }
  }

  List<Widget> _difficultyStars(int difficulty) {
    final d = difficulty.clamp(1, 5);
    final filled = List<Widget>.generate(
      d,
      (_) => const Icon(Icons.star, size: 18, color: Colors.amber),
    );
    final empty = List<Widget>.generate(
      5 - d,
      (_) => const Icon(Icons.star_border, size: 18, color: Colors.amber),
    );
    return [...filled, ...empty];
  }
}

