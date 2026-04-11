import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/features/auth/reset_password_screen.dart';

/// Supabase gerektirmeyen form validasyon testleri.
/// _saveNewPassword yalnızca validasyon geçince çağrılır.

Widget _wrap(Widget child) {
  return MaterialApp(home: child);
}

void main() {
  group('ResetPasswordScreen — form validasyonu', () {
    testWidgets('ekran başlığı görünür', (tester) async {
      await tester.pumpWidget(_wrap(const ResetPasswordScreen()));
      await tester.pump();
      expect(find.text('Şifre Sıfırla'), findsWidgets);
      expect(find.text('Yeni şifreni belirle'), findsOneWidget);
    });

    testWidgets('boş form gönderilince hata mesajı görünür', (tester) async {
      await tester.pumpWidget(_wrap(const ResetPasswordScreen()));
      await tester.pump();

      await tester.tap(find.text('Şifreyi Güncelle'));
      await tester.pump();

      expect(find.text('Şifre boş bırakılamaz'), findsOneWidget);
    });

    testWidgets('5 karakterli şifre → minimum uzunluk hatası', (tester) async {
      await tester.pumpWidget(_wrap(const ResetPasswordScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, '12345');
      await tester.tap(find.text('Şifreyi Güncelle'));
      await tester.pump();

      expect(find.text('Şifre en az 6 karakter olmalı'), findsOneWidget);
    });

    testWidgets('şifreler eşleşmeyince hata mesajı görünür', (tester) async {
      await tester.pumpWidget(_wrap(const ResetPasswordScreen()));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'sifre123');
      await tester.enterText(fields.at(1), 'farkli123');
      await tester.tap(find.text('Şifreyi Güncelle'));
      await tester.pump();

      expect(find.text('Şifreler eşleşmiyor'), findsOneWidget);
    });

    testWidgets('geçerli ve eşleşen şifre girince validasyon hatası yok', (tester) async {
      await tester.pumpWidget(_wrap(const ResetPasswordScreen()));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'gecerli123');
      await tester.enterText(fields.at(1), 'gecerli123');
      await tester.pump();

      // Hata mesajları olmamalı
      expect(find.text('Şifre boş bırakılamaz'), findsNothing);
      expect(find.text('Şifre en az 6 karakter olmalı'), findsNothing);
      expect(find.text('Şifreler eşleşmiyor'), findsNothing);
    });

    testWidgets('göster/gizle ikonu şifre alanı görünürlüğünü değiştirir',
        (tester) async {
      await tester.pumpWidget(_wrap(const ResetPasswordScreen()));
      await tester.pump();

      // İlk alanda visibility_off ikonu olmalı (obscureText=true)
      expect(find.byIcon(Icons.visibility_off), findsWidgets);

      // İlk visibility_off ikonuna tıkla
      await tester.tap(find.byIcon(Icons.visibility_off).first);
      await tester.pump();

      // Artık bir visibility ikonu görünmeli
      expect(find.byIcon(Icons.visibility), findsWidgets);
    });

    testWidgets('6 karakterli şifre kabul edilir — minimum sınır', (tester) async {
      await tester.pumpWidget(_wrap(const ResetPasswordScreen()));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'abc123');
      await tester.enterText(fields.at(1), 'abc123');
      await tester.tap(find.text('Şifreyi Güncelle'));
      await tester.pump();

      expect(find.text('Şifre en az 6 karakter olmalı'), findsNothing);
      expect(find.text('Şifreler eşleşmiyor'), findsNothing);
    });
  });
}
