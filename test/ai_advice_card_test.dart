import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/features/ai_assistant/application/ai_advice_provider.dart';
import 'package:visionguard/features/ai_assistant/data/ai_advice_repository.dart';
import 'package:visionguard/features/ai_assistant/presentation/ai_advice_card.dart';

class _ControlledRepo implements AiAdviceRepository {
  final completer = Completer<String>();
  AdviceMetrics? received;

  @override
  Future<String> getAdvice(AdviceMetrics metrics) {
    received = metrics;
    return completer.future;
  }
}

void main() {
  const metrics = AdviceMetrics(fatigueScore: 65, blinkRate: 8, distanceCm: 42);

  Future<void> pump(WidgetTester tester, AiAdviceRepository repo, AdviceMetrics? m) =>
      tester.pumpWidget(ProviderScope(
        overrides: [aiAdviceRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: Scaffold(body: AiAdviceCard(metrics: m))),
      ));

  testWidgets('loading lalu hasil; hanya angka ringkasan yang dikirim', (tester) async {
    final repo = _ControlledRepo();
    await pump(tester, repo, metrics);
    expect(find.text('Saran umum, bukan diagnosis medis'), findsOneWidget);

    await tester.tap(find.text('Minta saran'));
    await tester.pump();
    expect(find.text('Menyusun saran...'), findsOneWidget);
    expect(repo.received!.toJson().keys,
        unorderedEquals(['fatigue_score', 'blink_rate', 'perclos', 'distance_cm', 'screen_minutes']));

    repo.completer.complete('• Kedipkan mata perlahan.');
    await tester.pump();
    expect(find.text('• Kedipkan mata perlahan.'), findsOneWidget);
    expect(find.text('Minta lagi'), findsOneWidget);
  });

  testWidgets('error tak terduga → saran statis', (tester) async {
    final repo = _ControlledRepo();
    await pump(tester, repo, metrics);
    await tester.tap(find.text('Minta saran'));
    await tester.pump();
    repo.completer.completeError(Exception('gagal'));
    await tester.pump();
    expect(find.text(StaticAdvice.forMetrics(metrics)), findsOneWidget);
  });

  testWidgets('tanpa data → tombol nonaktif', (tester) async {
    await pump(tester, _ControlledRepo(), null);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Minta saran'));
    expect(button.onPressed, isNull);
    expect(find.text('Belum ada data untuk dianalisis.'), findsOneWidget);
  });
}
