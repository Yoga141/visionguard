import '../../../core/network/api_client.dart';
import 'ai_advice_repository.dart';

/// Saran AI lewat backend Laravel: POST /ai/advice (DOCS_SPEC §8.9, §11.2).
///
/// Ini jalur **final**: API key Gemini hanya disimpan di server, klien cukup
/// mengirim angka ringkasan dengan token Sanctum.
///
/// Bawaan aplikasi (`ApiConstants.useRemoteApi == true`).
class ApiAiAdviceRepository implements AiAdviceRepository {
  ApiAiAdviceRepository(this._api);

  final ApiClient _api;

  @override
  Future<String> getAdvice(AdviceMetrics metrics) async {
    try {
      final res = await _api.post('/ai/advice', body: metrics.toJson());
      final advice = res['advice'];
      if (advice is String && advice.trim().isNotEmpty) return advice.trim();
    } on ApiException {
      // Offline, 401, 429 (batas pemakaian), 5xx → saran statis.
    }
    return StaticAdvice.forMetrics(metrics);
  }
}
