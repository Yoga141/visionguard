import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/business_constants.dart';
import '../../../core/database/database_providers.dart';
import '../domain/credit_models.dart';

/// Kontrak Kredit & Pembayaran (CreditService, SDD 4.1). Implementasi asli
/// memanggil `GET /credits/status`, `POST /monitoring-days/activate`,
/// `GET /credit-packages`, `GET /orders`, `GET /credits/history` (§11).
abstract class CreditRepository {
  /// UC-18: sisa kuota gratis, saldo, status Hari Pemantauan AI hari ini.
  Future<CreditStatus> status();

  /// §8.2: aktivasi Hari Pemantauan AI hari ini.
  Future<ActivationResult> activateToday();

  /// Paket aktif saja (`is_active = true`, §8.6).
  Future<List<CreditPackage>> packages();

  /// UC-20: riwayat order, terbaru dulu.
  Future<List<CreditOrder>> orders();

  /// UC-20: mutasi kredit (pembelian, pemakaian, penyesuaian), terbaru dulu.
  Future<List<LedgerEntry>> ledger();
}

/// Sumber tanggal "sekarang" (bisa diganti di test).
final creditClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Default: repository tiruan sampai backend Laravel siap.
final creditRepositoryProvider = Provider<CreditRepository>(
    (ref) => FakeCreditRepository.demo(clock: ref.watch(creditClockProvider)));

/// Meniru `MonitoringDayController` & `User::creditBalance()` di server
/// (DOCS_SPEC §8.2, §8.3) dengan data di memori.
///
/// Saldo **selalu** = SUM(delta) ledger, tidak disimpan sebagai satu angka;
/// ledger append-only; satu hari satu aktivasi (UNIQUE(user_id, day)).
class FakeCreditRepository implements CreditRepository {
  FakeCreditRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Riwayat tiruan bulan lalu: 1 pembelian berhasil (+5), 1 order
  /// kedaluwarsa, 3 hari pemantauan (2 gratis, 1 kredit → −1). Saldo awal 4.
  /// Kuota gratis bulan berjalan masih utuh.
  factory FakeCreditRepository.demo({DateTime Function()? clock}) {
    final repo = FakeCreditRepository(clock: clock);
    final now = repo._clock();
    DateTime prev(int day, [int hour = 9]) => DateTime(now.year, now.month - 1, day, hour);
    final hemat = demoPackages[0], reguler = demoPackages[1];

    repo._addOrder(hemat, OrderStatus.settlement, prev(3, 10), paymentType: 'qris');
    repo._addOrder(reguler, OrderStatus.expire, prev(12, 20));
    repo._addLedger(5, LedgerReason.purchase, prev(3, 10), orderId: 1);
    repo._addDay(prev(5), DaySource.free);
    repo._addDay(prev(8), DaySource.free);
    final day = repo._addDay(prev(15), DaySource.credit);
    repo._addLedger(-BusinessConstants.creditsPerDay, LedgerReason.usage, prev(15),
        monitoringDayId: day.id);
    return repo;
  }

  /// Paket contoh (ADM-01 mengelola paket di panel admin).
  static const demoPackages = [
    CreditPackage(id: 1, name: 'Paket Hemat', credits: 5, priceIdr: 15000),
    CreditPackage(id: 2, name: 'Paket Reguler', credits: 12, priceIdr: 30000),
    CreditPackage(id: 3, name: 'Paket Hemat Plus', credits: 30, priceIdr: 65000),
    CreditPackage(id: 4, name: 'Paket Lama', credits: 3, priceIdr: 12000, isActive: false),
  ];

  final DateTime Function() _clock;
  final List<MonitoringDay> _days = [];
  final List<LedgerEntry> _ledger = [];
  final List<CreditOrder> _orders = [];

  /// Jumlah pemanggilan [activateToday] (untuk test).
  int activationCalls = 0;

