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
    with TickerProviderStateMixin {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshLocationStatus());
      unawaited(_refreshNotificationStatus());
    });
  }

  @override
  void dispose() {
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
          Positioned(
            right: 12,
            top: safeTop + 6,
            child: TextButton(
              onPressed: _finishOnboarding,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.muted,
                minimumSize: const Size(48, 48),
              ),
              child: const Text('Atla'),
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
                        title: 'Seni Nerede Arayayım?',
                        subtitle:
                            'Yakınındaki meraları, aktif bildirimleri ve hava durumunu gösterebilmem için konumuna ihtiyacım var.',
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
                        primaryLabel: _locationAllowed
                            ? 'Konum izni verildi ✓'
                            : 'Konum İzni Ver',
                        primaryEnabled: !_locationAllowed && !_busyLocation,
                        onPrimary: _requestLocation,
                        secondaryLabel: 'İstersen sonra',
                        onSecondary: () => _nextPage(),
                      ),
                      _OnboardingPage(
                        title: 'Balık Tutulurken Haberdar Ol',
                        subtitle:
                            'Favori merana yeni bildirim gelince, yakında yoğunluk artınca veya sabah hava ideale dönünce seni bilgilendireyim.',
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
                        primaryLabel: _notifAllowed
                            ? 'Bildirim izni verildi ✓'
                            : 'Bildirimlere İzin Ver',
                        primaryEnabled: !_notifAllowed && !_busyNotif,
                        onPrimary: _requestNotifications,
                        secondaryLabel: 'İstersen sonra',
                        onSecondary: () => _nextPage(),
                      ),
                      _OnboardingPage(
                        title: 'Her Şey Hazır! 🎣',
                        subtitle:
                            'Haritayı aç, yakınındaki meralara bak.\nİlk bildirimi yap, topluluğa katıl.',
                        illustration: const _FishingHeroIllustration(),
                        primaryLabel: 'Hadi Başlayalım!',
                        primaryEnabled: true,
                        onPrimary: _finishOnboarding,
                        secondaryLabel: null,
                        onSecondary: null,
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
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          child: Text(_currentPage == 3 ? 'Hadi Başlayalım!' : 'İleri'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

  final String primaryLabel;
  final bool primaryEnabled;
  final VoidCallback onPrimary;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
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
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.foam.withValues(alpha: 0.78),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: primaryEnabled ? onPrimary : null,
                                child: Text(primaryLabel),
                              ),
                            ),
                            if (secondaryLabel != null) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: onSecondary,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                    ),
                                    foregroundColor: AppColors.foam.withValues(
                                      alpha: 0.90,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(secondaryLabel!),
                                ),
                              ),
                            ],
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

    // Pin drop
    final drop = Curves.easeInOut.transform(t);
    final pinY = h * 0.18 + (h * 0.34) * (1 - drop);
    final pinC = Offset(c.dx, pinY);

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
    final c = Offset(w * 0.50, h * 0.44);

    final bellPaint = Paint()
      ..color = AppColors.foam.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCenter(
      center: c.translate(0, -8),
      width: w * 0.22,
      height: h * 0.28,
    );
    canvas.drawArc(rect, math.pi, math.pi, false, bellPaint);
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.right, rect.bottom),
      bellPaint,
    );
    canvas.drawCircle(
      c.translate(0, 28),
      6,
      Paint()..color = AppColors.sand.withValues(alpha: 0.75),
    );

    final ripplePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 0; i < 2; i++) {
      final tt = (t + i * 0.35) % 1.0;
      ripplePaint.color = AppColors.teal.withValues(alpha: 0.18 * (1 - tt));
      canvas.drawCircle(c.translate(0, -8), 26 + 22 * tt, ripplePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BellRipplePainter oldDelegate) =>
      oldDelegate.t != t;
}

class _FishingHeroIllustration extends StatelessWidget {
  const _FishingHeroIllustration();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _FishingHeroPainter());
  }
}

class _FishingHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Horizon glow
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.sand.withValues(alpha: 0.12),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(w * 0.55, h * 0.35),
              radius: h * 0.7,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);

    // Sea line
    final seaPaint = Paint()
      ..color = AppColors.teal.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, h * 0.58), Offset(w, h * 0.58), seaPaint);

    // Simple silhouette: fisherman + rod
    final man = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.30, h * 0.50), 10, man);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.285, h * 0.51, 28, 38),
        const Radius.circular(12),
      ),
      man,
    );

    final rod = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.32, h * 0.55),
      Offset(w * 0.70, h * 0.40),
      rod,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
