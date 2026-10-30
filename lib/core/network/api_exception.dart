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
