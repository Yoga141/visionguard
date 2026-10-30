import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import 'api_exception.dart';
import 'token_storage.dart';

export 'api_exception.dart';

/// Klien REST JSON ke backend Laravel + Sanctum (DOCS_SPEC §4.3, §11).
///
/// - Setiap request membawa header `Authorization: Bearer <token>` jika token
///   tersimpan di [TokenStorage].
/// - Error HTTP dipetakan ke subclass [ApiException] yang jelas.
/// - Hanya untuk data akun/angka. Frame kamera **tidak boleh** dikirim lewat sini.
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    String baseUrl = ApiConstants.baseUrl,
    Dio? dio,
  })  : _tokenStorage = tokenStorage,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = ApiConstants.connectTimeout
      ..receiveTimeout = ApiConstants.receiveTimeout
      ..responseType = ResponseType.json
      ..headers.addAll({
        Headers.acceptHeader: Headers.jsonContentType,
        Headers.contentTypeHeader: Headers.jsonContentType,
      });
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _attachToken));
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;

  TokenStorage get tokenStorage => _tokenStorage;

  Future<void> _attachToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.read();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<Object?>(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _send(() => _dio.post<Object?>(path, data: body));

  Future<Map<String, dynamic>> delete(String path, {Object? body}) =>
      _send(() => _dio.delete<Object?>(path, data: body));

  Future<Map<String, dynamic>> _send(Future<Response<Object?>> Function() request) async {
    try {
      final res = await request();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{'data': data};
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Menerjemahkan [DioException] menjadi [ApiException].
  static ApiException mapDioException(DioException e) {
    final res = e.response;
    if (res == null) {
      return switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          const NetworkException('Koneksi ke server habis waktu. Coba lagi.'),
        DioExceptionType.badCertificate =>
          const NetworkException('Sertifikat server tidak valid.'),
        _ => const NetworkException('Tidak dapat terhubung ke server. Periksa koneksi internet.'),
      };
    }

    final data = res.data;
    final serverMessage =
        (data is Map && data['message'] is String) ? data['message'] as String : null;

    switch (res.statusCode) {
      case 401:
        return UnauthorizedException(
            serverMessage ?? 'Sesi berakhir atau kredensial salah.', data: data);
      case 402:
        return PaymentRequiredException(serverMessage ?? 'Kredit tidak cukup.', data: data);
      case 403:
        return ForbiddenException(serverMessage ?? 'Verifikasi gagal.', data: data);
      case 404:
        return NotFoundException(serverMessage ?? 'Data tidak ditemukan.', data: data);
      case 422:
        return ValidationException(
          serverMessage ?? 'Data yang dikirim tidak valid.',
          errors: _parseErrors(data),
          data: data,
        );
      default:
        return ApiException(
          serverMessage ?? 'Terjadi kesalahan server (${res.statusCode}).',
          statusCode: res.statusCode,
          data: data,
        );
    }
  }

  /// Format error validasi Laravel: `{"errors": {"email": ["..."]}}`.
  static Map<String, List<String>> _parseErrors(Object? data) {
    if (data is! Map || data['errors'] is! Map) return const {};
    return (data['errors'] as Map).map(
      (k, v) => MapEntry(k.toString(), v is List ? v.map((e) => e.toString()).toList() : [v.toString()]),
    );
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(tokenStorage: ref.watch(tokenStorageProvider)),
);
