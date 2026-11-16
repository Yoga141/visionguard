/// Exception hasil pemetaan respons REST API Laravel (DOCS_SPEC §11).
///
/// Lapisan repository menerjemahkan exception ini menjadi exception domain
/// (mis. `AuthException`) sebelum sampai ke UI.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.data});

  final String message;

  /// Kode HTTP; `null` jika request tidak sampai ke server.
  final int? statusCode;

  /// Body respons (JSON yang sudah di-decode), jika ada.
  final Object? data;

  @override
  String toString() => message;
}

/// 401 — token tidak ada/kedaluwarsa, atau kredensial login salah.
class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message, {super.data}) : super(statusCode: 401);
}

/// 402 — kredit tidak cukup untuk aktivasi Hari Pemantauan AI (§8.2).
class PaymentRequiredException extends ApiException {
  const PaymentRequiredException(super.message, {super.data}) : super(statusCode: 402);
}

/// 403 — verifikasi gagal (mis. kata sandi salah saat hapus akun, UC-05).
class ForbiddenException extends ApiException {
  const ForbiddenException(super.message, {super.data}) : super(statusCode: 403);
}

/// 404 — sumber tidak ditemukan (mis. email tidak terdaftar saat reset sandi).
class NotFoundException extends ApiException {
  const NotFoundException(super.message, {super.data}) : super(statusCode: 404);
}

/// 422 — validasi Laravel gagal. [errors] berformat `{field: [pesan, ...]}`.
class ValidationException extends ApiException {
  const ValidationException(super.message, {this.errors = const {}, super.data})
      : super(statusCode: 422);

  final Map<String, List<String>> errors;

  /// Pesan pertama untuk [field], atau `null` jika tidak ada.
  String? firstError(String field) {
    final list = errors[field];
    return (list == null || list.isEmpty) ? null : list.first;
  }
}

/// Tidak ada koneksi, timeout, atau sertifikat TLS ditolak.
class NetworkException extends ApiException {
  const NetworkException(super.message);
}

/// Pesan ramah untuk ditampilkan ke pengguna (Tahap C, poin 8).
///
/// Pesan server dipakai bila sudah jelas & berbahasa Indonesia (402, 403,
/// 422, 429); kode lain memakai pesan baku agar teks bawaan Laravel
/// (mis. "Unauthenticated.") tidak sampai ke pengguna.
String friendlyErrorMessage(Object error) {
  if (error is ValidationException) {
    for (final list in error.errors.values) {
      if (list.isNotEmpty) return list.first;
    }
    return 'Data yang dikirim belum benar. Periksa kembali isian Anda.';
  }
  if (error is NetworkException) return error.message;
  if (error is! ApiException) return 'Terjadi kesalahan tak terduga. Coba lagi.';

  String serverOr(String fallback) {
    final m = error.message.trim();
    final looksDefault = m.isEmpty || m.endsWith('.') && !m.contains(' ') || m == 'Unauthenticated.';
    return looksDefault ? fallback : m;
  }

  return switch (error.statusCode) {
    401 => 'Sesi Anda berakhir. Silakan masuk lagi.',
    402 => serverOr('Kredit tidak cukup. Beli kredit atau gunakan Mode Timer.'),
    403 => serverOr('Akses ditolak.'),
    404 => 'Data tidak ditemukan.',
    429 => serverOr('Terlalu banyak permintaan. Coba lagi sebentar lagi.'),
    503 => serverOr('Layanan sedang tidak tersedia. Coba lagi nanti.'),
    final int code when code >= 500 => 'Server sedang bermasalah. Coba lagi nanti.',
    _ => serverOr('Terjadi kesalahan. Coba lagi.'),
  };
}

/// 429 — dibatasi (login ditahan, lupa sandi terlalu sering, batas Saran AI).
bool isTooManyRequests(Object e) => e is ApiException && e.statusCode == 429;
