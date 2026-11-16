import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../data/ai_advice_repository.dart';
import '../data/api_ai_advice_repository.dart';
import '../data/gemini_service.dart';

/// Sumber Saran AI (DOCS_SPEC §17.3):
/// - Bawaan: backend `POST /ai/advice` (key Gemini hanya di server).
/// - `USE_REMOTE_API=false` + build **debug**: Gemini langsung dengan key dari
///   `--dart-define=GEMINI_API_KEY=...` (khusus pengembangan; tanpa key → saran statis).
/// - `USE_REMOTE_API=false` + build rilis: hanya saran statis.
final aiAdviceRepositoryProvider = Provider<AiAdviceRepository>((ref) {
  if (ApiConstants.useRemoteApi) return ApiAiAdviceRepository(ref.watch(apiClientProvider));
  return DirectGeminiAdviceRepository(isAiEnabled: kDebugMode);
});
