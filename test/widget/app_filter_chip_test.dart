import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/shared/widgets/app_filter_chip.dart';

void main() {
  group('AppFilterChip', () {
    testWidgets('etiket görünür ve onTap çağrılır', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppFilterChip(
                label: 'Test Etiket',
                isSelected: false,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Test Etiket'), findsOneWidget);
      await tester.tap(find.text('Test Etiket'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('dense mod küçük font ile render olur', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppFilterChip(
                label: 'Kıyı',
                isSelected: true,
                dense: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Kıyı'));
      expect(text.style?.fontSize, 11);
    });

    testWidgets('seçili chip beyaz metin kullanır', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppFilterChip(
                label: 'Seçili',
                isSelected: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Seçili'));
      expect(text.style?.color, Colors.white);
    });
  });
}
