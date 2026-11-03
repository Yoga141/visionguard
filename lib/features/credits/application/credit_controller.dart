import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/credit_repository.dart';
import '../domain/credit_models.dart';

@immutable
class CreditState {
  const CreditState({
    this.status,
    this.packages = const [],
    this.orders = const [],
    this.ledger = const [],
    this.loading = false,
    this.error,
  });

  /// Status terakhir yang berhasil dimuat (tetap ditampilkan saat offline).
  final CreditStatus? status;
  final List<CreditPackage> packages;
  final List<CreditOrder> orders;
  final List<LedgerEntry> ledger;
  final bool loading;
  final String? error;

  CreditState copyWith({
    CreditStatus? status,
    List<CreditPackage>? packages,
    List<CreditOrder>? orders,
    List<LedgerEntry>? ledger,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      CreditState(
        status: status ?? this.status,
        packages: packages ?? this.packages,
        orders: orders ?? this.orders,
        ledger: ledger ?? this.ledger,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

final creditControllerProvider =
    NotifierProvider<CreditController, CreditState>(CreditController.new);

/// CreditService (SDD 4.1): status kredit, aktivasi hari, paket, riwayat.
/// Logika aturan (§8.2) ada di repository (server), bukan di sini.
class CreditController extends Notifier<CreditState> {
  CreditRepository get _repo => ref.read(creditRepositoryProvider);

  bool _disposed = false;

  /// Hasil async yang tiba setelah provider dibuang diabaikan.
  void _set(CreditState s) {
    if (!_disposed) state = s;
  }

  @override
  CreditState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    // Muat status awal tanpa memblokir build.
    Future.microtask(refresh);
    return const CreditState(loading: true);
  }

  /// UC-18 & UC-20: memuat status, paket, dan riwayat.
  Future<void> refresh() async {
    if (_disposed) return;
    _set(state.copyWith(loading: true, clearError: true));
    try {
      final results = await Future.wait<Object>([
        _repo.status(),
        _repo.packages(),
        _repo.orders(),
        _repo.ledger(),
      ]);
      _set(CreditState(
        status: results[0] as CreditStatus,
        packages: results[1] as List<CreditPackage>,
        orders: results[2] as List<CreditOrder>,
        ledger: results[3] as List<LedgerEntry>,
      ));
    } catch (e) {
      // Offline → data terakhir + waktu pembaruan (alur alternatif UC-18).
      _set(state.copyWith(loading: false, error: 'Gagal memuat data kredit. Periksa koneksi.'));
    }
  }

  /// §8.2 lewat repository. Melempar error bila server tidak terjangkau
  /// (pemanggil beralih ke Mode Timer).
  Future<ActivationResult> activateToday() async {
    final result = await _repo.activateToday();
    _set(state.copyWith(status: result.status, clearError: true));
    // Riwayat pemakaian ikut berubah bila kredit terpotong.
    if (result is ActivationSuccess && !result.alreadyActive) {
      _repo.ledger().then((l) => _set(state.copyWith(ledger: l)), onError: (_) {});
    }
    return result;
  }

  /// Hanya demo/debug dengan repository tiruan.
  bool get canAddDemoCredit => _repo is FakeCreditRepository;

  Future<void> addDemoCredit() async {
    final repo = _repo;
    if (repo is! FakeCreditRepository) return;
    repo.addDemoCredit(1);
    await refresh();
  }
}
