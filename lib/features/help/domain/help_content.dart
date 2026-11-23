import '../../../core/constants/business_constants.dart';
import '../../../core/constants/cv_constants.dart';

/// Topik bantuan; tiap layar membuka Bantuan dengan topiknya terbuka.
enum HelpTopic { umum, dashboard, kalibrasi, statistik, kredit, pengaturan, cekMata, akun }

class HelpEntry {
  const HelpEntry(this.question, this.answer);
  final String question;
  final String answer;
}

class HelpSection {
  const HelpSection(this.topic, this.title, this.entries);
  final HelpTopic topic;
  final String title;
  final List<HelpEntry> entries;
}

/// Isi User Manual singkat + FAQ (SRS 2.6, DOCS_SPEC §7.5). Statis, tanpa
/// jaringan. Angka diambil dari konstanta agar tidak menyimpang dari kode.
List<HelpSection> helpSections() {
  final waspada = CvConstants.levelWaspadaMin;
  final lelah = CvConstants.levelLelahMin;
  final quota = BusinessConstants.freeDaysPerMonth;
  return [
    HelpSection(HelpTopic.umum, 'Tentang VisionGuard', [
      const HelpEntry('Apa itu VisionGuard?',
          'VisionGuard membantu mendeteksi dini kelelahan mata digital. Kamera dipakai untuk '
              'menghitung kedipan, lama mata tertutup, dan jarak wajah ke layar, lalu digabung '
              'menjadi skor kelelahan yang memicu pengingat istirahat.'),
      const HelpEntry('Apakah VisionGuard alat medis?',
          'Bukan. VisionGuard bukan alat medis dan tidak menggantikan pemeriksaan dokter mata. '
              'Bila keluhan mata berlanjut, konsultasikan dengan tenaga kesehatan.'),
      const HelpEntry('Apakah gambar wajah saya disimpan atau dikirim?',
          'Tidak. Gambar kamera hanya diproses di memori perangkat lalu dibuang. Yang disimpan '
              'dan disinkronkan hanya angka ringkasan (kedipan, jarak, skor, durasi).'),
    ]),
    HelpSection(HelpTopic.dashboard, 'Dashboard & pemantauan', [
      const HelpEntry('Bagaimana memulai pemantauan?',
          'Selesaikan kalibrasi, lalu tekan "Mulai Pemantauan AI" di Dashboard. Hari Pemantauan '
              'AI diaktifkan sekali per hari dengan kuota gratis atau 1 kredit. Tekan Stop untuk '
              'berhenti; memulai lagi di hari yang sama tidak memotong kredit lagi.'),
      HelpEntry('Apa arti angka di Dashboard?',
          'Blink rate = jumlah kedipan per menit (normal sekitar 15–20). PERCLOS = persentase '
              'waktu mata tertutup. Jarak = perkiraan jarak wajah ke layar. Skor kelelahan 0–100: '
              '0–${waspada - 1} Normal, $waspada–${lelah - 1} Waspada, $lelah–100 Lelah.'),
      const HelpEntry('Apa itu Mode Timer?',
          'Mode tanpa kamera yang hanya mengingatkan aturan 20-20-20: setiap 20 menit, lihat '
              'benda sejauh 20 kaki (±6 m) selama 20 detik. Gratis tanpa batas, dan otomatis '
              'dipakai saat offline atau kamera tidak tersedia.'),
      HelpEntry('Kenapa kamera tidak aktif?',
          'Kemungkinan: izin kamera ditolak, kamera sedang dipakai aplikasi lain (mis. aplikasi '
              'rapat), atau perangkat tidak punya kamera. Saat kamera dipakai aplikasi lain, '
              'VisionGuard beralih ke Mode Timer dan mencoba lagi tiap '
              '${CvConstants.cameraRetryInterval.inSeconds} detik.'),
      const HelpEntry('Apa itu "Mode simulasi"?',
          'Bila deteksi wajah asli belum didukung di perangkat (saat ini Windows), aplikasi '
              'memakai data wajah tiruan agar fitur tetap bisa dicoba. Angka di mode ini bukan '
              'hasil pengukuran mata Anda.'),
      const HelpEntry('Bagaimana menanggapi pengingat?',
          'Tekan Oke untuk mengikuti, atau Tunda 15/30/60 menit. Pada 20-20-20, Oke memulai '
              'hitung mundur 20 detik; alihkan pandangan dari layar sampai selesai. Mode Fokus '
              'menahan semua pengingat selama 30–120 menit.'),
      const HelpEntry('Apakah pemantauan tetap berjalan saat jendela ditutup?',
          'Di Windows, menutup jendela menyembunyikan VisionGuard ke system tray; pemantauan '
              'tetap berjalan dan pengingat muncul sebagai notifikasi. Pilih Keluar di menu tray '
              'untuk benar-benar menutup aplikasi. Di Android, notifikasi permanen tampil selama '
              'Pemantauan AI; pemantauan berhenti saat layar dimatikan.'),
    ]),
    const HelpSection(HelpTopic.kalibrasi, 'Kalibrasi', [
      HelpEntry('Kenapa perlu kalibrasi?',
          'Bentuk mata dan kamera tiap orang berbeda. Kalibrasi mata (10 detik) mencatat '
              'ukuran mata terbuka Anda, kalibrasi jarak mencatat lebar iris pada jarak acuan.'),
      HelpEntry('Kenapa jarak tidak akurat?',
          'Pastikan kalibrasi jarak dilakukan tepat pada jarak acuan (50 cm di komputer, 30 cm '
              'di ponsel). Melewati kalibrasi jarak membuat perkiraan kurang akurat. Cahaya '
              'redup, kacamata yang memantulkan cahaya, atau wajah miring juga mengurangi '
              'akurasi. Ganti kamera → lakukan kalibrasi ulang.'),
    ]),
    const HelpSection(HelpTopic.statistik, 'Statistik', [
      HelpEntry('Data apa yang ditampilkan?',
          'Tab Hari Ini menampilkan durasi menatap layar, rata-rata kedipan, jarak, skor, dan '
              'kepatuhan istirahat. Tab Tren menampilkan grafik 7 atau 30 hari (minimal 2 hari '
              'data). Ringkasan disinkronkan ke akun saat online.'),
    ]),
    HelpSection(HelpTopic.kredit, 'Kuota & kredit', [
      HelpEntry('Bagaimana kuota gratis dihitung?',
          'Setiap bulan Anda mendapat $quota hari Pemantauan AI gratis. Satu hari terpakai saat '
              'Pemantauan AI pertama kali dimulai pada hari itu, berapa pun lamanya. Setelah '
              'kuota habis, setiap hari baru memakai 1 kredit.'),
      const HelpEntry('Bagaimana membeli kredit?',
          'Buka Kredit, pilih paket, lalu bayar di halaman Midtrans (QRIS, e-wallet, atau '
              'virtual account). Kembali ke aplikasi dan tekan "Muat ulang status"; kredit '
              'bertambah setelah pembayaran dikonfirmasi.'),
    ]),
    const HelpSection(HelpTopic.cekMata, 'Sesi Cek Mata (ponsel)', [
      HelpEntry('Apa itu Sesi Cek Mata?',
          'Pemeriksaan singkat 2 menit di ponsel: baca teks yang tampil sambil kamera mengukur '
              'kedipan, lama mata tertutup, dan jarak. Hasilnya berupa skor dan saran. Sesi butuh '
              'Hari Pemantauan AI yang aktif. Keluar sebelum 2 menit membatalkan sesi dan '
              'hasilnya tidak disimpan.'),
    ]),
    const HelpSection(HelpTopic.pengaturan, 'Pengaturan', [
      HelpEntry('Apa pengaruh sensitivitas?',
          'Sensitivitas mengatur seberapa mudah mata dianggap tertutup. Tinggi = lebih mudah, '
              'cocok bila kedipan Anda sering tidak terhitung.'),
      HelpEntry('Bagaimana menjalankan VisionGuard saat komputer menyala?',
          'Aktifkan "Jalankan saat komputer menyala" di Pengaturan (Windows). VisionGuard akan '
              'terbuka di system tray setelah Anda masuk ke Windows.'),
    ]),
    const HelpSection(HelpTopic.akun, 'Akun', [
      HelpEntry('Lupa kata sandi?',
          'Tekan "Lupa kata sandi?" di halaman masuk, masukkan email, lalu buka tautan yang '
              'dikirim untuk membuat kata sandi baru.'),
      HelpEntry('Bagaimana menghapus akun?',
          'Buka Pengaturan → Hapus Akun dan masukkan kata sandi. Data akun dan semua data di '
              'perangkat ini dihapus.'),
    ]),
  ];
}
