import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/main.dart';

void main() {
  testWidgets('Startup error ekranı hata metnini gösterir', (tester) async {
    await tester.pumpWidget(
      const StartupErrorApp(errors: ['Test hata mesajı']),
    );
    expect(find.textContaining('Test hata mesajı'), findsOneWidget);
  });
}
