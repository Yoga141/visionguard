import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/app/app.dart';

void main() {
  testWidgets('Aplikasi terbuka di halaman Login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VisionGuardApp()));
    await tester.pumpAndSettle();
    expect(find.text('VisionGuard'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Masuk'), findsOneWidget);
  });
}
