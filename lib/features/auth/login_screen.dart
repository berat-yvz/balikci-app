import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/preferences_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  // cleaned: dialog doğrulaması ve async context kullanımı lint uyumlu hale getirildi
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _googleLoading = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shake;

  late final AnimationController _headerAnimController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shake = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -10, end: 8), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -6, end: 4), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 4, end: -2), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -2, end: 0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));

    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    _headerAnimController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      // Form geçerliyse
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Hata denetimi provider'da yapılır ve UI state üzerinden dinlenir
      await ref.read(authNotifierProvider.notifier).signIn(email, password);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final dialogFormKey = GlobalKey<FormState>();
    final forgotEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    String? dialogError;
    bool sending = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.lock_reset, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Şifremi Unuttum',
                    style: AppTextStyles.h3.copyWith(color: Colors.white),
                  ),
                ],
              ),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'E-posta adresini gir, şifre sıfırlama bağlantısı gönderelim.',
                      style: AppTextStyles.body.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: forgotEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'E-posta boş bırakılamaz';
                        }
                        if (!text.contains('@')) {
                          return 'Geçerli bir e-posta girin';
                        }
                        return null;
                      },
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        dialogError!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          if (!(dialogFormKey.currentState?.validate() ??
                              false)) {
                            return;
                          }
                          setDialogState(() {
                            sending = true;
                            dialogError = null;
                          });
                          try {
                            await ref
                                .read(authRepositoryProvider)
                                .resetPassword(
                                  forgotEmailController.text.trim(),
                                );
                            if (!mounted) return;
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Şifre sıfırlama bağlantısı e-postana gönderildi. Spam klasörünü de kontrol et.',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              dialogError = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                              sending = false;
                            });
                          }
                        },
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Gönder'),
                ),
              ],
            );
          },
        );
      },
    );

    forgotEmailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Auth state'ini dinle, hata varsa ScaffoldMessenger ile göster
    ref.listen(authNotifierProvider, (previous, next) {
      if (next is AsyncError) {
        _shakeController.forward(from: 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      if (next is AsyncData<User?>) {
        final u = next.value;
        final prevUser = previous is AsyncData<User?> ? previous.value : null;
        if (u != null && u != prevUser) {
          final done = ref.read(onboardingStateProvider);
          context.go(done ? AppRoutes.home : AppRoutes.onboarding);
        }
      }
    });

    final authState = ref.watch(authNotifierProvider);

    final media = MediaQuery.of(context);
    final topPad = media.padding.top;
    final bottomPad = media.padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A1628),
                    const Color(0xFF0D2137),
                    const Color(0xFF0A1628),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Subtle wave/fish header paint
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 220 + topPad,
            child: SafeArea(
              bottom: false,
              child: AnimatedBuilder(
                animation: _headerAnimController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _HeaderSeaPainter(t: _headerAnimController.value),
                  );
                },
              ),
            ),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 16 + bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  _LogoLockup(),
                  const SizedBox(height: 18),

                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shake.value, 0),
                        child: child,
                      );
                    },
                    child: _FrostedCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Giriş Yap',
                              style: AppTextStyles.h2.copyWith(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'E-posta',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'E-posta boş olamaz';
                                }
                                if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ).hasMatch(value)) {
                                  return 'Geçerli bir e-posta girin';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!authState.isLoading) _submit();
                              },
                              decoration: InputDecoration(
                                labelText: 'Şifre',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Şifre boş olamaz';
                                }
                                if (value.length < 6) {
                                  return 'Şifre en az 6 karakter olmalı';
                                }
                                return null;
                              },
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: authState.isLoading
                                    ? null
                                    : _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  foregroundColor: AppColors.primary,
                                ),
                                child: const Text(
                                  'Şifremi Unuttum',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _TealGradientButton(
                              onPressed: authState.isLoading ? null : _submit,
                              loading: authState.isLoading,
                              label: 'Giriş Yap',
                            ),
                            const SizedBox(height: 10),
                            _GoogleOutlineButton(
                              loading: _googleLoading,
                              onPressed: (authState.isLoading || _googleLoading)
                                  ? null
                                  : () async {
                                      setState(() => _googleLoading = true);
                                      try {
                                        await ref
                                            .read(authNotifierProvider.notifier)
                                            .signInWithGoogle();
                                        if (!context.mounted) return;
                                        if (ref
                                            .read(authNotifierProvider)
                                            .hasError) {
                                          return;
                                        }
                                        if (ref
                                            .read(authRepositoryProvider)
                                            .isLoggedIn()) {
                                          final done = ref.read(
                                            onboardingStateProvider,
                                          );
                                          context.go(
                                            done
                                                ? AppRoutes.home
                                                : AppRoutes.onboarding,
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Tarayıcıda Google ile girişi tamamlayın; '
                                                'uygulamaya döndüğünüzde oturum açılır.',
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(
                                            () => _googleLoading = false,
                                          );
                                        }
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => context.go(AppRoutes.register),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.foam.withValues(alpha: 0.92),
                    ),
                    child: const Text('Hesap yok mu? Kayıt ol'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoLockup extends StatelessWidget {
  const _LogoLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: SvgPicture.asset(
            'assets/images/logo.svg',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Balıkçı',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                const _FishAnimation(),
              ],
            ),
            Text(
              'Super App',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.75),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FishAnimation extends StatefulWidget {
  const _FishAnimation();

  @override
  State<_FishAnimation> createState() => _FishAnimationState();
}

class _FishAnimationState extends State<_FishAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _swimX;
  late Animation<double> _wobble;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _swimX = Tween<double>(
      begin: -6,
      end: 6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _wobble = Tween<double>(
      begin: -0.08,
      end: 0.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_swimX.value, 0),
          child: Transform.rotate(
            angle: _wobble.value,
            child: const Text('🐟', style: TextStyle(fontSize: 28)),
          ),
        );
      },
    );
  }
}

class _FrostedCard extends StatelessWidget {
  final Widget child;
  const _FrostedCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.dark.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _TealGradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  const _TealGradientButton({
    required this.onPressed,
    required this.loading,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class _GoogleOutlineButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  const _GoogleOutlineButton({required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.30)),
          foregroundColor: AppColors.foam,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('Google ile bağlanıyor...'),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'G',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Google ile Giriş'),
                ],
              ),
      ),
    );
  }
}

