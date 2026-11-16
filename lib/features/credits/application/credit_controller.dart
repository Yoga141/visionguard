import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
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
    this.pendingOrder,
    this.checkingOrder = false,
    this.buyingPackageId,
  });

  /// Status terakhir yang berhasil dimuat (tetap ditampilkan saat offline).
  final CreditStatus? status;
  final List<CreditPackage> packages;
  final List<CreditOrder> orders;
  final List<LedgerEntry> ledger;
  final bool loading;
  final String? error;

  /// Order yang baru dibeli dan menunggu pembayaran (UC-19, notifikasi Midtrans).
  final CreditOrder? pendingOrder;

  /// Sedang "Muat ulang status" order.
  final bool checkingOrder;

  /// Paket yang sedang dibuatkan order (tombol Beli menampilkan progres).
  final int? buyingPackageId;

  CreditState copyWith({
    CreditStatus? status,
    List<CreditPackage>? packages,
    List<CreditOrder>? orders,
    List<LedgerEntry>? ledger,
    bool? loading,
    String? error,
    bool clearError = false,
    CreditOrder? pendingOrder,
    bool clearPendingOrder = false,
    bool? checkingOrder,
    int? buyingPackageId,
    bool clearBuying = false,
  }) =>
      CreditState(
        status: status ?? this.status,
        packages: packages ?? this.packages,
        orders: orders ?? this.orders,
        ledger: ledger ?? this.ledger,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        pendingOrder: clearPendingOrder ? null : (pendingOrder ?? this.pendingOrder),
        checkingOrder: checkingOrder ?? this.checkingOrder,
        buyingPackageId: clearBuying ? null : (buyingPackageId ?? this.buyingPackageId),
      );
}

/// Membuka halaman pembayaran di browser (bisa diganti di test).
typedef UrlOpener = Future<bool> Function(Uri uri);

final urlOpenerProvider = Provider<UrlOpener>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Hasil aksi pembayaran untuk ditampilkan sebagai pesan.
typedef PaymentFeedback = ({bool ok, String message});

final creditControllerProvider =
    NotifierProvider<CreditController, CreditState>(CreditController.new);

