import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../data/ai_advice_repository.dart';
import '../data/api_ai_advice_repository.dart';
import '../data/gemini_service.dart';

/// Sumber Saran AI. Default: Gemini langsung (pengembangan). Dengan
/// `--dart-define=USE_REMOTE_API=true` beralih ke backend POST /ai/advice.
final aiAdviceRepositoryProvider = Provider<AiAdviceRepository>(
  (ref) => ApiConstants.useRemoteApi
      ? ApiAiAdviceRepository(ref.watch(apiClientProvider))
      : DirectGeminiAdviceRepository(),
);
