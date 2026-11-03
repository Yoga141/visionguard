import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ai_advice_provider.dart';
import '../data/ai_advice_repository.dart';

/// Kartu "Saran AI" (DOCS_SPEC §17). Mengirim **hanya angka ringkasan**
/// ([AdviceMetrics]) lewat [AiAdviceRepository]; bila key kosong/gagal,
/// repository mengembalikan saran statis, dan kartu ini juga memakai saran
/// statis bila terjadi error tak terduga.
class AiAdviceCard extends ConsumerStatefulWidget {
  const AiAdviceCard({super.key, required this.metrics, this.emptyHint});

  /// Angka ringkasan saat ini; null = belum ada data (tombol nonaktif).
  final AdviceMetrics? metrics;

  /// Teks saat [metrics] null.
  final String? emptyHint;

  @override
  ConsumerState<AiAdviceCard> createState() => _AiAdviceCardState();
}

class _AiAdviceCardState extends ConsumerState<AiAdviceCard> {
  bool _loading = false;
  String? _advice;

  Future<void> _request() async {
    final metrics = widget.metrics;
    if (metrics == null || _loading) return;
    setState(() => _loading = true);
    String text;
    try {
      text = await ref.read(aiAdviceRepositoryProvider).getAdvice(metrics);
    } catch (_) {
      text = StaticAdvice.forMetrics(metrics);
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _advice = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = widget.metrics != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text('Saran AI', style: theme.textTheme.titleMedium)),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: hasData && !_loading ? _request : null,
                  child: Text(_advice == null ? 'Minta saran' : 'Minta lagi'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Saran umum, bukan diagnosis medis', style: theme.textTheme.labelSmall),
            const SizedBox(height: 12),
            if (_loading)
              const Row(children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Menyusun saran...'),
              ])
            else if (_advice != null)
              SelectableText(_advice!)
            else
              Text(
                hasData
                    ? 'Hanya angka ringkasan (skor, blink rate, jarak) yang dikirim. '
                        'Tidak ada gambar kamera.'
                    : (widget.emptyHint ?? 'Belum ada data untuk dianalisis.'),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
