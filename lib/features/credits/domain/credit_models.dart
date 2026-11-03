/// Model data Kredit & Pembayaran (DOCS_SPEC §8, §12.2). Struktur mengikuti
/// tabel server `monitoring_days`, `credit_ledger`, `orders`, `credit_packages`.
library;

/// `monitoring_days.source`.
enum DaySource { free, credit }

/// `credit_ledger.reason`.
enum LedgerReason { purchase, usage, adjustment }

/// `orders.status` (§8.4).
enum OrderStatus { pending, settlement, expire, cancel, deny }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'Menunggu pembayaran',
        OrderStatus.settlement => 'Berhasil',
        OrderStatus.expire => 'Kedaluwarsa',
        OrderStatus.cancel => 'Dibatalkan',
        OrderStatus.deny => 'Ditolak',
      };
}

/// D9 Paket Kredit (`credit_packages`).
class CreditPackage {
  const CreditPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceIdr,
    this.isActive = true,
  });

  final int id;
  final String name;
  final int credits;
  final int priceIdr;
  final bool isActive;
}

/// D6 Hari Pemantauan (`monitoring_days`).
class MonitoringDay {
  const MonitoringDay({
    required this.id,
    required this.day,
    required this.source,
    required this.activatedAt,
  });

  final int id;

  /// Kunci hari `YYYY-MM-DD` menurut zona waktu akun.
  final String day;
  final DaySource source;
  final DateTime activatedAt;
}

/// D7 Ledger Kredit (`credit_ledger`, append-only).
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.delta,
    required this.reason,
    required this.createdAt,
    this.orderId,
    this.monitoringDayId,
    this.note,
  });

  final int id;
  final int delta;
  final LedgerReason reason;
  final DateTime createdAt;
  final int? orderId;
  final int? monitoringDayId;
  final String? note;
}

/// D8 Order (`orders`).
class CreditOrder {
  const CreditOrder({
    required this.id,
    required this.orderCode,
    required this.packageName,
    required this.credits,
    required this.amountIdr,
    required this.status,
    required this.createdAt,
    this.paymentType,
    this.paidAt,
  });

  final int id;
  final String orderCode;
  final String packageName;
  final int credits;
  final int amountIdr;
  final OrderStatus status;
  final DateTime createdAt;
  final String? paymentType;
  final DateTime? paidAt;
}

/// Respons `GET /credits/status` (KRD-01, UC-18).
class CreditStatus {
  const CreditStatus({
    required this.today,
    required this.freeQuotaRemaining,
    required this.balance,
    required this.todayActive,
    required this.updatedAt,
    this.todaySource,
  });

  final String today;
  final int freeQuotaRemaining;

  /// Saldo = SUM(delta) ledger, dihitung di server (§8.3, KMN-03).
  final int balance;
  final bool todayActive;
  final DaySource? todaySource;

  /// Waktu data terakhir diperbarui (alur offline UC-18).
  final DateTime updatedAt;
}

/// Hasil `POST /monitoring-days/activate` (§8.2).
sealed class ActivationResult {
  const ActivationResult(this.status);
  final CreditStatus status;
}

/// 200 OK: hari aktif. [alreadyActive] = true bila hari ini sudah aktif
/// sebelumnya (tidak memotong apa pun).
class ActivationSuccess extends ActivationResult {
  const ActivationSuccess(super.status, {required this.source, required this.alreadyActive});
  final DaySource source;
  final bool alreadyActive;
}

/// 402: kuota gratis & kredit habis → tawarkan beli kredit atau Mode Timer.
class ActivationInsufficient extends ActivationResult {
  const ActivationInsufficient(super.status);
}
