import 'package:flutter/material.dart';

import '../../../shared/widgets/coming_soon.dart';

/// S-09 Kredit & Pembayaran (KRD-01..04). Placeholder; diisi di bagian berikutnya.
class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kredit')),
      body: const ComingSoon(
        icon: Icons.account_balance_wallet,
        title: 'Kredit & Pembayaran',
        description: 'Saldo kredit, sisa kuota gratis, paket kredit, pembelian via Midtrans, '
            'dan riwayat transaksi.',
      ),
    );
  }
}
