import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences nesnesini senkron olarak sağlayan provider.
/// main() metodunda await SharedPreferences.getInstance() ile başlatılıp
/// overrideWithValue ile Riverpod scope içine enjekte edilmelidir.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider main.dart içinde override edilmedi.',
  );
});

/// Kullanıcının onboarding'i (3 adımı) tamamlayıp tamamlamadığını tutan state.
/// Başlangıç değeri varsayılan olarak `false`dur.
class OnboardingStateNotifier extends Notifier<bool> {
  static const _key = 'isOnboardingCompleted';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> completeOnboarding() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, true);
    state = true;
  }
}

final onboardingStateProvider = NotifierProvider<OnboardingStateNotifier, bool>(
  OnboardingStateNotifier.new,
);
