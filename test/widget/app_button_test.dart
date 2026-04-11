import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/shared/widgets/app_button.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('AppButton — primary (ElevatedButton)', () {
    testWidgets('etiket metni görünür', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppButton(label: 'Kaydet')),
      );
      expect(find.text('Kaydet'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('onPressed callback tetiklenir', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Tıkla', onPressed: () => pressed = true)),
      );
      await tester.tap(find.byType(ElevatedButton));
      expect(pressed, isTrue);
    });

    testWidgets('onPressed null → buton devre dışı', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppButton(label: 'Devre Dışı', onPressed: null)),
      );
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('isLoading=true → spinner gösterilir, etiket yok', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppButton(label: 'Kaydet', isLoading: true)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Kaydet'), findsNothing);
    });

    testWidgets('isLoading=true → tıklanamaz', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        _wrap(AppButton(
          label: 'Kaydet',
          isLoading: true,
          onPressed: () => pressed = true,
        )),
      );
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      expect(pressed, isFalse);
    });
  });

  group('AppButton — outlined (OutlinedButton)', () {
    testWidgets('outlined=true → OutlinedButton gösterilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppButton(label: 'İptal', outlined: true)),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('outlined + callback tetiklenir', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        _wrap(AppButton(
          label: 'İptal',
          outlined: true,
          onPressed: () => pressed = true,
        )),
      );
      await tester.tap(find.byType(OutlinedButton));
      expect(pressed, isTrue);
    });

    testWidgets('outlined + isLoading=true → spinner gösterilir', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppButton(label: 'İptal', outlined: true, isLoading: true)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('İptal'), findsNothing);
    });
  });
}
