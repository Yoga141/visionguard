import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Service asisten AI berbasis Gemini untuk memberikan saran kesehatan mata.
///
/// Menerima data skor kelelahan dan metrik terkait, mengirimkannya ke Gemini,
/// lalu mengembalikan teks saran yang bisa langsung ditampilkan di UI.
///
/// API Key diambil otomatis dari file `.env` (key: `GEMINI_API_KEY`).
/// Bisa juga di-override secara manual lewat parameter constructor.
///
/// Contoh penggunaan:
/// ```dart
/// // Otomatis dari .env:
/// final gemini = GeminiService();
///
/// // Atau manual:
/// final gemini = GeminiService(apiKey: 'YOUR_API_KEY');
///
/// final saran = await gemini.getHealthAdvice(fatigueScore: 75.0);
/// print(saran); // "Istirahatkan mata Anda selama 10 menit..."
/// ```
class GeminiService {
  GeminiService({
    String? apiKey,
    this.isAiEnabled = true,
    String? modelName,
  })  : _apiKey = apiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '',
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

  /// Meminta saran kesehatan mata berdasarkan data kelelahan pengguna.
  ///
  /// Parameter:
  /// - [fatigueScore] : skor kelelahan (0–100, makin tinggi makin lelah).
  /// - [blinkRate]    : jumlah kedipan per menit (opsional).
  /// - [perclos]      : persentase waktu mata tertutup (opsional).
  /// - [screenMinutes]: durasi menatap layar dalam menit (opsional).
  /// - [distanceCm]   : jarak mata ke layar dalam cm (opsional).
  ///
  /// Mengembalikan teks saran kesehatan.
  /// Jika [isAiEnabled] == false, mengembalikan pesan fallback statis.
  Future<String> getHealthAdvice({
    required double fatigueScore,
    double? blinkRate,
    double? perclos,
    double? screenMinutes,
    double? distanceCm,
  }) async {
    // ---------- Feature Flag ----------
    if (!isAiEnabled) {
      return _fallbackAdvice(fatigueScore);
    }

    // ---------- Bangun prompt dengan data metrik ----------
    final buffer = StringBuffer()
      ..writeln('Berikut data kondisi mata pengguna saat ini:')
      ..writeln('- Skor kelelahan: ${fatigueScore.toStringAsFixed(1)} / 100');

    if (blinkRate != null) {
      buffer.writeln('- Frekuensi kedipan: ${blinkRate.toStringAsFixed(1)} kali/menit');
    }
    if (perclos != null) {
      buffer.writeln('- PERCLOS: ${(perclos * 100).toStringAsFixed(1)}%');
    }
    if (screenMinutes != null) {
      buffer.writeln('- Durasi menatap layar: ${screenMinutes.toStringAsFixed(0)} menit');
    }
    if (distanceCm != null) {
      buffer.writeln('- Jarak ke layar: ${distanceCm.toStringAsFixed(0)} cm');
    }

    buffer.writeln();
    buffer.writeln(
      'Berdasarkan data di atas, berikan 2–3 saran singkat dan praktis '
      'untuk menjaga kesehatan mata pengguna. Gunakan bahasa yang ramah dan mudah dipahami.',
    );

    try {
      final response = await _generativeModel.generateContent([
        Content.text(buffer.toString()),
      ]);

      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        return _fallbackAdvice(fatigueScore);
      }
      return text.trim();
    } catch (e) {
      // Jika API gagal (jaringan, kuota habis, dsb.), kembalikan saran statis
      // agar UX tetap berjalan.
      return _fallbackAdvice(fatigueScore);
    }
  }

  /// Saran statis sebagai fallback saat AI dinonaktifkan atau API gagal.
  static String _fallbackAdvice(double fatigueScore) {
    if (fatigueScore >= 75) {
      return '⚠️ Tingkat kelelahan mata Anda tinggi!\n'
          '• Istirahatkan mata selama 10–15 menit.\n'
          '• Terapkan aturan 20-20-20: setiap 20 menit, lihat objek sejauh 6 meter selama 20 detik.\n'
          '• Pertimbangkan untuk berhenti bekerja di depan layar sementara waktu.';
    } else if (fatigueScore >= 50) {
      return '🟡 Mata Anda mulai menunjukkan tanda-tanda kelelahan.\n'
          '• Kedipkan mata secara sadar beberapa kali.\n'
          '• Pastikan jarak mata ke layar minimal 50 cm.\n'
          '• Lakukan peregangan mata: lihat ke kiri, kanan, atas, dan bawah.';
    } else {
      return '✅ Kondisi mata Anda masih baik.\n'
          '• Tetap jaga jarak aman ke layar.\n'
          '• Ingat untuk berkedip secara teratur.\n'
          '• Atur kecerahan layar agar nyaman di mata.';
    }
  }
}
