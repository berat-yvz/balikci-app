import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/preferences_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  @override
  Widget build(BuildContext context) {
    // Auth state'ini dinle, hata varsa ScaffoldMessenger ile göster
    ref.listen(authNotifierProvider, (previous, next) {
      if (next is AsyncError) {
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
          context.go(done ? '/home' : '/onboarding');
        }
      }
    });

    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Başlık
                  const Icon(
                    Icons.sailing,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Balıkçı',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h1,
                  ),
                  const SizedBox(height: 48),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'E-posta boş olamaz';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Geçerli bir e-posta girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Şifre
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
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
                  const SizedBox(height: 24),

                  // Giriş Yap Butonu
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _submit,
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Giriş Yap'),
                  ),
                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    onPressed: authState.isLoading
                        ? null
                        : () async {
                            await ref
                                .read(authNotifierProvider.notifier)
                                .signInWithGoogle();
                            if (!context.mounted) return;
                            if (ref.read(authNotifierProvider).hasError) {
                              return;
                            }
                            if (ref.read(authRepositoryProvider).isLoggedIn()) {
                              final done = ref.read(onboardingStateProvider);
                              context.go(done ? '/home' : '/onboarding');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Tarayıcıda Google ile girişi tamamlayın; '
                                    'uygulamaya döndüğünüzde oturum açılır.',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.login),
                    label: const Text('Google ile devam et'),
                  ),
                  const SizedBox(height: 16),

                  // Kayıt Ol Butonu
                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => context.go('/register'),
                    child: const Text('Hesabın yok mu? Kayıt ol'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
