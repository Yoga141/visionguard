import 'package:flutter/material.dart';

import '../../../shared/widgets/coming_soon.dart';

/// S-08 Statistik (STK-01, STK-02). Placeholder; diisi di bagian berikutnya.
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: const ComingSoon(
        icon: Icons.bar_chart,
        title: 'Statistik',
        description: 'Ringkasan hari ini (durasi layar, rata-rata kedipan, jumlah pengingat, '
            'kepatuhan istirahat) dan grafik tren 7 & 30 hari.',
      ),
    );
  }
}
