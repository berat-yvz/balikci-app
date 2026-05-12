import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_model.dart';
import 'package:balikci_app/shared/widgets/app_filter_chip.dart';

String _mevsimTurkce(String s) {
  switch (s) {
    case 'ilkbahar':
      return '🌱 İlkbahar';
    case 'yaz':
      return '☀️ Yaz';
    case 'sonbahar':
      return '🍂 Sonbahar';
    case 'kis':
      return '❄️ Kış';
    default:
      return s;
  }
}

const _turkishMonthNames = <String>[
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

String _ayAdiTr(int month) {
  if (month < 1 || month > 12) return '$month';
  return _turkishMonthNames[month - 1];
}

int? _monthIndexFromTurkishName(String name) {
  final i = _turkishMonthNames.indexOf(name);
  if (i < 0) return null;
  return i + 1;
}

String _zorlukEtiket(String d) {
  return switch (d) {
    'kolay' => 'Kolay',
    'orta' => 'Orta',
    'zor' => 'Zor',
    _ => d,
  };
}

Color _zorlukRenk(String d) {
  return switch (d) {
    'kolay' => AppColors.success,
    'zor' => AppColors.danger,
    _ => AppColors.warning,
  };
}

/// [Navigator.push] ile açılan balık detayı — bölüm sırası İstanbul Olta El Kitabı akışına göre.
class FishDetailScreen extends StatefulWidget {
  final FishEncyclopediaEntry fish;

  const FishDetailScreen({super.key, required this.fish});

  @override
  State<FishDetailScreen> createState() => _FishDetailScreenState();
}

class _FishDetailScreenState extends State<FishDetailScreen> {
  /// Seçili ay adı (Ocak…Aralık); null ise av durumu özeti gösterilmez.
  String? _selectedMonth;

  final GlobalKey _generalKey = GlobalKey();
  final GlobalKey _seasonKey = GlobalKey();
  final GlobalKey _baitKey = GlobalKey();
  final GlobalKey _avlanmaKey = GlobalKey();
  final GlobalKey _tackleKey = GlobalKey();
  final GlobalKey _tipsKey = GlobalKey();
  final GlobalKey _legalKey = GlobalKey();
  final GlobalKey _funFactKey = GlobalKey();

  /// Yalnızca chip tıklanınca güncellenir (scroll ile senkronize edilmez).
  String? _selectedNavLabel;

  void _scrollToSection(GlobalKey key, String label) {
    setState(() => _selectedNavLabel = label);
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onMonthChipTap(String monthName) {
    setState(() {
      if (_selectedMonth == monthName) {
        _selectedMonth = null;
      } else {
        _selectedMonth = monthName;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fish = widget.fish;
    final mevsimMetni = fish.seasons.map(_mevsimTurkce).join('  •  ');
    final aylarMetni = fish.bestMonths.isEmpty
        ? '—'
        : fish.bestMonths.map(_ayAdiTr).join(', ');
    final gear = fish.istanbulGear;
    final hasGear = gear != null && gear.hasDisplayableData;

    final selectedMonth = _selectedMonth;
    final selectedMonthIdx = selectedMonth != null
        ? _monthIndexFromTurkishName(selectedMonth)
        : null;
    final isSelectedMonthBest = selectedMonthIdx != null &&
        fish.bestMonths.contains(selectedMonthIdx);

    final navEntries = <({String label, GlobalKey key})>[
      (label: 'Genel', key: _generalKey),
      (label: 'Mevsim', key: _seasonKey),
      (label: 'Yemler', key: _baitKey),
      (label: 'Avlanma', key: _avlanmaKey),
      if (hasGear) (label: 'Takım', key: _tackleKey),
      (label: 'İpuçları', key: _tipsKey),
      if (fish.minLegalSizeCm != null)
        (label: 'Mevzuat', key: _legalKey),
      (label: 'Bilgi', key: _funFactKey),
    ];

    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: Text(
          '${fish.emoji} ${fish.name}',
          style: AppTextStyles.h3.copyWith(
            color: AppColors.foam,
            fontSize: 19,
          ),
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.foam,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.navy,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.muted.withValues(alpha: 0.22),
                ),
              ),
            ),
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final e in navEntries) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AppFilterChip(
                        label: e.label,
                        isSelected: _selectedNavLabel == e.label,
                        onTap: () => _scrollToSection(e.key, e.label),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: _generalKey,
                    color: AppColors.navy,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          color: AppColors.encyclopediaCard,
                          child: Column(
                            children: [
                              Text(
                                fish.emoji,
                                style: AppTextStyles.h1.copyWith(
                                  fontSize: 64,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                fish.name,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.h2.copyWith(
                                  color: AppColors.foam,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fish.scientificName,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.muted,
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                fishCategoryDisplayLabel(fish.category),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _zorlukRenk(fish.difficulty)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _zorlukRenk(fish.difficulty)
                                      .withValues(alpha: 0.65),
                                ),
                              ),
                              child: Text(
                                'Zorluk: ${_zorlukEtiket(fish.difficulty)}',
                                style: AppTextStyles.body.copyWith(
                                  color: _zorlukRenk(fish.difficulty),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    key: _seasonKey,
                    child: _Section(
                      title: '🌤️ Hangi mevsimde tutulur?',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mevsimMetni.isEmpty ? '—' : mevsimMetni,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.foam,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'En iyi aylar',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.muted,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final ay in _turkishMonthNames)
                                GestureDetector(
                                  onTap: () => _onMonthChipTap(ay),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _selectedMonth == ay
                                          ? AppColors.primary
                                              .withValues(alpha: 0.35)
                                          : AppColors.navy
                                              .withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _selectedMonth == ay
                                            ? AppColors.primary
                                            : AppColors.muted
                                                .withValues(alpha: 0.35),
                                        width:
                                            _selectedMonth == ay ? 2 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      ay,
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.foam,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (fish.bestMonths.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Özet: $aylarMetni',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.muted,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: selectedMonth == null
                                ? const SizedBox.shrink(
                                    key:
                                        ValueKey<String>('av-summary-none'),
                                  )
                                : _MonthAvSummaryCard(
                                    key: ValueKey<String>(selectedMonth),
                                    monthLabel: selectedMonth,
                                    isBestPeriod: isSelectedMonthBest,
                                  ),
                          ),
                          if (fish.habitats.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Öne çıkan yerler',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.muted,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...fish.habitats.map((h) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• ',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.accent,
                                        fontSize: 17,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        h,
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.muted,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(
                                        Icons.map_outlined,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        'Haritada Gör',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () {
                                        context.go(AppRoutes.home);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    key: _baitKey,
                    child: _Section(
                      title: '🪱 Hangi yemlere gelir?',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: fish.baits.map((b) => _Chip(b)).toList(),
                      ),
                    ),
                  ),
                  Container(
                    key: _avlanmaKey,
                    child: _Section(
                      title: '🎣 Nasıl avlanır?',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            fish.techniques.map((t) => _Chip(t)).toList(),
                      ),
                    ),
                  ),
                  if (fish.istanbulGear case final gear?
                      when gear.hasDisplayableData)
                    Container(
                      key: _tackleKey,
                      child: _Section(
                        title: '🎒 Önerilen takım',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'İstanbul av skorunda kullanılan tür dosyasından (olta, teknik, iğne, ağırlık). '
                              'Mevcut deniz ve mevzuata göre uyarlamanız gerekebilir.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.muted,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (gear.tackle.isNotEmpty)
                              _GearDetailLine(
                                label: 'Yem / takım',
                                value: gear.tackle,
                              ),
                            if (gear.technique.isNotEmpty)
                              _GearDetailLine(
                                label: 'Teknik',
                                value: gear.technique,
                              ),
                            if (gear.hookSize.isNotEmpty)
                              _GearDetailLine(
                                label: 'İğne numarası',
                                value: gear.hookSize,
                              ),
                            if (gear.weightGr > 0)
                              _GearDetailLine(
                                label: 'Ağırlık (öneri)',
                                value: '${gear.weightGr} g',
                              ),
                            if (gear.weightGr <= 0 &&
                                gear.technique.toLowerCase().contains('yüzey'))
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Yüzey avı — kurşun ekini koşula göre ayarlayın.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.muted,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  Container(
                    key: _tipsKey,
                    child: _Section(
                      title: '💡 İpuçları',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: fish.tips.map((tip) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.accent,
                                    fontSize: 17,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    tip,
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.muted,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  if (fish.minLegalSizeCm != null)
                    Container(
                      key: _legalKey,
                      child: _Section(
                        title: '📏 Minimum boy (av mevzuatı)',
                        child: Text(
                          '${fish.minLegalSizeCm} cm',
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.accent,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  Container(
                    key: _funFactKey,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '💬 İlginç bilgi',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.foam,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              fish.funFact,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.foam,
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthAvSummaryCard extends StatelessWidget {
  final String monthLabel;
  final bool isBestPeriod;

  const _MonthAvSummaryCard({
    super.key,
    required this.monthLabel,
    required this.isBestPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final text = isBestPeriod
        ? '⭐ $monthLabel: Bu balık için iyi bir dönem!'
        : 'ℹ️ $monthLabel: Sezon dışı, av azalabilir.';
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        color: AppColors.navy.withValues(alpha: 0.55),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(
              color: AppColors.foam,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.encyclopediaCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.body.copyWith(
              color: AppColors.foam,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _GearDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _GearDetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: AppColors.foam,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.body.copyWith(
          color: AppColors.foam,
          fontSize: 16,
        ),
      ),
    );
  }
}
