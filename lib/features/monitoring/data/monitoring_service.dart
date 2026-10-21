import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service untuk menyimpan dan mengambil log data metrik kelelahan ke Firestore.
///
/// Struktur Firestore:
/// ```
/// users/{uid}/fatigue_logs/{autoId}
///   ├── ear            : double
///   ├── blinkRate       : double
///   ├── perclos         : double
///   ├── distanceCm      : double?
///   ├── fatigueScore    : double
///   ├── totalBlinks     : int
///   ├── screenMinutes   : double
///   ├── timestamp       : Timestamp
///   └── createdAt       : Timestamp (server)
/// ```
class MonitoringService {
  MonitoringService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Koleksi log kelelahan milik pengguna yang sedang login.
  ///
  /// Melempar [StateError] jika belum ada pengguna yang login.
  CollectionReference<Map<String, dynamic>> get _logsCollection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Tidak ada pengguna yang login. Silakan login terlebih dahulu.');
    }
    return _firestore.collection('users').doc(uid).collection('fatigue_logs');
  }

  /// Menyimpan satu snapshot metrik kelelahan ke Firestore.
  ///
  /// Dipanggil secara periodik oleh [MonitoringController] saat
  /// skor kelelahan terdeteksi meningkat atau pada interval tertentu.
  Future<void> saveFatigueLog({
    required double ear,
    required double blinkRate,
    required double perclos,
    double? distanceCm,
    required double fatigueScore,
    required int totalBlinks,
    required double screenMinutes,
  }) async {
    await _logsCollection.add({
      'ear': ear,
      'blinkRate': blinkRate,
      'perclos': perclos,
      'distanceCm': distanceCm,
      'fatigueScore': fatigueScore,
      'totalBlinks': totalBlinks,
      'screenMinutes': screenMinutes,
      'timestamp': Timestamp.now(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mengambil riwayat log kelelahan terbaru.
  ///
  /// Default mengembalikan 50 data terakhir; atur [limit] untuk mengubahnya.
  Future<List<Map<String, dynamic>>> getRecentLogs({int limit = 50}) async {
    final snapshot = await _logsCollection
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Mengambil log kelelahan dalam rentang tanggal tertentu.
  Future<List<Map<String, dynamic>>> getLogsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _logsCollection
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Menghapus satu log berdasarkan ID dokumen.
  Future<void> deleteLog(String logId) async {
    await _logsCollection.doc(logId).delete();
  }
}
