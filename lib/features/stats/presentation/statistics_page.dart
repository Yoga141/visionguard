import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/business_constants.dart';
import '../../../core/constants/cv_constants.dart';
import '../../../core/database/app_database.dart';
import '../../ai_assistant/data/ai_advice_repository.dart';
import '../../ai_assistant/presentation/ai_advice_card.dart';
import '../application/stats_controller.dart';

/// S-08 Statistik: ringkasan hari ini (STK-01, UC-16) & grafik tren 7/30
/// hari (STK-02, UC-17), dari database lokal.
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  Future<void> _seed(BuildContext context, WidgetRef ref) async {
    await ref.read(statsControllerProvider.notifier).seedDemoData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Data contoh ${BusinessConstants.demoSeedDays} hari ditambahkan.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsControllerProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistik'),
          actions: [
            if (kDebugMode)
              IconButton(
                tooltip: 'Isi data contoh ${BusinessConstants.demoSeedDays} hari (debug)',
                icon: const Icon(Icons.dataset_outlined),
                onPressed: stats.isLoading ? null : () => _seed(context, ref),
              ),
            IconButton(
              tooltip: 'Muat ulang',
              icon: const Icon(Icons.refresh),
              onPressed: stats.isLoading
                  ? null
                  : () => ref.read(statsControllerProvider.notifier).refresh(),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Hari Ini'), Tab(text: 'Tren')]),
        ),
        body: switch (stats) {
          AsyncValue(:final value?) => TabBarView(children: [
              _TodayTab(data: value, onSeed: kDebugMode ? () => _seed(context, ref) : null),
              _TrendTab(data: value),
            ]),
          AsyncValue(:final error?) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Data statistik lokal tidak dapat dibaca.\n$error',
                    textAlign: TextAlign.center),
              ),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
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

String _minutes(int m) => m >= 60 ? '${m ~/ 60} j ${m % 60} m' : '$m m';

class _TodayTab extends StatelessWidget {
  const _TodayTab({required this.data, this.onSeed});
  final StatsData data;
  final VoidCallback? onSeed;

  @override
  Widget build(BuildContext context) {
    final s = data.today;
    return _page([
      Text('Ringkasan hari ini', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      _SyncNote(synced: data.synced),
      const SizedBox(height: 12),
      if (s == null)
        _EmptyCard(
          icon: Icons.today_outlined,
          text: 'Belum ada data hari ini',
          detail: 'Mulai Pemantauan AI atau Mode Timer dari Dashboard.',
          onSeed: onSeed,
        )
      else ...[
        _SummaryGrid(summary: s, data: data),
        const SizedBox(height: 16),
        AiAdviceCard(metrics: _adviceMetrics(s), emptyHint: 'Belum ada skor kelelahan hari ini.'),
      ],
    ]);
  }

  /// §17.2: hanya angka ringkasan harian.
  static AdviceMetrics? _adviceMetrics(DailySummary s) => s.avgFatigueScore == null
      ? null
      : AdviceMetrics(
          fatigueScore: s.avgFatigueScore!.round(),
          blinkRate: s.avgBlinkRate,
          distanceCm: s.avgDistanceCm,
        );
}

class _SyncNote extends StatelessWidget {
  const _SyncNote({required this.synced});
  final bool synced;

  @override
  Widget build(BuildContext context) => Text(
        synced
            ? 'Dihitung dari data di perangkat ini.'
            : 'Offline — menampilkan data lokal; sinkronisasi dicoba lagi nanti.',
        style: Theme.of(context).textTheme.bodySmall,
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text, required this.detail, this.onSeed});
  final IconData icon;
  final String text;
  final String detail;
  final VoidCallback? onSeed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(text, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(detail, textAlign: TextAlign.center),
            if (onSeed != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onSeed,
                icon: const Icon(Icons.dataset_outlined),
                label: const Text('Isi data contoh ${BusinessConstants.demoSeedDays} hari'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.data});
  final DailySummary summary;
  final StatsData data;

  @override
  Widget build(BuildContext context) {
    String f(double? v, int d) => v == null ? '--' : v.toStringAsFixed(d);
    final compliance = data.breakCompliance;
    final tiles = [
      _Tile(icon: Icons.schedule, label: 'Durasi layar', value: _minutes(summary.screenMinutes)),
      _Tile(
          icon: Icons.remove_red_eye_outlined,
          label: 'Rata-rata blink rate',
          value: '${f(summary.avgBlinkRate, 1)} /menit'),
      _Tile(icon: Icons.straighten, label: 'Rata-rata jarak', value: '${f(summary.avgDistanceCm, 0)} cm'),
      _Tile(
          icon: Icons.speed,
          label: 'Rata-rata skor',
          value: f(summary.avgFatigueScore, 0),
          color: _scoreColor(summary.avgFatigueScore)),
      _Tile(
          icon: Icons.notifications_active_outlined,
          label: 'Jumlah pengingat',
          value: '${summary.alertsCount}'),
      _Tile(
        icon: Icons.self_improvement,
        label: 'Kepatuhan istirahat',
        value: compliance == null
            ? '--'
            : '${(compliance * 100).round()}% (${summary.breaksTaken}/${data.breakReminders})',
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 520 ? 3 : 2;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: tiles,
      );
    });
  }

  static Color? _scoreColor(double? v) => v == null
      ? null
      : v >= CvConstants.levelLelahMin
          ? AppTheme.lelah
          : v >= CvConstants.levelWaspadaMin
              ? AppTheme.waspada
              : AppTheme.normal;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value, this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            ]),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendTab extends StatefulWidget {
  const _TrendTab({required this.data});
  final StatsData data;

  @override
  State<_TrendTab> createState() => _TrendTabState();
}

