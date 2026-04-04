import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';

class StepWelcome extends StatelessWidget {
  const StepWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.anchor,
                          size: 44,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Türkiye\'nin Balıkçı Topluluğu',
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.foam,
                          fontSize: 20,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Gerçek balıkçılardan anlık mera raporları.\nHava, akıntı, balık yoğunluğu — tek uygulamada.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.foam.withValues(alpha: 0.72),
                          fontSize: 13.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          children: [
                            _FeatureRow(
                              icon: Icons.location_on_rounded,
                              iconColor: AppColors.primary,
                              title: 'Anlık Mera Raporları',
                              description:
                                  'Yakınındaki meralarda şu an kaç kişi var, balık tutuluyor mu — canlı gör.',
                            ),
                            SizedBox(height: 20),
                            _FeatureRow(
                              icon: Icons.cloud_rounded,
                              iconColor: AppColors.secondary,
                              title: 'Balıkçı Hava Tahmini',
                              description:
                                  'Dalga, rüzgar, akıntı — sade balıkçı diliyle yorumlanmış hava bilgisi.',
                            ),
                            SizedBox(height: 20),
                            _FeatureRow(
                              icon: Icons.emoji_events_rounded,
                              iconColor: AppColors.accent,
                              title: 'Puan Kazan, Rütbe Al',
                              description:
                                  'Mera paylaş, Balık Var bildir, topluluktan puan kazan. Acemi\'den Deniz Reisi\'ne ilerle.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _FeatureRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.foam,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.foam.withValues(alpha: 0.62),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