class _HeaderSeaPainter extends CustomPainter {
  final double t; // 0..1
  _HeaderSeaPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Soft glow
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.teal.withValues(alpha: 0.18),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(w * 0.7, h * 0.2), radius: h),
          );
    canvas.drawRect(Offset.zero & size, glowPaint);

    // Waves
    final wavePaint = Paint()
      ..color = AppColors.teal.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 3; i++) {
      final yBase = h * (0.55 + i * 0.12);
      final phase = (t * 2 * 3.14159) + i * 0.8;
      final path = Path()..moveTo(0, yBase);
      for (double x = 0; x <= w; x += 12) {
        final amp = 6.0 + i * 3.0;
        final y = yBase + amp * math.sin((x / w) * (math.pi * 2) + phase);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, wavePaint);
    }

    // Small fish silhouette
    final fishX = w * (0.18 + 0.64 * t);
    final fishY = h * 0.36 + 10 * math.sin(t * math.pi * 2);
    final fishPaint = Paint()
      ..color = AppColors.foam.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final fish = Path()
      ..moveTo(fishX, fishY)
      ..quadraticBezierTo(fishX + 16, fishY - 8, fishX + 28, fishY)
      ..quadraticBezierTo(fishX + 16, fishY + 8, fishX, fishY)
      ..close()
      ..moveTo(fishX + 28, fishY)
      ..lineTo(fishX + 38, fishY - 6)
      ..lineTo(fishX + 38, fishY + 6)
      ..close();
    canvas.drawPath(fish, fishPaint);
  }

  @override
  bool shouldRepaint(covariant _HeaderSeaPainter oldDelegate) =>
      oldDelegate.t != t;
}
