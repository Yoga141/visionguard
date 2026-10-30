import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionguard/cv_engine/fatigue_scorer.dart';
import 'package:visionguard/features/ai_assistant/data/ai_advice_repository.dart';
import 'package:visionguard/features/ai_assistant/data/api_ai_advice_repository.dart';
import 'package:visionguard/features/ai_assistant/data/gemini_service.dart';

import 'network_test.dart' show fakeClient;

void main() {
  const metrics = AdviceMetrics(
    fatigueScore: 45,
    blinkRate: 9.5,
    perclos: 0.08,
    distanceCm: 42,
    screenMinutes: 35,
  );

  group('AdviceMetrics', () {
    test('level mengikuti §9.4 (0–39 / 40–59 / 60–100)', () {
      expect(const AdviceMetrics(fatigueScore: 39).level, FatigueLevel.normal);
      expect(const AdviceMetrics(fatigueScore: 40).level, FatigueLevel.waspada);
      expect(const AdviceMetrics(fatigueScore: 59).level, FatigueLevel.waspada);
      expect(const AdviceMetrics(fatigueScore: 60).level, FatigueLevel.lelah);
    });

    test('JSON hanya berisi angka ringkasan', () {
      final json = metrics.toJson();
      expect(json.keys, unorderedEquals(
          ['fatigue_score', 'blink_rate', 'perclos', 'distance_cm', 'screen_minutes']));
      expect(json.values.every((v) => v == null || v is num), isTrue);
      expect(json['fatigue_score'], isA<int>());
    });
  });

  group('StaticAdvice', () {
    test('jarak minimum dari CvConstants: desktop 50 cm, mobile 30 cm', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(StaticAdvice.forMetrics(metrics), contains('minimal 50 cm'));
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(StaticAdvice.forMetrics(metrics), contains('minimal 30 cm'));
      debugDefaultTargetPlatformOverride = null;
    });

    test('skor 60 sudah dianggap lelah (bukan 75)', () {
      expect(StaticAdvice.forMetrics(const AdviceMetrics(fatigueScore: 60)), contains('tinggi'));
    });
  });

  group('DirectGeminiAdviceRepository', () {
    test('prompt memuat skor int dan metrik, tanpa data gambar', () {
      final prompt = DirectGeminiAdviceRepository.buildPrompt(metrics);
      expect(prompt, contains('Skor kelelahan: 45 / 100 (Waspada)'));
      expect(prompt, contains('9.5 kali/menit'));
      expect(prompt, contains('8.0%'));
      expect(prompt, contains('42 cm'));
      expect(prompt, contains('35 menit'));
    });

    test('tanpa API key → saran statis, tanpa panggilan jaringan', () async {
      final repo = DirectGeminiAdviceRepository(apiKey: '');
      expect(await repo.getAdvice(metrics), StaticAdvice.forMetrics(metrics));
    });

    test('feature flag mati → saran statis', () async {
      final repo = DirectGeminiAdviceRepository(apiKey: 'x', isAiEnabled: false);
      expect(await repo.getAdvice(metrics), StaticAdvice.forMetrics(metrics));
    });
  });

  group('ApiAiAdviceRepository', () {
    test('POST /ai/advice dan mengembalikan teks saran', () async {
      final c = fakeClient(200, {'advice': '  Istirahat sebentar.  '});
      final advice = await ApiAiAdviceRepository(c.api).getAdvice(metrics);
      expect(advice, 'Istirahat sebentar.');
      expect(c.adapter.last!.path, '/ai/advice');
      expect((c.adapter.last!.data as Map)['fatigue_score'], 45);
    });

    test('server gagal → saran statis', () async {
      final c = fakeClient(500, {'message': 'error'});
      expect(await ApiAiAdviceRepository(c.api).getAdvice(metrics),
          StaticAdvice.forMetrics(metrics));
    });
  });
}