class _TrendTabState extends State<_TrendTab> {
  int _days = BusinessConstants.trendRangesDays.first;

  @override
  Widget build(BuildContext context) {
    final points = widget.data.lastDays(_days);
    final enough = StatsData.daysWithData(points) >= BusinessConstants.trendMinDays;
    final scheme = Theme.of(context).colorScheme;
    return _page([
      Center(
        child: SegmentedButton<int>(
          segments: [
            for (final d in BusinessConstants.trendRangesDays)
              ButtonSegment(value: d, label: Text('$d hari')),
          ],
          selected: {_days},
          onSelectionChanged: (v) => setState(() => _days = v.first),
        ),
      ),
      const SizedBox(height: 8),
      _SyncNote(synced: widget.data.synced),
      const SizedBox(height: 12),
      if (!enough)
        const _EmptyCard(
          icon: Icons.insights_outlined,
          text: 'Data belum cukup (minimal ${BusinessConstants.trendMinDays} hari)',
          detail: 'Grafik tren tampil setelah ada data pemantauan minimal '
              '${BusinessConstants.trendMinDays} hari.',
        )
      else ...[
        _ChartCard(
          title: 'Blink rate rata-rata (/menit)',
          note: 'Garis putus-putus: ambang kedip ${CvConstants.lowBlinkRatePerMin.round()}/menit',
          child: _LineTrend(
            points: points,
            value: (s) => s.avgBlinkRate,
            color: scheme.primary,
            thresholds: const [(CvConstants.lowBlinkRatePerMin, AppTheme.waspada)],
          ),
        ),
        _ChartCard(
          title: 'Skor kelelahan rata-rata (0–100)',
          note: 'Garis: ${CvConstants.levelWaspadaMin} Waspada • ${CvConstants.levelLelahMin} Lelah',
          child: _LineTrend(
            points: points,
            value: (s) => s.avgFatigueScore,
            color: AppTheme.lelah,
            minY: 0,
            maxY: 100,
            thresholds: [
              (CvConstants.levelWaspadaMin.toDouble(), AppTheme.waspada),
              (CvConstants.levelLelahMin.toDouble(), AppTheme.lelah),
            ],
          ),
        ),
        _ChartCard(
          title: 'Durasi layar per hari (menit)',
          child: _BarTrend(points: points, color: scheme.tertiary),
        ),
      ],
    ]);
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child, this.note});
  final String title;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text(note!, style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            SizedBox(height: 180, child: child),
          ],
        ),
      ),
    );
  }
}

/// Label sumbu-x: tanggal/bulan, dijarangkan untuk rentang 30 hari.
FlTitlesData _titles(List<TrendPoint> points) {
  final step = points.length > 10 ? 5 : 1;
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: 1,
        reservedSize: 24,
        getTitlesWidget: (value, meta) {
          final i = value.round();
          if (i < 0 || i >= points.length || value != i.toDouble()) return const SizedBox.shrink();
          // Label dihitung mundur dari hari ini agar hari ini selalu berlabel.
          if ((points.length - 1 - i) % step != 0) return const SizedBox.shrink();
          final d = points[i].day;
          return SideTitleWidget(
            meta: meta,
            child: Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 10)),
          );
        },
      ),
    ),
  );
}

class _LineTrend extends StatelessWidget {
  const _LineTrend({
    required this.points,
    required this.value,
    required this.color,
    this.thresholds = const [],
    this.minY,
    this.maxY,
  });

  final List<TrendPoint> points;
  final double? Function(DailySummary) value;
  final Color color;
  final List<(double, Color)> thresholds;
  final double? minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < points.length; i++)
        switch (points[i].summary) {
          final s? when value(s) != null => FlSpot(i.toDouble(), value(s)!),
          _ => FlSpot.nullSpot,
        },
    ];
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        titlesData: _titles(points),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(drawVerticalLine: false),
        extraLinesData: ExtraLinesData(horizontalLines: [
          for (final (y, c) in thresholds)
            HorizontalLine(y: y, color: c.withValues(alpha: 0.8), strokeWidth: 1, dashArray: [6, 4]),
        ]),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(show: points.length <= 14),
          ),
        ],
      ),
    );
  }
}

class _BarTrend extends StatelessWidget {
  const _BarTrend({required this.points, required this.color});
  final List<TrendPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        titlesData: _titles(points),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(drawVerticalLine: false),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: (points[i].summary?.screenMinutes ?? 0).toDouble(),
                color: color,
                width: points.length > 10 ? 6 : 14,
                borderRadius: BorderRadius.circular(3),
              ),
            ]),
        ],
      ),
    );
  }
}