  int get _balance => _ledger.fold(0, (sum, e) => sum + e.delta);

  /// 5.2.1: tanggal hari ini menurut zona waktu akun (sementara: zona waktu perangkat).
  String get _today => dayKey(_clock());

  int _freeUsedThisMonth() {
    final month = _today.substring(0, 7); // YYYY-MM
    return _days.where((d) => d.source == DaySource.free && d.day.startsWith(month)).length;
  }

  MonitoringDay? _todayRow() {
    final today = _today;
    for (final d in _days) {
      if (d.day == today) return d;
    }
    return null;
  }

  @override
  Future<CreditStatus> status() async {
    final row = _todayRow();
    return CreditStatus(
      today: _today,
      freeQuotaRemaining:
          (BusinessConstants.freeDaysPerMonth - _freeUsedThisMonth()).clamp(0, BusinessConstants.freeDaysPerMonth),
      balance: _balance,
      todayActive: row != null,
      todaySource: row?.source,
      updatedAt: _clock(),
    );
  }

  @override
  Future<ActivationResult> activateToday() async {
    activationCalls++;
    // 5.2.2 Hari ini sudah aktif → kembalikan status, tidak memotong apa pun.
    final existing = _todayRow();
    if (existing != null) {
      return ActivationSuccess(await status(), source: existing.source, alreadyActive: true);
    }
    // 5.2.3 Kuota gratis bulan berjalan.
    if (_freeUsedThisMonth() < BusinessConstants.freeDaysPerMonth) {
      _addDay(_clock(), DaySource.free);
      return ActivationSuccess(await status(), source: DaySource.free, alreadyActive: false);
    }
    // 5.2.4 Saldo kredit ≥ 1 → catat hari + ledger usage −1.
    if (_balance >= BusinessConstants.creditsPerDay) {
      final day = _addDay(_clock(), DaySource.credit);
      _addLedger(-BusinessConstants.creditsPerDay, LedgerReason.usage, _clock(),
          monitoringDayId: day.id);
      return ActivationSuccess(await status(), source: DaySource.credit, alreadyActive: false);
    }
    // 402 kredit tidak cukup.
    return ActivationInsufficient(await status());
  }

  @override
  Future<List<CreditPackage>> packages() async =>
      demoPackages.where((p) => p.isActive).toList();

  @override
  Future<List<CreditOrder>> orders() async => _orders.reversed.toList();

  @override
  Future<List<LedgerEntry>> ledger() async => _ledger.reversed.toList();

  /// Hanya demo/debug: meniru penyesuaian kredit admin (§8.5, reason adjustment).
  void addDemoCredit(int delta, {String note = 'Kredit demo (debug)'}) =>
      _addLedger(delta, LedgerReason.adjustment, _clock(), note: note);

  MonitoringDay _addDay(DateTime at, DaySource source) {
    final day = MonitoringDay(id: _days.length + 1, day: dayKey(at), source: source, activatedAt: at);
    _days.add(day);
    return day;
  }

  void _addLedger(int delta, LedgerReason reason, DateTime at,
      {int? orderId, int? monitoringDayId, String? note}) {
    _ledger.add(LedgerEntry(
      id: _ledger.length + 1,
      delta: delta,
      reason: reason,
      createdAt: at,
      orderId: orderId,
      monitoringDayId: monitoringDayId,
      note: note,
    ));
  }

  void _addOrder(CreditPackage p, OrderStatus status, DateTime at, {String? paymentType}) {
    final id = _orders.length + 1;
    _orders.add(CreditOrder(
      id: id,
      orderCode: 'VG-${at.year}${at.month.toString().padLeft(2, '0')}-${id.toString().padLeft(4, '0')}',
      packageName: p.name,
      credits: p.credits,
      amountIdr: p.priceIdr,
      status: status,
      createdAt: at,
      paymentType: paymentType,
      paidAt: status == OrderStatus.settlement ? at : null,
    ));
  }
}
