import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';

/// "Nasıl Puan Kazanırsın?" bilgi alt sayfası — `showModalBottomSheet` ile açılır.
class HowToEarnPointsSheet extends StatelessWidget {
  const HowToEarnPointsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Nasıl Puan Kazanırsın? 🎣',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foam,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'Puan Kazanma Yolları',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const _PointRow('🗺️', 'Herkese açık mera eklemek', '+50'),
              const _PointRow('🗺️', 'Arkadaşlara özel mera eklemek', '+30'),
              const _PointRow('🗺️', 'Gizli mera eklemek', '+10'),
              const _PointRow('📍', 'Meraya gidip bildirim göndermek', '+15'),
              const _PointRow('📸', 'Av fotoğrafı paylaşmak', '+20'),
              const _PointRow('❤️', 'Her 10 beğeni aldığında', '+5'),
              const _PointRow('✅', 'Doğru balık bildirimi oyu almak', '+10'),
              const _PointRow(
                '⛔',
                'Yanlış rapor cezası',
                '-20',
                isNegative: true,
              ),
              Divider(height: 32, thickness: 1, color: AppColors.muted.withValues(alpha: 0.35)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'Rütbeler Ne Zaman Açılır?',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const _RankRow('🪝', 'Yeni Balıkçı', '0 – 499 puan', ''),
              const _RankRow(
                '🎣',
                'Olta Kurdusu',
                '500 puan',
                'Arkadaş meraları açılır',
              ),
              const _RankRow(
                '⚓',
                'Usta Balıkçı',
                '2.000 puan',
                'Gizli meralar açılır',
              ),
              const _RankRow(
                '🌊',
                'Deniz Reisi',
                '5.000 puan',
                'En seçkin balıkçı unvanı',
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.foam,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Anladım 👍',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
            ],
          ),
        );
      },
    );
  }
}

class _PointRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String points;
  final bool isNegative;

  const _PointRow(
    this.emoji,
    this.label,
    this.points, {
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.foam,
                ),
              ),
            ),
            Text(
              points,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isNegative ? AppColors.danger : AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final String emoji;
  final String rankName;
  final String pointsLabel;
  final String perk;

  const _RankRow(
    this.emoji,
    this.rankName,
    this.pointsLabel,
    this.perk,
  );

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minLeadingWidth: 40,
      leading: Text(
        emoji,
        style: const TextStyle(fontSize: 28),
      ),
      title: Text(
        rankName,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.foam,
        ),
      ),
      subtitle: perk.isEmpty
          ? null
          : Text(
              perk,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
      trailing: Text(
        pointsLabel,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.muted,
        ),
      ),
    );
  }
}
