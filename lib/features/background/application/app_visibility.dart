import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true saat jendela desktop disembunyikan ke system tray (S-11) atau
/// aplikasi mobile berada di latar belakang (PMT-06). Selama true, pengingat
/// dikirim lewat notifikasi sistem karena pop-up dalam aplikasi tidak terlihat.
final appInBackgroundProvider = StateProvider<bool>((ref) => false);
