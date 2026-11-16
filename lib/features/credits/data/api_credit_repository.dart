import '../../../core/network/api_client.dart';
import '../domain/credit_models.dart';
import 'credit_repository.dart';

/// Kredit & pembayaran lewat backend Laravel (DOCS_SPEC §8, API_CONTRACT.md).
/// Saldo selalu dari server (SUM ledger, KMN-03); klien tidak menghitungnya.
class ApiCreditRepository implements CreditRepository {
  ApiCreditRepository(this._api, {required Future<int?> Function() deviceId}) : _deviceId = deviceId;

  final ApiClient _api;
  final Future<int?> Function() _deviceId;

  /// `orders()` dan `ledger()` dipanggil bersamaan oleh controller; keduanya
  /// berasal dari satu `GET /credits/history`, jadi request dibagi.
  Future<Map<String, dynamic>>? _history;

  @override
  Future<CreditStatus> status() async => statusFromJson(await _api.get('/credits/status'));

  /// §8.2: 200 → [ActivationSuccess]; 402 → [ActivationInsufficient] dengan
  /// status kredit dari body. Error lain (offline, 401, 5xx) dilempar → pemanggil
  /// beralih ke Mode Timer.
  @override
  Future<ActivationResult> activateToday() async {
    final deviceId = await _deviceId();
    try {
      final res = await _api.post('/monitoring-days/activate', body: {
        if (deviceId != null) 'device_id': deviceId,
      });
      return ActivationSuccess(
        statusFromJson(res),
        source: _source(res['source']) ?? DaySource.free,
        alreadyActive: res['already_active'] == true,
      );
    } on PaymentRequiredException catch (e) {
      final data = e.data;
      return ActivationInsufficient(
          data is Map<String, dynamic> ? statusFromJson(data) : _emptyStatus());
    }
  }

  @override
  Future<List<CreditPackage>> packages() async {
    final res = await _api.get('/credit-packages');
    final list = res['packages'];
    return [
      if (list is List)
        for (final p in list)
          if (p is Map<String, dynamic>) packageFromJson(p),
    ];
  }

  @override
  Future<List<CreditOrder>> orders() async {
    final list = (await _historyOnce())['orders'];
    return [
      if (list is List)
        for (final o in list)
          if (o is Map<String, dynamic>) orderFromJson(o),
    ];
  }

  @override
  Future<List<LedgerEntry>> ledger() async {
    final list = (await _historyOnce())['ledger'];
    return [
      if (list is List)
        for (final e in list)
          if (e is Map<String, dynamic>) ledgerFromJson(e),
    ];
  }

  @override
  Future<CheckoutSession> createOrder(int packageId) async {
    final res = await _api.post('/orders', body: {'package_id': packageId});
    final order = res['order'];
    final redirect = res['redirect_url'];
    if (order is! Map<String, dynamic> || redirect is! String || res['order_code'] is! String) {
      throw const ApiException('Respons server tidak dikenali.');
    }
    return CheckoutSession(
      orderCode: res['order_code'] as String,
      redirectUrl: redirect,
      paymentMode: res['payment_mode'] is String ? res['payment_mode'] as String : 'midtrans',
      order: orderFromJson(order),
    );
  }

  @override
  Future<OrderCheck> orderStatus(String orderCode) async {
    final res = await _api.get('/orders/${Uri.encodeComponent(orderCode)}');
    final order = res['order'];
    if (order is! Map<String, dynamic>) throw const ApiException('Respons server tidak dikenali.');
    return OrderCheck(order: orderFromJson(order), balance: _int(res['credit_balance']));
  }

  Future<Map<String, dynamic>> _historyOnce() =>
      _history ??= _api.get('/credits/history').whenComplete(() => _history = null);

  // ---- Pemetaan JSON (API_CONTRACT.md) ----

  static CreditStatus statusFromJson(Map<String, dynamic> m) => CreditStatus(
        today: m['today'] is String ? m['today'] as String : '',
        freeQuotaRemaining: _int(m['free_quota_remaining']),
        balance: _int(m['credit_balance']),
        todayActive: m['today_active'] == true,
        todaySource: _source(m['today_source']),
        updatedAt: _date(m['updated_at']) ?? DateTime.now(),
      );

  static CreditPackage packageFromJson(Map<String, dynamic> m) => CreditPackage(
        id: _int(m['id']),
        name: '${m['name'] ?? ''}',
        credits: _int(m['credits']),
        priceIdr: _int(m['price_idr']),
        isActive: m['is_active'] != false,
      );

  static CreditOrder orderFromJson(Map<String, dynamic> m) => CreditOrder(
        id: _int(m['id']),
        orderCode: '${m['order_code'] ?? ''}',
        packageName: '${m['package_name'] ?? 'Paket kredit'}',
        credits: _int(m['credits']),
        amountIdr: _int(m['amount_idr']),
        status: OrderStatus.values.asNameMap()[m['status']] ?? OrderStatus.pending,
        createdAt: _date(m['created_at']) ?? DateTime.now(),
        paymentType: m['payment_type'] is String ? m['payment_type'] as String : null,
        paidAt: _date(m['paid_at']),
      );

  static LedgerEntry ledgerFromJson(Map<String, dynamic> m) => LedgerEntry(
        id: _int(m['id']),
        delta: _int(m['delta']),
        reason: LedgerReason.values.asNameMap()[m['reason']] ?? LedgerReason.adjustment,
        createdAt: _date(m['created_at']) ?? DateTime.now(),
        orderId: m['order_id'] is int ? m['order_id'] as int : null,
        monitoringDayId: m['monitoring_day_id'] is int ? m['monitoring_day_id'] as int : null,
        note: m['note'] is String ? m['note'] as String : null,
      );

  static CreditStatus _emptyStatus() => CreditStatus(
        today: '',
        freeQuotaRemaining: 0,
        balance: 0,
        todayActive: false,
        updatedAt: DateTime.now(),
      );

  static int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static DaySource? _source(Object? v) => v is String ? DaySource.values.asNameMap()[v] : null;

  /// Waktu server ISO 8601 UTC → waktu lokal untuk ditampilkan.
  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
}
