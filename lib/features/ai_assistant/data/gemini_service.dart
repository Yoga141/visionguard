import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../cv_engine/fatigue_scorer.dart';
import 'ai_advice_repository.dart';

/// Saran AI dengan memanggil Gemini **langsung dari klien**.
///
/// ⚠️ **KHUSUS PENGEMBANGAN.** API key dibaca dari `.env` (`GEMINI_API_KEY`)
/// yang ikut ter-bundle di aplikasi, sehingga dapat diekstrak dari build.
/// Versi final **wajib** lewat backend (`ApiAiAdviceRepository`,
/// POST /ai/advice) agar key hanya ada di server (DOCS_SPEC §17).
///
/// Yang dikirim hanya [AdviceMetrics] (angka ringkasan), tanpa frame/gambar.
class DirectGeminiAdviceRepository implements AiAdviceRepository {
  DirectGeminiAdviceRepository({
    String? apiKey,
    this.isAiEnabled = true,
    String? modelName,
  })  : _apiKey = apiKey ?? dotenv.maybeGet('GEMINI_API_KEY') ?? '',
        _modelName = modelName ?? 'gemini-2.0-flash';

  final String _apiKey;
  final String _modelName;

  /// **Feature Flag** — saklar untuk mengaktifkan/menonaktifkan panggilan
  /// API Gemini. Set ke `false` untuk menonaktifkan fitur AI tanpa perlu
  /// mengubah kode lainnya (misalnya saat maintenance atau hemat kuota).
  bool isAiEnabled;

  GenerativeModel? _model;

  /// Lazy-init model agar tidak membuat koneksi sebelum diperlukan.
  GenerativeModel get _generativeModel {
    _model ??= GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 512,
      ),
      systemInstruction: Content.system(
        'Kamu adalah asisten kesehatan mata bernama VisionGuard AI. '
        'Tugasmu memberi saran singkat, praktis, dan ramah dalam Bahasa Indonesia '
        'untuk menjaga kesehatan mata pengguna saat bekerja di depan layar. '
        'Jangan memberi diagnosis medis, cukup saran umum pencegahan kelelahan mata digital.',
      ),
    );
    return _model!;
  }

  /// Prompt hanya berisi angka ringkasan dari [metrics].
  static String buildPrompt(AdviceMetrics metrics) {
    final buffer = StringBuffer()
      ..writeln('Berikut data kondisi mata pengguna saat ini:')
      ..writeln('- Skor kelelahan: ${metrics.fatigueScore} / 100 (${metrics.level.label})');

    if (metrics.blinkRate != null) {
      buffer.writeln('- Frekuensi kedipan: ${metrics.blinkRate!.toStringAsFixed(1)} kali/menit');
    }
    if (metrics.perclos != null) {
      buffer.writeln('- PERCLOS: ${(metrics.perclos! * 100).toStringAsFixed(1)}%');
    }
    if (metrics.screenMinutes != null) {
      buffer.writeln('- Durasi menatap layar: ${metrics.screenMinutes} menit');
    }
    if (metrics.distanceCm != null) {
      buffer.writeln('- Jarak ke layar: ${metrics.distanceCm!.toStringAsFixed(0)} cm');
    }

    buffer.writeln();
    buffer.writeln(
      'Berdasarkan data di atas, berikan 2–3 saran singkat dan praktis '
      'untuk menjaga kesehatan mata pengguna. Gunakan bahasa yang ramah dan mudah dipahami.',
    );
    return buffer.toString();
  }

  @override
  Future<String> getAdvice(AdviceMetrics metrics) async {
    // ---------- Feature Flag ----------
    if (!isAiEnabled || _apiKey.isEmpty) {
      return StaticAdvice.forMetrics(metrics);
    }

    try {
      final response = await _generativeModel.generateContent([
        Content.text(buildPrompt(metrics)),
      ]);

      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        return StaticAdvice.forMetrics(metrics);
      }
      return text.trim();
    } catch (e) {
      // Jika API gagal (jaringan, kuota habis, dsb.), kembalikan saran statis
      // agar UX tetap berjalan.
      return StaticAdvice.forMetrics(metrics);
    }
  }
}
