import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/app/app.dart';
import 'package:visionguard/core/database/database_providers.dart';

import 'database_test.dart' show memoryDb;

void main() {
  testWidgets('Tanpa sesi tersimpan, aplikasi terbuka di halaman Login', (tester) async {
    final db = memoryDb();
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const VisionGuardApp(),
    ));
    // Splash → restoreSession (tiruan, tanpa sesi) → Login.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('VisionGuard'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Masuk'), findsOneWidget);
  });
}