/// CreditService (SDD 4.1): status kredit, aktivasi hari, paket, riwayat,
/// dan pembelian. Logika aturan (§8.2) & saldo ada di server, bukan di sini.
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
      final orders = results[2] as List<CreditOrder>;
      _set(state.copyWith(
        status: results[0] as CreditStatus,
        packages: results[1] as List<CreditPackage>,
        orders: orders,
        ledger: results[3] as List<LedgerEntry>,
        loading: false,
        clearError: true,
        // Order pending yang dibuka sebelumnya ikut diperbarui statusnya.
        pendingOrder: _matching(orders, state.pendingOrder),
      ));
    } catch (e) {
      // Offline → data terakhir + waktu pembaruan (alur alternatif UC-18).
      _set(state.copyWith(loading: false, error: _loadError(e)));
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

  /// UC-19: `POST /orders` → buka `redirect_url` Snap di browser. Setelah
  /// kembali ke aplikasi, order tampil "Menunggu pembayaran" sampai pengguna
  /// menekan "Muat ulang status" (kredit hanya bertambah dari notifikasi server).
  Future<PaymentFeedback> buy(CreditPackage package) async {
    if (state.buyingPackageId != null) return (ok: false, message: 'Order sedang dibuat.');
    _set(state.copyWith(buyingPackageId: package.id));
    final CheckoutSession checkout;
    try {
      checkout = await _repo.createOrder(package.id);
    } catch (e) {
      _set(state.copyWith(clearBuying: true));
      return (ok: false, message: _orderError(e));
    }
    _set(state.copyWith(
      clearBuying: true,
      pendingOrder: checkout.order,
      orders: [checkout.order, ...state.orders.where((o) => o.orderCode != checkout.orderCode)],
    ));

    if (checkout.redirectUrl.isEmpty) {
      return (ok: true, message: 'Order ${checkout.orderCode} dibuat (mode tiruan, tanpa halaman bayar).');
    }
    final opened = await openPaymentPage(checkout.redirectUrl);
    return opened
        ? (ok: true, message: 'Selesaikan pembayaran di browser, lalu kembali dan tekan "Muat ulang status".')
        : (ok: false, message: 'Halaman pembayaran tidak dapat dibuka. Coba "Buka halaman bayar" lagi.');
  }

  /// Simpan URL terakhir agar bisa dibuka lagi dari kartu order pending.
  String? _lastRedirectUrl;
  String? get lastRedirectUrl => _lastRedirectUrl;

  Future<bool> openPaymentPage([String? url]) async {
    final target = url ?? _lastRedirectUrl;
    if (target == null || target.isEmpty) return false;
    _lastRedirectUrl = target;
    final uri = Uri.tryParse(target);
    if (uri == null) return false;
    try {
      return await ref.read(urlOpenerProvider)(uri);
    } catch (e) {
      debugPrint('CreditController: gagal membuka halaman bayar (${e.runtimeType}).');
      return false;
    }
  }

  /// "Muat ulang status": `GET /orders/{code}` lalu `GET /credits/status`
  /// (+ riwayat). Order final → kartu pending ditutup dengan pesan.
  Future<PaymentFeedback> reloadOrderStatus() async {
    final pending = state.pendingOrder;
    if (pending == null) {
      await refresh();
      return (ok: true, message: 'Status kredit diperbarui.');
    }
    _set(state.copyWith(checkingOrder: true));
    try {
      final check = await _repo.orderStatus(pending.orderCode);
      await refresh();
      final order = check.order;
      final message = switch (order.status) {
        OrderStatus.settlement =>
          'Pembayaran berhasil. ${order.credits} kredit ditambahkan (saldo ${check.balance}).',
        OrderStatus.pending => 'Masih menunggu pembayaran. Selesaikan di halaman Midtrans lalu muat ulang lagi.',
        _ => 'Pembayaran ${order.status.label.toLowerCase()}. Saldo tidak berubah.',
      };
      // Saldo & riwayat sudah dimuat ulang oleh refresh() di atas.
      final stillPending = order.status == OrderStatus.pending;
      _set(state.copyWith(
        checkingOrder: false,
        pendingOrder: stillPending ? order : null,
        clearPendingOrder: !stillPending,
      ));
      return (ok: true, message: message);
    } catch (e) {
      _set(state.copyWith(checkingOrder: false));
      return (ok: false, message: friendlyErrorMessage(e));
    }
  }

  /// Tutup kartu order pending (order tetap ada di riwayat).
  void dismissPendingOrder() => _set(state.copyWith(clearPendingOrder: true));

  /// Hanya demo/debug dengan repository tiruan.
  bool get canAddDemoCredit => _repo is FakeCreditRepository;

  Future<void> addDemoCredit() async {
    final repo = _repo;
    if (repo is! FakeCreditRepository) return;
    repo.addDemoCredit(1);
    await refresh();
  }

  static CreditOrder? _matching(List<CreditOrder> orders, CreditOrder? current) {
    if (current == null) return null;
    for (final o in orders) {
      if (o.orderCode == current.orderCode) return o;
    }
    return current;
  }

  static String _loadError(Object e) {
    if (e is NetworkException) return 'Gagal memuat data kredit. Periksa koneksi.';
    if (e is ApiException) return friendlyErrorMessage(e);
    return 'Gagal memuat data kredit. Periksa koneksi.';
  }

  static String _orderError(Object e) {
    if (e is ValidationException) return e.firstError('package_id') ?? friendlyErrorMessage(e);
    if (e is ApiException && e.statusCode == 503) {
      return 'Pembayaran sedang tidak tersedia. Coba lagi nanti.';
    }
    if (e is ApiException) return friendlyErrorMessage(e);
    if (e is StateError) return e.message;
    return 'Gagal membuat order. Coba lagi.';
  }
}
