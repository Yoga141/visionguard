import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:visionguard/app/router.dart';
import 'package:visionguard/core/constants/business_constants.dart';
import 'package:visionguard/features/help/domain/help_content.dart';
import 'package:visionguard/features/help/presentation/help_page.dart';
import 'package:visionguard/shared/widgets/help_button.dart';

void main() {
  test('FAQ memuat topik wajib §7.5', () {
    final all = helpSections().expand((s) => s.entries).map((e) => e.question).join('\n');
    expect(all, contains('Kenapa kamera tidak aktif?'));
    expect(all, contains('Kenapa jarak tidak akurat?'));
    expect(all, contains('Bagaimana kuota gratis dihitung?'));
    expect(all, contains('Apa arti angka di Dashboard?'));
    expect(all, contains('Bagaimana membeli kredit?'));
    final quota = helpSections().firstWhere((s) => s.topic == HelpTopic.kredit).entries.first.answer;
    expect(quota, contains('${BusinessConstants.freeDaysPerMonth} hari'));
    // Setiap topik punya bagian sendiri.
    expect(helpSections().map((s) => s.topic).toSet(), HelpTopic.values.toSet());
  });

  test('halaman Bantuan boleh dibuka tanpa login', () {
    expect(Routes.public, contains(Routes.help));
  });

  testWidgets('HelpPage membuka topik asal layar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpPage(topic: HelpTopic.kalibrasi)));
    expect(find.text('Bantuan & FAQ'), findsOneWidget);
    expect(find.text('Kenapa jarak tidak akurat?'), findsOneWidget); // terbuka
    expect(find.text('Bagaimana membeli kredit?'), findsNothing); // tertutup
  });

  testWidgets('HelpButton membuka /help dengan topik', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(appBar: AppBar(actions: const [HelpButton(topic: HelpTopic.kredit)]))),
      GoRoute(
        path: Routes.help,
        builder: (_, s) => HelpPage(topic: HelpTopic.values.byName(s.uri.queryParameters['topic']!)),
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byTooltip('Bantuan'));
    await tester.pumpAndSettle();
    expect(find.text('Bagaimana membeli kredit?'), findsOneWidget);
  });
}
