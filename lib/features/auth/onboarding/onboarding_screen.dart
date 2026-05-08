import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/notification_service.dart';
import 'package:balikci_app/features/auth/onboarding/step_welcome.dart';
import 'package:balikci_app/shared/providers/preferences_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _bgParallaxController;
  late final AnimationController _pinDropController;
  late final AnimationController _bellRippleController;

  bool _busyLocation = false;
  bool _busyNotif = false;

  LocationPermission? _locationPermission;
  AuthorizationStatus? _notifStatus;

  bool get _locationAllowed =>
      _locationPermission == LocationPermission.always ||
      _locationPermission == LocationPermission.whileInUse;

  bool get _notifAllowed =>
      _notifStatus == AuthorizationStatus.authorized ||
      _notifStatus == AuthorizationStatus.provisional;

  bool get _isBusy => _busyLocation || _busyNotif;

  @override
  void initState() {
    super.initState();
    _bgParallaxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _pinDropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bellRippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshLocationStatus());
      unawaited(_refreshNotificationStatus());
    });
  }

  /// Kullanıcı konum/bildirim ayarlarından uygulamaya döndüğünde izin
  /// durumunu otomatik yenile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshLocationStatus());
      unawaited(_refreshNotificationStatus());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _bgParallaxController.dispose();
    _pinDropController.dispose();
    _bellRippleController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    await ref.read(onboardingStateProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  String get _bottomLabel {
    if (_currentPage == 1 && !_locationAllowed) return 'Konum İzni Ver';
    if (_currentPage == 2 && !_notifAllowed) return 'Bildirimlere İzin Ver';
    if (_currentPage == 3) return 'Hadi Başlayalım!';
    return 'İleri';
  }

  VoidCallback get _primaryAction {
    if (_currentPage == 1 && !_locationAllowed) return _requestLocation;
    if (_currentPage == 2 && !_notifAllowed) return _requestNotifications;
    if (_currentPage == 3) return _finishOnboarding;
    return _nextPage;
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _refreshLocationStatus() async {
    try {
      final p = await Geolocator.checkPermission();
      if (!mounted) return;
      setState(() => _locationPermission = p);
    } catch (e) {
      debugPrint('Konum izni durumu alınamadı: $e');
    }
  }

  Future<void> _requestLocation() async {
    if (_busyLocation) return;
    setState(() => _busyLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        await Geolocator.openLocationSettings();
      }

      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      setState(() => _locationPermission = p);
    } finally {
      if (mounted) setState(() => _busyLocation = false);
    }
  }

  Future<void> _refreshNotificationStatus() async {
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      if (!mounted) return;
      setState(() => _notifStatus = s.authorizationStatus);
    } catch (e) {
      debugPrint('Bildirim izni durumu alınamadı: $e');
    }
  }

  Future<void> _requestNotifications() async {
    if (_busyNotif) return;
    setState(() => _busyNotif = true);
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (!mounted) return;
      setState(() => _notifStatus = settings.authorizationStatus);
      if (_notifAllowed) {
        try {
          await NotificationService.syncFcmToken();
        } catch (e) {
          debugPrint('FCM token senkronizasyonu başarısız: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _busyNotif = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgParallaxController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ParallaxSeaPainter(t: _bgParallaxController.value),
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      const StepWelcome(),
                      _OnboardingPage(
                        title: _locationAllowed
                            ? 'Konum İzni Verildi ✓'
                            : 'Nerede Balık Tutacaksın?',
                        subtitle: _locationAllowed
                            ? 'Harika! Yakınındaki meraları ve hava durumunu görebilirsin.'
                            : 'Yakınındaki meraları, aktif bildirimleri ve hava durumunu gösterebilmem için konumuna ihtiyacım var.',
                        illustration: AnimatedBuilder(
                          animation: _pinDropController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _LocationPinDropPainter(
                                t: _pinDropController.value,
                              ),
                            );
                          },
                        ),
                      ),
                      _OnboardingPage(
                        title: _notifAllowed
                            ? 'Bildirimler Açık ✓'
                            : 'Balık Tutulurken Haberdar Ol',
                        subtitle: _notifAllowed
                            ? 'Harika! Favori meranda yoğunluk artınca seni haberdar edeceğiz.'
                            : 'Favori merana yeni bildirim gelince, yakında yoğunluk artınca veya sabah hava ideale dönünce seni bilgilendireyim.',
                        illustration: AnimatedBuilder(
                          animation: _bellRippleController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _BellRipplePainter(
                                t: _bellRippleController.value,
                              ),
                            );
                          },
                        ),
                      ),
                      const _OnboardingPage(
                        title: 'Her Şey Hazır! 🎣',
                        subtitle:
                            'Haritayı aç, yakınındaki meralara bak.\nİlk bildirimi yap, topluluğa katıl.',
                        illustration: _FishingHeroIllustration(),
                      ),
                    ],
                  ),
                ),

                // Progress dots + bottom action
                Container(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + safeBottom),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.85),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final active = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: active ? 22 : 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.teal
                                  : AppColors.foam.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isBusy ? null : _primaryAction,
                          child: _isBusy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_bottomLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // "Atla" — son sayfada (sayfa 3) ve yükleme sırasında gizlenir.
          if (_currentPage < 3)
            Positioned(
              right: 12,
              top: safeTop + 6,
              child: Material(
                type: MaterialType.transparency,
                child: TextButton(
                  onPressed: _isBusy ? null : () => unawaited(_finishOnboarding()),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Atla'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget illustration;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.illustration,
  });

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
                child: Stack(
                  children: [
                    Positioned.fill(child: illustration),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.foam,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.foam.withValues(alpha: 0.82),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParallaxSeaPainter extends CustomPainter {
  final double t; // 0..1
  _ParallaxSeaPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.navy,
            const Color(0xFF07182D),
            AppColors.background,
          ],
        ).createShader(rect),
    );

    // Two parallax wave layers
    _wave(canvas, size, y: 0.30, amp: 10, speed: 1.2, alpha: 0.10);
    _wave(canvas, size, y: 0.46, amp: 14, speed: 0.8, alpha: 0.12);
    _wave(canvas, size, y: 0.70, amp: 18, speed: 0.55, alpha: 0.10);
  }

  void _wave(
    Canvas canvas,
    Size size, {
    required double y,
    required double amp,
    required double speed,
    required double alpha,
  }) {
    final w = size.width;
    final h = size.height;
    final baseY = h * y;
    final phase = t * 2 * math.pi * speed;
    final p = Path()..moveTo(0, baseY);
    for (double x = 0; x <= w; x += 12) {
      final yy = baseY + amp * math.sin((x / w) * 2 * math.pi + phase);
      p.lineTo(x, yy);
    }
    final paint = Paint()
      ..color = AppColors.teal.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant _ParallaxSeaPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _LocationPinDropPainter extends CustomPainter {
  final double t; // 0..1
  _LocationPinDropPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w * 0.50, h * 0.46);

    // Mini map grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double x = 0; x <= w; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y <= h; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Pin yukarıdan (h*0.14) aşağıya (h*0.48) düşer, easeOut ile yavaşlar
    final drop = Curves.easeOut.transform(t);
    final pinY = h * 0.14 + (h * 0.34) * drop;
    final pinC = Offset(c.dx, pinY);

    // Konuma oturunca altında küçük bir daire genişler
    if (t > 0.85) {
      final landT = (t - 0.85) / 0.15;
      canvas.drawCircle(
        c.translate(0, 70),
        10 + 14 * landT,
        Paint()
          ..color = AppColors.teal.withValues(alpha: 0.18 * (1 - landT))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(c.translate(0, 70), 14 + 10 * (1 - drop), shadow);

    final pinPaint = Paint()
      ..color = AppColors.teal.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(pinC.dx, pinC.dy - 22)
      ..cubicTo(
        pinC.dx + 18,
        pinC.dy - 18,
        pinC.dx + 18,
        pinC.dy + 6,
        pinC.dx,
        pinC.dy + 28,
      )
      ..cubicTo(
        pinC.dx - 18,
        pinC.dy + 6,
        pinC.dx - 18,
        pinC.dy - 18,
        pinC.dx,
        pinC.dy - 22,
      )
      ..close();
    canvas.drawPath(path, pinPaint);
    canvas.drawCircle(
      pinC.translate(0, -4),
      8,
      Paint()..color = AppColors.navy.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _LocationPinDropPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _BellRipplePainter extends CustomPainter {
  final double t; // 0..1
  _BellRipplePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w * 0.50, h * 0.42);

    final bw = w * 0.11; // zil yarı genişliği
    final bh = h * 0.15; // zil kubbe yüksekliği

    // ── Hafif sallanma animasyonu ─────────────────────────────────────────
    final swing = math.sin(t * 2 * math.pi) * 0.07; // radyan
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(swing);
    canvas.translate(-c.dx, -c.dy);

    // ── Zil gövdesi (path ile düzgün zil şekli) ───────────────────────────
    final bellPath = Path();
    // Sol alt köşeden başla
    bellPath.moveTo(c.dx - bw - 7, c.dy + 8);
    bellPath.lineTo(c.dx + bw + 7, c.dy + 8); // taban düz kenar (etek)
    bellPath.lineTo(c.dx + bw, c.dy);
    // Sağ kavis
    bellPath.cubicTo(
      c.dx + bw,     c.dy - bh * 0.55,
      c.dx + bw * 0.35, c.dy - bh,
      c.dx,          c.dy - bh,
    );
    // Sol kavis
    bellPath.cubicTo(
      c.dx - bw * 0.35, c.dy - bh,
      c.dx - bw,     c.dy - bh * 0.55,
      c.dx - bw,     c.dy,
    );
    bellPath.close();

    // Dolgu
    canvas.drawPath(
      bellPath,
      Paint()..color = AppColors.foam.withValues(alpha: 0.12),
    );
    // Kenarlık
    canvas.drawPath(
      bellPath,
      Paint()
        ..color = AppColors.foam.withValues(alpha: 0.60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Sap (zil kulpu) ────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(c.dx, c.dy - bh),
      Offset(c.dx, c.dy - bh - 10),
      Paint()
        ..color = AppColors.foam.withValues(alpha: 0.55)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // ── Çan (clapper) ──────────────────────────────────────────────────────
    // Sallantıyla birlikte hafif sağa sola kayar
    final clapperX = c.dx + bw * 0.35 * math.sin(t * 2 * math.pi);
    canvas.drawCircle(
      Offset(clapperX, c.dy + 18),
      6,
      Paint()..color = AppColors.sand.withValues(alpha: 0.85),
    );

    canvas.restore(); // sallantı dönüşümü bitti

    // ── Dalgalanan bildirim halkaları ──────────────────────────────────────
    final ripplePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    for (int i = 0; i < 3; i++) {
      final tt = (t + i * 0.33) % 1.0;
      final radius = 28.0 + 48.0 * tt;
      ripplePaint.color = AppColors.teal.withValues(alpha: 0.28 * (1 - tt));
      canvas.drawCircle(c, radius, ripplePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BellRipplePainter oldDelegate) =>
      oldDelegate.t != t;
}

/// Son onboarding sayfası — balıkçı sahnesi.
/// Kendi AnimationController'ı ile balık yüzmesi + su dalgalanması.
class _FishingHeroIllustration extends StatefulWidget {
  const _FishingHeroIllustration();

  @override
  State<_FishingHeroIllustration> createState() =>
      _FishingHeroIllustrationState();
}

class _FishingHeroIllustrationState extends State<_FishingHeroIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) =>
          CustomPaint(painter: _FishingHeroPainter(t: _ctrl.value)),
    );
  }
}

class _FishingHeroPainter extends CustomPainter {
  final double t; // 0..1
  _FishingHeroPainter({this.t = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Ufuk parıltısı ────────────────────────────────────────────────────
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.sand.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(w * 0.55, h * 0.28),
            radius: h * 0.65,
          ),
        ),
    );

    // ── Su yüzeyi ─────────────────────────────────────────────────────────
    final waveY = h * 0.58 + 3 * math.sin(t * 2 * math.pi);

    // Su dolgusu
    final waterPath = Path()
      ..moveTo(0, waveY)
      ..lineTo(w, waveY)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      waterPath,
      Paint()..color = AppColors.teal.withValues(alpha: 0.09),
    );

    // Su çizgisi
    canvas.drawLine(
      Offset(0, waveY),
      Offset(w, waveY),
      Paint()
        ..color = AppColors.teal.withValues(alpha: 0.40)
        ..strokeWidth = 2,
    );

    // ── Balıkçı silüeti ───────────────────────────────────────────────────
    final bodyColor = Colors.white.withValues(alpha: 0.22);
    // Kafa
    canvas.drawCircle(Offset(w * 0.28, h * 0.49), 10, Paint()..color = bodyColor);
    // Gövde
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.265, h * 0.50, 28, 40),
        const Radius.circular(12),
      ),
      Paint()..color = bodyColor,
    );

    // ── Olta kamışı ───────────────────────────────────────────────────────
    // El → kamış ucu (geriye ve yukarıya doğru uzanır)
    final rodBase = Offset(w * 0.30, h * 0.54);
    final rodTip  = Offset(w * 0.72, h * 0.38);
    canvas.drawLine(
      rodBase,
      rodTip,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // ── Olta ipi (kamış ucundan suya iner) ───────────────────────────────
    final bobberX = w * 0.78;
    final bobberY = waveY + 1.5 * math.sin(t * 2 * math.pi + 0.8);

    // İp: kamış ucundan şamandıraya parabolik eğri
    final lineP = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final linePath = Path()
      ..moveTo(rodTip.dx, rodTip.dy)
      ..quadraticBezierTo(
        bobberX + (rodTip.dx - bobberX) * 0.2, // kontrol noktası
        waveY - 18,
        bobberX,
        bobberY,
      );
    canvas.drawPath(linePath, lineP);

    // ── Şamandıra ─────────────────────────────────────────────────────────
    // Gövde (kırmızı)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bobberX, bobberY - 4),
        width: 8,
        height: 14,
      ),
      Paint()..color = AppColors.danger.withValues(alpha: 0.75),
    );
    // Alt yarı (beyaz)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bobberX, bobberY + 2),
        width: 8,
        height: 8,
      ),
      Paint()..color = AppColors.foam.withValues(alpha: 0.55),
    );

    // ── Sudaki balık ──────────────────────────────────────────────────────
    _drawFish(canvas, w, h, waveY, t);
  }

  void _drawFish(
    Canvas canvas,
    double w,
    double h,
    double waterY,
    double t,
  ) {
    // Sinüs dalgasıyla soldan sağa gidip gelen balık
    final fishX = w * 0.42 + w * 0.28 * math.sin(t * 2 * math.pi * 0.6);
    final fishY = waterY +
        h * 0.08 +
        h * 0.015 * math.sin(t * 2 * math.pi * 1.1 + 1.0);

    // Hareket yönü: pozitif → sağa, negatif → sola
    final vel = math.cos(t * 2 * math.pi * 0.6);

    final fishColor = AppColors.teal.withValues(alpha: 0.62);
    final finColor  = AppColors.teal.withValues(alpha: 0.38);

    canvas.save();
    canvas.translate(fishX, fishY);
    if (vel < 0) canvas.scale(-1.0, 1.0); // sola gidince çevir

    // Kuyruk yüzgeci
    final tailPath = Path()
      ..moveTo(-14, 0)
      ..lineTo(-25, -9)
      ..lineTo(-25, 9)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = fishColor);

    // Gövde
    final bodyPath = Path()
      ..moveTo(17, 0)
      ..cubicTo(12, -9, -10, -9, -14, 0)
      ..cubicTo(-10, 9, 12, 9, 17, 0)
      ..close();
    canvas.drawPath(bodyPath, Paint()..color = fishColor);

    // Sırt yüzgeci
    final dorsal = Path()
      ..moveTo(4, -9)
      ..lineTo(-4, -18)
      ..lineTo(-12, -9)
      ..close();
    canvas.drawPath(dorsal, Paint()..color = finColor);

    // Göz
    canvas.drawCircle(
      const Offset(10, -2),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    canvas.drawCircle(
      const Offset(10, -2),
      1.2,
      Paint()..color = Colors.black.withValues(alpha: 0.40),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FishingHeroPainter old) => old.t != t;
}
