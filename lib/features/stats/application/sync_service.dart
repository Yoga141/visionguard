import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../monitoring/data/metrics_repository.dart';
import '../data/stats_repository.dart';

final syncServiceProvider = Provider<SyncService>(SyncService.new);

/// SyncService (SDD 4.1, Seq 4.26, DFD 6.2): kirim `daily_summaries` yang
/// belum `synced` ke `POST /stats/daily`, lalu tandai `synced = true`.
/// Gagal/offline → baris tetap `synced = false` dan dikirim ulang nanti.
class SyncService {
  SyncService(this._ref);

  final Ref _ref;
  Future<bool>? _running;

  /// `true` bila semua ringkasan tertunda berhasil terkirim (atau tidak ada).
  /// Panggilan bersamaan memakai proses yang sama.
  Future<bool> syncPending() => _running ??= _sync().whenComplete(() => _running = null);

  Future<bool> _sync() async {
    final metrics = _ref.read(metricsRepositoryProvider);
    try {
      final pending = await metrics.pendingSync();
      if (pending.isEmpty) return true;
      await _ref.read(statsRepositoryProvider).uploadDaily(pending);
      for (final p in pending) {
        await metrics.markSynced(p.day);
      }
      return true;
    } catch (e) {
      debugPrint('SyncService: sinkronisasi tertunda (${e.runtimeType}).');
      return false;
    }
  }
}
