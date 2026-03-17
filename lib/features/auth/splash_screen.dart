import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Splash ekranını en az 2 saniye göster
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final isLoggedIn = ref.read(isLoggedInProvider);
    if (isLoggedIn) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Spacer(),
            Text(
              'Balıkçı',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Super App',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            Spacer(),
            CircularProgressIndicator(
              color: AppColors.primary,
            ),
            SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
