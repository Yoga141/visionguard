import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/business_constants.dart';
import '../application/credit_controller.dart';
import '../domain/credit_models.dart';

/// S-09 Kredit & Pembayaran: kuota gratis, saldo, status hari ini (KRD-01,
/// UC-18), paket kredit (UC-19), riwayat transaksi & pemakaian (KRD-04, UC-20).
/// Data dari repository tiruan sampai backend Laravel siap.
class CreditsPage extends ConsumerWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(creditControllerProvider);
    final ctrl = ref.read(creditControllerProvider.notifier);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kredit'),
          actions: [
            if (kDebugMode && ctrl.canAddDemoCredit)
              IconButton(
                tooltip: 'Tambah 1 kredit (debug)',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: ctrl.addDemoCredit,
              ),
            IconButton(
              tooltip: 'Muat ulang',
              icon: const Icon(Icons.refresh),
              onPressed: s.loading ? null : ctrl.refresh,
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Saldo & Paket'), Tab(text: 'Riwayat')]),
        ),
        body: s.status == null && s.loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_BalanceTab(state: s), _HistoryTab(state: s)]),
      ),
    );
  }
}

Widget _page(List<Widget> children) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(padding: const EdgeInsets.all(20), children: children),
      ),
    );

/// Format Rupiah sederhana, mis. 15000 → "Rp15.000".
String formatRupiah(int v) {
  final digits = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${v < 0 ? '-' : ''}Rp$buf';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String formatDate(DateTime t, {bool time = true}) {
  final d = '${t.day} ${_months[t.month - 1]} ${t.year}';
  if (!time) return d;
  String two(int v) => v.toString().padLeft(2, '0');
  return '$d ${two(t.hour)}.${two(t.minute)}';
}

class _BalanceTab extends StatelessWidget {
  const _BalanceTab({required this.state});
  final CreditState state;

  @override
  Widget build(BuildContext context) {
    final status = state.status;
    final theme = Theme.of(context);
    return _page([
      if (state.error != null) ...[
        Card(
          margin: EdgeInsets.zero,
          color: theme.colorScheme.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.cloud_off),
            title: Text(state.error!),
            subtitle: status == null
                ? null
                : Text('Data terakhir diperbarui ${formatDate(status.updatedAt)}'),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (status != null) ...[
        Row(children: [
          Expanded(
            child: _StatCard(
              icon: Icons.card_giftcard,
              label: 'Kuota gratis tersisa',
              value: '${status.freeQuotaRemaining}/${BusinessConstants.freeDaysPerMonth}',
              note: 'hari, bulan ini',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Saldo kredit',
              value: '${status.balance}',
              note: '1 kredit = 1 hari',
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _TodayCard(status: status),
      ],
      const SizedBox(height: 20),
      Text('Paket kredit', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final p in state.packages) _PackageTile(package: p),
      const SizedBox(height: 8),
      Text(
        'Kuota gratis ${BusinessConstants.freeDaysPerMonth} Hari Pemantauan AI direset tiap awal bulan. '
        'Mode Timer 20-20-20 selalu gratis tanpa batas.',
        style: theme.textTheme.bodySmall,
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.note});
  final IconData icon;
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(note, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.status});
  final CreditStatus status;

  @override
  Widget build(BuildContext context) {
    final active = status.todayActive;
    final source = switch (status.todaySource) {
      DaySource.free => ' (kuota gratis)',
      DaySource.credit => ' (1 kredit)',
      null => '',
    };
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(active ? Icons.check_circle : Icons.radio_button_unchecked,
            color: active ? AppTheme.normal : null),
        title: Text('Hari Pemantauan AI hari ini: ${active ? 'AKTIF$source' : 'belum aktif'}'),
        subtitle: Text(active
            ? 'Berlaku hingga pukul 23.59. Jeda lalu lanjut hari ini tidak memotong kredit lagi.'
            : 'Diaktifkan otomatis saat Anda memulai Pemantauan AI.'),
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({required this.package});
  final CreditPackage package;

  Future<void> _buy(BuildContext context) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Beli ${package.name}'),
          content: const Text('Pembayaran Midtrans akan tersedia setelah backend siap.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.toll_outlined),
        title: Text(package.name),
        subtitle: Text('${package.credits} kredit • ${formatRupiah(package.priceIdr)}'),
        trailing: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => _buy(context),
          child: const Text('Beli'),
        ),
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.state});
  final CreditState state;

  static String _reasonLabel(LedgerEntry e) => switch (e.reason) {
        LedgerReason.purchase => 'Pembelian kredit',
        LedgerReason.usage => 'Pemakaian: Hari Pemantauan AI',
        LedgerReason.adjustment => 'Penyesuaian${e.note == null ? '' : ': ${e.note}'}',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.orders.isEmpty && state.ledger.isEmpty) {
      return const Center(child: Text('Belum ada riwayat'));
    }
    return _page([
      Text('Transaksi', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      if (state.orders.isEmpty) const Text('Belum ada transaksi.'),
      for (final o in state.orders)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text('${o.packageName} • ${o.credits} kredit'),
            subtitle: Text('${formatDate(o.createdAt)} • ${o.orderCode}'
                '${o.paymentType == null ? '' : ' • ${o.paymentType!.toUpperCase()}'}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatRupiah(o.amountIdr), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(o.status.label,
                    style: TextStyle(
                        fontSize: 12,
                        color: switch (o.status) {
                          OrderStatus.settlement => AppTheme.normal,
                          OrderStatus.pending => AppTheme.waspada,
                          _ => AppTheme.lelah,
                        })),
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      Text('Mutasi kredit', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      if (state.ledger.isEmpty) const Text('Belum ada mutasi kredit.'),
      for (final e in state.ledger)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(e.delta >= 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                color: e.delta >= 0 ? AppTheme.normal : AppTheme.lelah),
            title: Text(_reasonLabel(e)),
            subtitle: Text(formatDate(e.createdAt)),
            trailing: Text('${e.delta > 0 ? '+' : ''}${e.delta}',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ),
      Text('Pemakaian kuota gratis tidak memotong kredit sehingga tidak tercatat di mutasi.',
          style: theme.textTheme.bodySmall),
    ]);
  }
}
