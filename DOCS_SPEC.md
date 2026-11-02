# DOCS_SPEC — VisionGuard (ringkasan SRS + SDD v1.0)

> Sumber kebenaran untuk implementasi. Disusun dari **SRS VisionGuard v1.0** (25 Sep 2026) dan **SDD VisionGuard v1.0** (Sep 2026), Mayoga Finanda (11241044), Informatika.
> Jika kode bertentangan dengan dokumen ini, **ikuti dokumen ini** kecuali ada catatan di §16 (Inkonsistensi & Keputusan Terbuka).
> Penanda sumber: `[SRS x.y]`, `[SDD x.y]`. Semua ambang CV adalah **nilai awal** yang boleh disetel setelah pengujian.

---

## 0. Ringkasan Satu Paragraf

VisionGuard adalah aplikasi **Flutter** (Windows, macOS, Android, iOS — satu basis kode) yang memakai webcam/kamera depan untuk menghitung **blink rate (BR)**, **PERCLOS**, dan **jarak wajah ke layar** secara *on-device* (MediaPipe Face Landmarker via TFLite). Ketiganya digabung menjadi **skor kelelahan 0–100**, lalu dipakai untuk memunculkan **pengingat** (istirahat, jarak, kedip, 20-20-20). **Gambar kamera tidak pernah disimpan/dikirim.** Backend **Laravel + Sanctum + MySQL** hanya mengurus akun, kredit, pembayaran **Midtrans**, dan statistik angka. Panel admin memakai **Laravel Filament**. Model bisnis **freemium + pay-per-credit**.

---

## 1. Tujuan, Ruang Lingkup, Batasan

### 1.1 Tujuan produk [SRS 1.1]
- Mengenali tanda awal kelelahan mata (BR + jarak) otomatis via kamera.
- Memberi pengingat tepat waktu: berkedip, mundur dari layar, istirahat, 20-20-20.
- Menjaga privasi: gambar kamera diproses sepenuhnya di perangkat.
- Menyediakan statistik harian & mingguan/tren.
- Model pendapatan adil: fitur tanpa kamera gratis, fitur AI punya kuota gratis bulanan, lanjut dengan kredit.

### 1.2 Batasan produk v1.0 [SRS 1.3, SDD 1.2]
1. **Bukan alat medis** — tidak mendiagnosis, tidak menggantikan dokter mata.
2. **Platform**: Windows, macOS, Android, iOS. **Tidak ada** versi web (selain panel admin) dan Linux.
3. **iOS**: kamera dilarang di latar belakang → di iOS pemantauan hanya saat app terbuka; fitur utama iOS = **Sesi Cek Mata** + **Mode Timer**.
4. Akurasi turun pada cahaya redup, pantulan kacamata, wajah terlalu miring.
5. Internet **wajib** untuk: login, aktivasi Hari Pemantauan AI, pembelian kredit, sinkronisasi statistik. **Setelah aktif, pemantauan tetap jalan offline.**
6. Bergantung pada Midtrans (pembayaran) dan layanan email SMTP (reset sandi).
7. **Di luar scope v1.0**: diagnosis medis, *gaze tracking* presisi tinggi, versi web, versi Linux.

### 1.3 Batasan desain & implementasi [SRS 2.5]
- **Privasi kamera**: frame hanya di memori; **dilarang** ditulis ke disk / dikirim ke jaringan. Penjelasan privasi **wajib** tampil sebelum kamera pertama kali menyala.
- **Aturan OS**: iOS melarang kamera latar belakang; Android hanya lewat **foreground service** dengan notifikasi permanen; Windows: webcam biasanya hanya untuk satu aplikasi → jika dipakai app lain (mis. Zoom), **beralih ke Mode Timer**.
- **Teknologi wajib**: Flutter (klien), Laravel + MySQL (backend), Midtrans (pembayaran).
- Dikerjakan satu semester, fitur bertahap sesuai prioritas (§5).
- **Konvensi**: kode modular, **modul CV terpisah dari UI**, Git untuk version control, **RESTful API JSON**.

---

## 2. Istilah [SRS 1.4]

| Istilah | Definisi |
|---|---|
| Kelelahan mata digital | Mata kering/perih/buram/sakit kepala akibat menatap layar lama (digital eye strain / Computer Vision Syndrome). |
| Blink Rate (BR) | Jumlah kedipan per menit dalam jendela **60 detik terakhir**. |
| EAR (Eye Aspect Ratio) | Rasio tinggi/lebar mata dari landmark; turun tajam saat mata menutup. |
| PERCLOS | Persentase waktu mata tertutup dalam satu jendela waktu. |
| Aturan 20-20-20 | Tiap 20 menit menatap layar, lihat objek ±6 m (20 kaki) selama 20 detik. |
| Skor Kelelahan | Nilai 0–100 gabungan BR, PERCLOS, dan lama menatap layar tanpa istirahat. |
| Landmark Wajah | Titik koordinat wajah (mata, iris, dll.) dari MediaPipe Face Landmarker (478 titik). |
| On-device | Diproses di perangkat tanpa mengirim gambar. |
| Hari Pemantauan AI | Hak memakai fitur kamera selama **satu hari kalender (00.00–23.59)** menurut zona waktu akun. |
| Kredit | Satuan berbayar; **1 kredit = 1 Hari Pemantauan AI**. |
| Mode Timer | Pengingat 20-20-20 tanpa kamera, **gratis tanpa batas**. |
| Sesi Cek Mata | Pemeriksaan **2 menit** di aplikasi **mobile** saat membaca. |
| Midtrans | Payment gateway: QRIS, e-wallet, virtual account. |

---

## 3. Aktor & Hak Akses [SRS 2.3]

| Aktor | Tugas | Hak akses |
|---|---|---|
| **Pengguna** (mahasiswa & pekerja IT) | Kalibrasi, pemantauan, respons pengingat, statistik, beli kredit | Insert/View/Update data milik sendiri; Delete akun sendiri |
| **Admin** | Kelola paket kredit, pantau pengguna & transaksi, penyesuaian kredit | Full access panel admin (Insert, View, Update, nonaktifkan) |
| **Midtrans** (eksternal) | Memproses pembayaran, kirim status transaksi | Mengirim notifikasi ke endpoint pembayaran |
| **Layanan Email** (eksternal) | Kirim tautan reset kata sandi | Menerima permintaan kirim email dari server |
| **Kamera Perangkat** (entitas DFD) | Memberi frame video | Frame hanya diproses di perangkat |

Role akun di DB: `ENUM('user','admin')`.

---

## 4. Lingkungan & Teknologi

### 4.1 Lingkungan operasi [SRS 2.4, SDD 3.1–3.2]
- **Klien**: Windows 10 64-bit+, macOS 12+, Android 8.0 (API 26)+, iOS 15+.
- **Panel admin**: browser modern (Chrome, Firefox, Edge), layar min. 1366×768.
- **Hardware desktop**: CPU 4 core (mis. i3 gen 8 / Ryzen 3), RAM 4 GB (disarankan 8), webcam ≥ 640×480 @ 15 fps, ruang kosong ≥ 300 MB.
- **Hardware ponsel**: RAM ≥ 3 GB, kamera depan berfungsi.
- **Server**: VPS Linux 2 vCPU, RAM 2 GB, SSD ≥ 40 GB, TLS/HTTPS. OS: **Ubuntu Server 22.04 LTS** + Nginx + PHP-FPM.
- Output suara opsional (bunyi pengingat).

### 4.2 Stack [SDD Tabel 3.1]

| Komponen | Teknologi | Alasan |
|---|---|---|
| Aplikasi klien | Flutter (Dart) | Satu basis kode 4 platform |
| State management | **Riverpod** | Pisahkan logika dari UI, mudah diuji |
| Model CV | **MediaPipe Face Landmarker (TFLite)** | Ringan di CPU, sudah ada titik iris |
| Runtime inferensi | **TensorFlow Lite (`tflite_flutter`)** | Model sama di mobile & desktop |
| DB lokal | **SQLite (`drift`)** | Semua platform, kueri bertipe |
| Notifikasi | **`flutter_local_notifications`** + pop-up kustom desktop | Jalan tanpa internet |
| Backend | **Laravel (PHP 8.2+) + Sanctum** | REST API + token auth |
| DB server | **MySQL 8** | Relasional, cocok untuk ledger |
| Panel admin | **Laravel Filament** | CRUD admin tanpa frontend terpisah |
| Pembayaran | **Midtrans Snap** | QRIS, e-wallet, VA |
| Version control | Git + GitHub | — |
| Email | SMTP | Reset kata sandi |

### 4.3 Komunikasi & keamanan [SRS 3.4, SDD 3.2]
- Klien ↔ server: **REST JSON over HTTPS (TLS ≥ 1.2)**. Server ↔ Midtrans/email: HTTPS/TLS.
- Setiap request membawa **token Laravel Sanctum**; token disimpan di **penyimpanan aman** perangkat.
- Kata sandi di-hash **bcrypt**.
- Notifikasi Midtrans diverifikasi dengan **signature key SHA-512** sebelum diproses.
- Pengingat = **notifikasi lokal** (tanpa push service), tetap jalan offline.
- Data yang boleh dikirim ke server: **akun, order, status hari pemantauan, ringkasan statistik angka**. Gambar **tidak pernah**.
- **Sinkronisasi**: ringkasan harian yang belum tersinkron disimpan lokal, dikirim otomatis saat online kembali.

### 4.4 Izin platform [SDD 3.2]
- Android: `CAMERA`, `FOREGROUND_SERVICE_CAMERA`, `POST_NOTIFICATIONS`.
- iOS & macOS: `NSCameraUsageDescription`.
- Windows: izin kamera dari pengaturan privasi Windows.

### 4.5 Distribusi [SDD 3.2]
Windows: installer `.exe`/MSIX · macOS: `.dmg` bertanda tangan · Android: Google Play · iOS: TestFlight → App Store.

### 4.6 Arsitektur [SDD 2.1, Gambar 2.1]
Klien–server dengan **edge AI**:
```
Kamera/Webcam --frame (tetap di perangkat)--> CV Engine (Face Landmarker, EAR, estimasi jarak, skor)
CV Engine --metrik--> Lapisan Aplikasi (Session, Pengingat, Kredit, Sinkronisasi)
Lapisan Aplikasi --> SQLite Lokal
Lapisan Aplikasi --> Antarmuka (layar, pop-up, tray)
Lapisan Aplikasi --HTTPS JSON (akun, kredit, statistik angka)--> Laravel REST API + Panel Admin (VPS)
Laravel --> MySQL ; Laravel <--transaksi--> Midtrans ; Laravel --> Layanan Email
```
Aliran frame **berhenti di CV Engine**.

---

## 5. Kebutuhan Fungsional [SRS 4, Tabel 4]

Modul: **AKN** Akun · **KLB** Kalibrasi · **PMT** Pemantauan · **PNG** Pengingat · **STK** Statistik · **KRD** Kredit & Pembayaran · **PGT** Pengaturan · **ADM** Admin.

| ID | Kebutuhan | Prioritas |
|---|---|---|
| AKN-01 | Daftar dengan nama, email, kata sandi | Tinggi |
| AKN-02 | Pengguna & admin login dan logout | Tinggi |
| AKN-03 | Reset kata sandi via tautan email | Sedang |
| AKN-04 | Hapus akun beserta data pribadi | Sedang |
| KLB-01 | Tampilkan penjelasan privasi & minta izin kamera sebelum kamera pertama aktif | Tinggi |
| KLB-02 | Rekam mata terbuka normal **10 detik** untuk ambang kedip pribadi | Tinggi |
| KLB-03 | Hitung focal length pada jarak acuan (**50 cm desktop, 30 cm mobile**) | Tinggi |
| KLB-04 | Kalibrasi ulang & **minta kalibrasi ulang saat kamera diganti** | Sedang |
| PMT-01 | Aktifkan Hari Pemantauan AI pakai kuota gratis atau 1 kredit | Tinggi |
| PMT-02 | Deteksi kedipan & BR real-time | Tinggi |
| PMT-03 | Estimasi jarak wajah (cm) real-time | Tinggi |
| PMT-04 | Hitung PERCLOS & skor kelelahan **setiap 10 detik** | Tinggi |
| PMT-05 | **Jeda perhitungan** saat wajah tak terdeteksi **> 10 detik** | Sedang |
| PMT-06 | Jalan di latar belakang (system tray desktop, foreground service Android) | Tinggi |
| PMT-07 | Sesi Cek Mata 2 menit (mobile) | Sedang |
| PMT-08 | Beralih ke Mode Timer saat kamera tak tersedia **atau** Hari Pemantauan AI tak aktif | Tinggi |
| PNG-01 | Pengingat kedip saat BR di bawah ambang | Tinggi |
| PNG-02 | Pengingat saat jarak terlalu dekat | Tinggi |
| PNG-03 | Pengingat istirahat saat skor mencapai ambang | Tinggi |
| PNG-04 | Pengingat 20-20-20 dengan hitung mundur 20 detik | Tinggi |
| PNG-05 | Verifikasi via kamera bahwa pengguna berpaling saat istirahat | Rendah |
| PNG-06 | Tunda pengingat **15/30/60 menit** & **Mode Fokus** | Sedang |
| PNG-07 | Cooldown minimum per jenis pengingat | Tinggi |
| STK-01 | Ringkasan harian: durasi layar, rata-rata BR, jumlah pengingat, kepatuhan istirahat | Tinggi |
| STK-02 | Grafik tren 7 & 30 hari | Sedang |
| STK-03 | Sinkron ringkasan harian (tanpa gambar) ke server | Sedang |
| KRD-01 | Tampilkan sisa kuota gratis, saldo kredit, status Hari Pemantauan AI | Tinggi |
| KRD-02 | Beli paket kredit via Midtrans | Tinggi |
| KRD-03 | Tambah kredit otomatis setelah pembayaran berhasil | Tinggi |
| KRD-04 | Riwayat transaksi & pemakaian kredit | Sedang |
| PGT-01 | Atur sensitivitas, jenis pengingat, interval 20-20-20 | Sedang |
| PGT-02 | Autostart saat OS menyala (desktop) | Rendah |
| ADM-01 | Admin tambah/ubah/nonaktifkan paket kredit | Sedang |
| ADM-02 | Admin lihat data pengguna & transaksi | Sedang |
| ADM-03 | Admin sesuaikan kredit manual dengan alasan tercatat | Rendah |

---

## 6. Kebutuhan Non-Fungsional [SRS 5, Tabel 5]

| ID | Kebutuhan | Ukuran keberhasilan |
|---|---|---|
| KNR-01 | Proses video real-time | ≥ **15 fps desktop**, ≥ **10 fps mobile** |
| KNR-02 | Ringan di latar belakang | CPU rata-rata ≤ **15%**, RAM ≤ **300 MB** (Core i5 gen 8, RAM 8 GB) |
| KNR-03 | Responsif | Pengingat muncul ≤ **2 detik** setelah kondisi terpenuhi; **95%** request API < **1 detik** |
| AKR-01 | Deteksi kedip akurat | Precision & recall ≥ **90%** pada data uji berlabel |
| AKR-02 | Estimasi jarak tepat | Galat ≤ **±5 cm** pada rentang **30–80 cm** setelah kalibrasi |
| PRV-01 | Gambar hanya di memori | Tidak ada gambar di disk/jaringan |
| PRV-02 | Server hanya data perlu, user bisa hapus data | Hanya data akun, transaksi, statistik angka; hapus akun berfungsi |
| PRV-03 | User selalu tahu kamera menyala | **Indikator kamera aktif selalu tampil** |
| KMN-01 | Komunikasi terenkripsi | Semua endpoint HTTPS (TLS ≥ 1.2) |
| KMN-02 | Akun terlindungi | bcrypt, token Sanctum, **login ditahan 5 menit setelah 5 kali gagal** |
| KMN-03 | Saldo tak bisa dimanipulasi dari app | **Saldo dihitung di server**; notifikasi Midtrans palsu ditolak |
| USB-01 | Mudah sejak awal | Onboarding + kalibrasi selesai ≤ **3 menit** |
| USB-02 | Pengingat tidak mengganggu | Tutup dengan **satu klik/ketuk**, **tidak mengambil fokus keyboard** |
| PRT-01 | Empat platform | Build sukses Windows, macOS, Android, iOS dari satu basis kode |
| KDL-01 | Jalan tanpa internet setelah aktif | Metrik disimpan **setiap 60 detik**; data hilang ≤ **1 menit** saat crash |
| KDL-02 | Hemat baterai mobile | **Pemantauan berhenti saat layar mati**; baterai ≤ **10%/jam** |
| PML-01 | Mudah dirawat & diuji | **Modul CV terpisah dari UI**; **cakupan unit test ≥ 70%** untuk modul CV & aturan kredit |
| KSL-01 | Jujur soal batas kemampuan | **Penafian "bukan alat medis"** tampil saat onboarding |

---

## 7. Antarmuka Pengguna [SRS 3.1]

### 7.1 Elemen utama
- Dashboard: tombol **Mulai/Stop**, BR, jarak, **meteran skor kelelahan**, status kuota & kredit.
- **Pop-up pengingat desktop** di **pojok kanan bawah**, **tanpa mengambil fokus keyboard**.
- **Notifikasi sistem mobile** dengan tombol aksi **Tunda**.
- **Menu system tray desktop**: jeda, lanjut, buka Dashboard.
- **Indikator "kamera aktif"** selalu terlihat saat kamera menyala.

### 7.2 Standar tampilan
Bersih, minimalis, huruf sans-serif. **Hijau = Normal, Kuning = Waspada, Merah = Lelah**, dan **setiap status wajib punya label teks** (tidak bergantung warna). Mendukung **mode terang & gelap**.

### 7.3 Daftar layar

| Kode | Layar | Platform | Isi utama |
|---|---|---|---|
| S-01 | Login & Registrasi | Semua | Form login, daftar, lupa kata sandi |
| S-02 | Onboarding Privasi | Semua | Penjelasan pemrosesan on-device, penafian medis, izin kamera |
| S-03 | Kalibrasi | Semua | Pratinjau kamera, panduan posisi, hitung mundur |
| S-04 | Dashboard | Semua | Mulai/Stop, BR, jarak, skor, status kredit |
| S-05 | Pop-up Pengingat | Desktop | Pesan, tombol **Oke** & **Tunda**, hitung mundur 20 detik |
| S-06 | Notifikasi Pengingat | Mobile | Notifikasi sistem dengan aksi Tunda |
| S-07 | Sesi Cek Mata | Mobile | Teks bacaan 2 menit, hasil skor & saran |
| S-08 | Statistik | Semua | Ringkasan hari ini & grafik tren |
| S-09 | Kredit & Pembayaran | Semua | Saldo, kuota gratis, paket, riwayat transaksi |
| S-10 | Pengaturan | Semua | Sensitivitas, jenis pengingat, interval, autostart, hapus akun |
| S-11 | Menu System Tray | Desktop | Status, jeda/lanjut, buka Dashboard, keluar (+ Mode Fokus, Logout) |
| A-01..A-03 | Panel Admin | Web (Filament) | Paket kredit, transaksi, pengguna & penyesuaian kredit |

### 7.4 Navigasi & aksesibilitas
Menu utama: **Dashboard, Statistik, Kredit, Pengaturan**. Tiap pengingat ditutup dengan satu klik/ketuk. Ukuran huruf mengikuti pengaturan OS.

### 7.5 Dokumentasi pengguna [SRS 2.6]
1. **Onboarding** (saat pertama buka): privasi, penafian medis, panduan kalibrasi langkah demi langkah.
2. **User Manual**: cara mulai pemantauan, arti angka (BR, jarak, skor), merespons pengingat, membeli kredit.
3. **Bantuan dalam aplikasi**: ikon bantuan di setiap layar.
4. **FAQ**: mis. kenapa kamera tidak aktif, kenapa jarak tidak akurat, cara hitung kuota gratis.
5. **Panduan Admin**: kelola paket, baca transaksi, penyesuaian kredit.

---

## 8. Aturan Bisnis (WAJIB dipatuhi)

### 8.1 Freemium & kredit [SRS 2.1, SDD 2.3, 3.3]
- **Mode Timer**: gratis **tanpa batas**, tanpa kamera.
- **Fitur kamera** (pemantauan AI & Sesi Cek Mata): **kuota gratis 2 Hari Pemantauan AI per bulan** (bulan berjalan).
- Setelah kuota habis: **1 kredit = 1 Hari Pemantauan AI**. Kredit dibeli via paket Midtrans.
- Hari Pemantauan = **satu hari kalender 00.00–23.59 menurut `users.timezone`**.
- **Satu hari satu aktivasi**: `UNIQUE(user_id, day)` di `monitoring_days` → kredit tak terpotong dua kali di hari yang sama. Jeda lalu lanjut di hari yang sama **tidak memotong kredit lagi** (UC-10).
- Aktivasi dicatat dengan `source = free | credit` dan `device_id` perangkat pertama yang mengaktifkan.

### 8.2 Algoritma aktivasi hari (DFD L3 5.2, Activity 4.7) — urutan pemeriksaan
1. **5.2.1** Tentukan tanggal hari ini dari **zona waktu akun** (D1).
2. **5.2.2** Hari ini sudah aktif? → **Ya**: kembalikan status aktif (tidak memotong apa pun).
3. **5.2.3** Belum aktif → cek **kuota gratis bulan ini** (jumlah `monitoring_days` dengan `source='free'` di bulan berjalan < 2).
   - Tersedia → **5.2.5** catat hari aktif `source='free'`.
4. **5.2.4** Kuota habis → cek **saldo kredit** (SUM `credit_ledger.delta`) ≥ 1.
   - Cukup → **5.2.5** catat hari aktif `source='credit'` **dan** insert ledger `usage` **delta = −1** (dengan `monitoring_day_id`).
   - Tidak cukup → **HTTP 402 "kredit tidak cukup"** → app menawarkan **beli kredit atau Mode Timer**.
5. Response sukses: **200 OK + sisa kuota dan saldo**.
- Alur alternatif: **offline & hari belum aktif → Mode Timer**; **kamera dipakai app lain → Mode Timer dan coba kamera lagi tiap 60 detik**.

### 8.3 Ledger kredit [SDD 3.3]
- **Saldo tidak disimpan sebagai satu angka**; saldo = `SUM(delta)` seluruh baris `credit_ledger` milik user (`User::creditBalance()`).
- `credit_ledger` **append-only** (tidak boleh UPDATE/DELETE) → jejak audit.
- `reason ∈ {purchase, usage, adjustment}`.
- `order_id` **UNIQUE** → notifikasi Midtrans berulang **tidak** menambah kredit dua kali (idempoten).
- `note` **wajib** untuk `adjustment`.
- Saldo hanya dihitung di **server** (KMN-03).

### 8.4 Pembayaran Midtrans [UC-19, Seq 4.25, Activity 4.11]
1. User pilih paket → `POST /orders` → server buat `order_code` + total harga, insert order **status `pending`**.
2. Server buat transaksi **Snap** → terima `snap_token` → kirim `snap_token + order_code` ke app.
3. App tampilkan halaman pembayaran Midtrans (QRIS / e-wallet / VA).
4. Midtrans kirim **HTTP notification** ke server → **verifikasi signature key (SHA-512)**.
   - Signature **tidak valid** → tolak & **catat log**.
   - Valid & status **`settlement`** → `UPDATE orders.status='settlement'` (+ `paid_at`, `payment_type`) dan `INSERT credit_ledger (+kredit, reason='purchase', order_id)`.
   - Valid & status **`expire`/`cancel`** (atau `deny`) → update status order, **tanpa** penambahan kredit.
   - Balas **200 OK** ke Midtrans.
5. App memuat ulang `GET /credits/status` → tampilkan saldo baru.
- Notifikasi terlambat → order tetap "menunggu pembayaran"; user dapat memuat ulang status.
- **Kredit hanya bertambah setelah notifikasi `settlement` dengan signature valid**.
- Status order yang mungkin: `pending, settlement, expire, cancel, deny`.

### 8.5 Penyesuaian kredit admin [UC-24, Seq 4.30]
- Input: `user_id`, `delta` (positif/negatif), `note` (alasan).
- **Alasan kosong → tolak.** **Saldo akhir negatif → tolak.**
- Valid → `INSERT credit_ledger (reason='adjustment', note=...)` → tampilkan saldo terbaru.
- Admin **hanya** bisa mengubah kredit lewat entri ledger (tidak edit saldo langsung).

### 8.6 Paket kredit [UC-22]
- Field: nama, jumlah kredit, harga (IDR), status aktif.
- Hanya paket `is_active=true` tampil di app.
- **Paket yang pernah dibeli tidak boleh dihapus, hanya dinonaktifkan.**

### 8.7 Akun & keamanan
- Registrasi: validasi format, email unik (**422** jika sudah dipakai → sarankan login/reset), hash bcrypt, **201 Created + token**, arahkan ke **onboarding privasi**.
- Login: **401** jika kredensial salah; **5× gagal berturut-turut → tahan 5 menit**; sukses → token Sanctum + catat perangkat (`devices`, `last_seen_at`) → **ke kalibrasi jika belum pernah kalibrasi, else Dashboard**; admin → panel admin.
- Reset sandi: token reset **berlaku 60 menit**; email tak terdaftar → **404**; token kedaluwarsa/invalid → **422**; sandi baru diisi **dua kali**.
- Logout: hentikan pemantauan, simpan metrik terakhir, cabut token perangkat. Offline → hapus token lokal, cabut di server saat online.
- Hapus akun (sesuai UU PDP): peringatan data & **sisa kredit hilang**; verifikasi kata sandi (**403** jika salah); hapus akun, perangkat, statistik; **lepas identitas dari data transaksi** (anonimisasi, bukan hapus order); cabut semua token; hapus data lokal (kalibrasi, metrik, pengaturan); kembali ke login.

### 8.8 Privasi
- Tidak ada tabel yang menyimpan gambar/video wajah (server maupun lokal).
- Penjelasan privasi + penafian medis sebelum kamera pertama aktif; tolak → **Mode Timer**; izin dapat diberikan kembali dari Pengaturan.
- Indikator kamera aktif selalu tampil.

---

## 9. Algoritma CV Engine [SDD 2.5]

### 9.1 Umum
- Resolusi proses **640×480**; **15 fps desktop, 10 fps mobile**.
- Frame **tidak valid** jika wajah tak terdeteksi **atau** kepala menoleh **> 30°** (yaw).
- Pipeline (DFD L2 3.0): **3.1** ambil & perkecil frame → **3.2** deteksi wajah & 478 landmark + yaw → **3.3** validasi wajah → **3.4** analisis kedipan (landmark mata + baseline/ambang dari D3) & **3.5** estimasi jarak (landmark iris + focal dari D3) → **3.6** skor kelelahan → **3.7** simpan metrik per menit ke D4. Jarak & skor real-time juga ditampilkan ke pengguna.

### 9.2 Deteksi kedipan (EAR) [SDD 2.5.1, Tabel 2.4, DFD L3 3.4]
```
EAR = ( ‖p2 − p6‖ + ‖p3 − p5‖ ) / ( 2 · ‖p1 − p4‖ )
p1, p4 = sudut mata; p2, p3 = kelopak atas; p5, p6 = kelopak bawah
```
| Parameter | Nilai awal |
|---|---|
| Landmark mata kanan p1..p6 | **33, 160, 158, 133, 153, 144** |
| Landmark mata kiri p1..p6 | **362, 385, 387, 263, 373, 380** |
| EAR yang dipakai | Rata-rata kiri & kanan, **dihaluskan rata-rata 3 frame** |
| Baseline EAR | **Median** EAR selama kalibrasi **10 detik** |
| Ambang mata tertutup τ | **0,7 × baseline** (diatur via sensitivitas) |
| Satu kedipan | EAR < τ selama **100–400 ms** |
| Tertutup > 400 ms | "Mata tertutup panjang" (bukan kedipan; masuk PERCLOS) |
| Blink rate (BR) | Jumlah kedipan dalam **60 detik terakhir**; **tidak dilaporkan jika frame valid < 70%** |
| PERCLOS | Proporsi **frame valid** dengan EAR < τ dalam **60 detik terakhir** |

Sub-proses: 3.4.1 EAR per mata → 3.4.2 haluskan (rata-rata 3 frame) → 3.4.3 bandingkan dengan τ → 3.4.4 klasifikasi durasi tertutup (kedip / tertutup panjang) → 3.4.5 BR & PERCLOS 60 detik.
*Indeks landmark perlu diverifikasi ulang terhadap MediaPipe saat implementasi.*

### 9.3 Estimasi jarak (iris) [SDD 2.5.2, DFD L3 3.5]
```
d = f · D_iris / w_iris          (d dalam mm)
f = d_ref · w_ref / D_iris       (kalibrasi)
D_iris = 11,7 mm
w_iris = rata-rata jarak landmark 469→471 (iris kanan) dan 474→476 (iris kiri), dalam piksel
d_ref = 500 mm (desktop) | 300 mm (mobile)
```
- Sub-proses: 3.5.1 ambil titik tepi iris → 3.5.2 lebar iris (px) → **3.5.3 haluskan dengan median 1 detik** → 3.5.4 hitung jarak (cm) → 3.5.5 bandingkan dengan ambang jarak → status "terlalu dekat" ke 4.1.
- **Kalibrasi dilewati** → f diperkirakan dari lebar frame dengan asumsi **FOV kamera 60°**: `f = (W/2) / tan(30°)` (lebih cepat, kurang akurat).

### 9.4 Skor kelelahan [SDD 2.5.3, Tabel 2.5]
```
S = 100 · ( 0,5·s_BR + 0,3·s_P + 0,2·s_T )
s_BR = clamp((15 − BR) / 10, 0, 1)   → 0 bila BR ≥ 15/menit, 1 bila BR ≤ 5/menit
s_P  = clamp(PERCLOS / 0,15, 0, 1)   → 1 bila mata tertutup ≥ 15% waktu
s_T  = clamp(T / 60, 0, 1)           → T = menit menatap layar tanpa istirahat
```
- Level: **0–39 Normal**, **40–59 Waspada**, **60–100 Lelah**.
- Dihitung **setiap 10 detik** (PMT-04, Seq 4.22). `FatigueScorer.score(br, perclos, minutes): int`.
- Pendekatan rule-based dipilih karena mudah dijelaskan & tanpa data latih; versi berikutnya bisa diganti model klasifikasi dari data kuesioner.

### 9.5 Aturan pengingat [SDD 2.5.4, Tabel 2.6, UC-13]
Urutan tabel = **urutan prioritas**. Bila beberapa kondisi terjadi bersamaan → **hanya satu** pengingat (prioritas tertinggi).

| Prioritas | Pengingat | Kondisi pemicu | Cooldown | Contoh pesan |
|---|---|---|---|---|
| 1 | **Istirahat** | S ≥ 60 | **20 menit** | "Mata tampak lelah. Istirahat 5 menit, yuk." |
| 2 | **Jarak** | Jarak < **50 cm (desktop)** / **30 cm (mobile)** selama **10 detik** | **5 menit** | "Posisi terlalu dekat, mundur sedikit." |
| 3 | **Kedip** | BR < **10/menit** selama **3 menit** | **10 menit** | "Kedipkan mata perlahan 10 kali." |
| 4 | **20-20-20** | **20 menit** menatap layar tanpa jeda | Terjadwal | "Lihat objek sejauh 6 meter selama 20 detik." |

- Kandidat pengingat dicek terhadap **cooldown & status tunda/Mode Fokus** sebelum tampil (DFD 4.2).
- Respons pengguna: **Oke / Tunda**; tidak direspons → **pop-up hilang setelah 15 detik**, dicatat **diabaikan** (`dismissed`). Nilai `alerts.action`: `followed | snoozed | dismissed`.
- Pengingat tidak tampil saat **Mode Fokus** aktif atau izin notifikasi dimatikan.
- Interval 20-20-20 & ambang/sensitivitas diambil dari **D10 Pengaturan**.

### 9.6 Verifikasi istirahat 20-20-20 [UC-14, Seq 4.23]
- Hitung mundur **20 detik**; FaceAnalyzer memantau keberadaan wajah & sudut kepala.
- **Terverifikasi** jika wajah **tidak terdeteksi** atau **berpaling > 30°** selama **≥ 15 dari 20 detik**; selain itu "tidak terverifikasi".
- Simpan catatan istirahat (D5), **reset timer 20 menit**.
- Mode Timer (tanpa kamera): langkah verifikasi dilewati.

### 9.7 Penundaan & Mode Fokus [UC-15, PNG-06]
- Tunda **15 / 30 / 60 menit** dari pengingat, atau **Mode Fokus** dari system tray (pilih durasi).
- Semua pengingat ditahan selama durasi; aktif lagi otomatis setelahnya; Mode Fokus bisa diakhiri lebih cepat.

---

## 10. Alur Sistem per Use Case [SRS 4.2 + SDD 4.2/4.3]

### 10.1 Relasi use case [SRS 4.1]
- `Kalibrasi Mata` & `Kalibrasi Jarak` **<<include>>** `Menyetujui Privasi & Izin Kamera`.
- `Memulai Pemantauan AI` & `Sesi Cek Mata` membutuhkan `Mengaktifkan Hari Pemantauan AI` (<<include>>; diagram juga menarik garis include dari `Menghentikan Pemantauan`).
- `Menunda Pengingat/Mode Fokus` & `Melakukan Istirahat 20-20-20` **<<extend>>** `Menerima & Merespons Pengingat`.
- Use case admin (`Mengelola Paket Kredit`, `Melihat Data Pengguna & Transaksi`, `Menyesuaikan Kredit Manual`) **<<include>>** `Login`.
- `Membeli Paket Kredit` melibatkan aktor **Midtrans**; `Reset Kata Sandi` melibatkan **Layanan Email**.

### 10.2 Daftar use case (24)

| UC | Nama | Aktor | Prasyarat | Alur utama (ringkas) | Alternatif | Sukses / Gagal |
|---|---|---|---|---|---|---|
| UC-01 | Registrasi | Pengguna | Belum punya akun, online | Isi nama/email/sandi → validasi & cek email → simpan hash → token → onboarding privasi | Format invalid → error per kolom; email terdaftar → sarankan login/reset | Akun dibuat / gagal: invalid, email terpakai, koneksi putus |
| UC-02 | Login | Pengguna, Admin | Akun aktif | Email+sandi → validasi → token + catat perangkat → Dashboard (atau Kalibrasi jika belum) / admin ke panel | Salah → pesan gagal; 5× gagal → tahan 5 menit | Masuk / gagal: kredensial salah atau akun dihapus |
| UC-03 | Reset Kata Sandi | Pengguna (+Email) | Akun dengan email aktif | "Lupa kata sandi" → email → token 60 menit + kirim tautan → sandi baru 2× → simpan | Email tak terdaftar → pesan; tautan kedaluwarsa → minta kirim ulang | Sandi berganti / gagal |
| UC-04 | Logout | Pengguna, Admin | Sedang login | Menu profil/tray → Logout → hentikan pemantauan & simpan metrik → cabut token → halaman login | Offline → hapus token lokal, cabut di server saat online | Keluar / dibatalkan |
| UC-05 | Hapus Akun | Pengguna | Login, online | Pengaturan → Hapus Akun → peringatan → sandi + konfirmasi → hapus server & anonimkan transaksi → hapus lokal → login | Sandi salah → gagal; batal → tidak ada yang dihapus | Terhapus / gagal |
| UC-06 | Setujui Privasi & Izin Kamera | Pengguna | Login, pertama kali fitur kamera | Penjelasan privasi + penafian → Setuju → izin kamera OS → izinkan → kalibrasi mata | Tidak setuju/tolak izin → **Mode Timer**; izin bisa dari Pengaturan | Izin diberikan / ditolak |
| UC-07 | Kalibrasi Mata | Pengguna | Setuju privasi, izin kamera | Pratinjau + panduan → duduk tegak → rekam EAR 10 dtk → baseline & ambang → simpan lokal | Wajah tak terdeteksi/cahaya kurang → instruksi & ulang | Ambang tersimpan / batal |
| UC-08 | Kalibrasi Jarak | Pengguna | Kalibrasi mata selesai | Ukur jarak acuan dgn penggaris → posisikan → ukur iris 5 dtk → hitung & simpan f → pesan berhasil | Belum stabil → ulang; lewati → perkiraan FOV | f tersimpan / tidak |
| UC-09 | Mulai Pemantauan AI | Pengguna | Login, kalibrasi, izin kamera | Mulai → cek status hari ke server → kuota/kredit (§8.2) → nyalakan kamera & muat model → tampil BR/jarak/skor → jalan di latar belakang | Kuota & kredit habis → tawarkan beli/Mode Timer; offline & belum aktif → Mode Timer; kamera dipakai app lain → Mode Timer + coba ulang tiap 60 dtk | Berjalan & hari tercatat / gagal |
| UC-10 | Hentikan Pemantauan | Pengguna | Sedang berjalan | Stop/Jeda (Dashboard/tray) → matikan kamera → simpan metrik & ringkasan sesi → tampilkan status | Jeda → lanjut di hari sama tanpa potong kredit | Tersimpan / maks 1 menit data hilang jika force close |
| UC-11 | Sesi Cek Mata (Mobile) | Pengguna | Login mobile, kalibrasi | Menu → cek status hari (`GET /credits/status`) → teks bacaan + hitung mundur 2 menit → ukur BR, PERCLOS, jarak rata-rata → skor + saran | Hari belum aktif → arahkan aktivasi; keluar < 2 menit → batal, tak disimpan | Skor + saran / batal / wajah tak terdeteksi |
| UC-12 | Mode Timer 20-20-20 | Pengguna | Login | Pilih/otomatis → timer 20 menit → pengingat 20-20-20 + hitung mundur 20 dtk → ulang | Tunda / Mode Fokus | Muncul berkala / izin notifikasi mati |
| UC-13 | Terima & Respons Pengingat | Pengguna | Pemantauan AI berjalan | Kondisi berisiko (§9.5) → cek cooldown → pop-up/notifikasi → Oke/Tunda → catat | Bersamaan → satu prioritas tertinggi; tak direspons 15 dtk → hilang, "diabaikan" | Tercatat / Mode Fokus atau notifikasi mati |
| UC-14 | Istirahat 20-20-20 | Pengguna | Pengingat 20-20-20 muncul | Hitung mundur 20 dtk → lihat 6 m → pantau wajah & sudut → ≥15 dtk berpaling = terverifikasi → simpan & reset timer | Tidak berpaling → tidak terverifikasi; Mode Timer → lewati verifikasi | Tercatat / app ditutup |
| UC-15 | Tunda / Mode Fokus | Pengguna | Pemantauan AI atau Mode Timer berjalan | Tunda di pengingat / Mode Fokus di tray → pilih durasi → tahan semua pengingat → aktif lagi | Akhiri lebih cepat | Tertahan / tak tersimpan jika app ditutup |
| UC-16 | Ringkasan Harian | Pengguna | Login | Menu Statistik → hitung dari data lokal → sinkron jika online → tampil | Belum ada data → pesan; offline → data lokal | Tampil / data lokal rusak |
| UC-17 | Grafik Tren | Pengguna | Login, data ≥ 2 hari | Tab Tren → pilih 7/30 hari → ambil dari server → grafik | Offline → data lokal; < 2 hari → "data belum cukup" | Tampil / gangguan server |
| UC-18 | Saldo & Kuota | Pengguna | Login | Menu Kredit → status ke server → tampil kuota, saldo, status hari | Offline → data terakhir + waktu pembaruan | Tampil / tak ada data |
| UC-19 | Beli Paket Kredit | Pengguna, Midtrans | Login, online | §8.4 | Expire/cancel → tanpa kredit; notifikasi telat → "menunggu", bisa muat ulang | Saldo bertambah / tidak berubah |
| UC-20 | Riwayat Transaksi | Pengguna | Login | Kredit → Riwayat → ambil order & mutasi → tampil tanggal, paket, nominal, status, pemakaian | Belum ada → "belum ada riwayat" | Tampil / gangguan jaringan |
| UC-21 | Preferensi Pengingat | Pengguna | Login | Pengaturan → ubah sensitivitas (**Rendah/Sedang/Tinggi**), jenis pengingat (**pop-up, notifikasi, suara**), interval, autostart → validasi → simpan (`settings` lokal) → **langsung diterapkan** (RuleEngine & timer dimuat ulang); autostart → daftar ke startup OS (desktop) | Invalid → pesan; reset ke bawaan | Tersimpan / tidak |
| UC-22 | Kelola Paket Kredit | Admin | Login panel | Menu Paket → tambah/ubah/nonaktifkan → isi nama, kredit, harga → validasi & simpan → paket aktif tampil di app | Invalid → error; paket pernah dibeli hanya bisa dinonaktifkan | Tersimpan / invalid |
| UC-23 | Lihat Pengguna & Transaksi | Admin | Login panel | Menu Pengguna/Transaksi → filter status & tanggal → daftar → detail | Tak ada data → tabel kosong + keterangan | Tampil / gangguan server |
| UC-24 | Sesuaikan Kredit Manual | Admin | Login, buka detail pengguna | Isi delta & alasan → validasi alasan & saldo akhir → simpan ledger `adjustment` → saldo terbaru | Alasan kosong → tolak; saldo akhir negatif → tolak | Tercatat / ditolak |

### 10.3 Alur kunci (detail dari activity & sequence diagram)

**Kalibrasi (Seq 4.20, Activity 4.6)**
Setujui privasi & izin → `CalibrationService.mulaiKalibrasi()` → `CameraSource.start()` → loop **10 detik**: frame → `FaceAnalyzer` → landmark mata → hitung **baseline EAR & ambang** → minta duduk di jarak acuan → loop **sampai wajah stabil** (ukur iris **5 detik**; tidak stabil → ulang) → ukur lebar iris (px) → hitung **focal length** → simpan ke **DB lokal (`calibrations`)** → "kalibrasi berhasil" → Dashboard. Tidak setuju/izin ditolak → Mode Timer.

**Memulai pemantauan (Seq 4.21)**
`UI Dashboard → MonitoringSession.start() → CreditService.activateToday() → POST /monitoring-days/activate → MonitoringDayController` (cek hari aktif, kuota, saldo) → **402** kredit tidak cukup (tawarkan beli/Mode Timer) **atau** catat hari aktif → **200 OK + sisa kuota & saldo** → `CameraSource.start()` → tampilkan BR, jarak, skor.

**Deteksi & pengingat (Seq 4.22, Activity 4.8)**
- Loop **setiap frame (15 fps)**: `CameraSource → FaceAnalyzer.analyze(frame) → FaceResult`; **opt wajah valid**: `BlinkAnalyzer.update(FaceResult)`, `DistanceEstimator.update(FaceResult)`; tidak valid → tandai frame tidak valid.
- Loop **setiap 10 detik**: `blinkRate()`, `perclos()`, `distanceCm()` → `FatigueScorer.score(BR, PERCLOS, menit)` → `RuleEngine.evaluate(metrik)` → **opt ambang terlampaui & cooldown selesai**: `ReminderService.show(pengingat)` → pop-up → Oke/Tunda → catat pengingat & respons.
- `MetricsRepository.saveSample()` **tiap 60 detik**.
- Pemantauan berhenti → matikan kamera & simpan ringkasan sesi.

**20-20-20 (Seq 4.23)**: `TimerService` hitung waktu layar kontinu → 20 menit → `ReminderService` (pengingat + hitung mundur 20 dtk) → loop 20 dtk status wajah & sudut kepala dari `FaceAnalyzer` → berpaling ≥ 15 dtk → `MetricsRepository` catat terverifikasi / tidak → reset timer 20 menit.

**Sesi Cek Mata (Seq 4.24)**: `CreditService.status() → GET /credits/status` → belum aktif → arahkan ke aktivasi; aktif → teks bacaan 2 menit → `MonitoringSession.startCheck(120 detik)` → ukur BR, PERCLOS, jarak rata-rata → skor → tampilkan skor & saran.

**Statistik & sinkronisasi (Seq 4.26, Activity 4.12)**: `MetricsRepository.dailySummary(hari ini)` → **online**: `SyncService.syncPending() → POST /stats/daily` → `StatsController` **upsert** `daily_stats` → 200 → tandai `synced = true` → `GET /stats (7/30 hari)` → SELECT rentang tanggal → grafik tren; **offline**: tampilkan ringkasan lokal saja.

**Hapus akun (Seq 4.28)**: `DELETE /me` + kata sandi → `AccountController` cek hash → **403** jika salah → hapus akun, perangkat, statistik → lepas identitas dari transaksi → cabut semua token → **200 OK** → app hapus kalibrasi, metrik, pengaturan lokal → halaman login.

**Admin paket (Seq 4.29)**: Filament `CreditPackageResource.index()` → SELECT paket → tambah/ubah/nonaktifkan → `save(data)` → validasi → INSERT/UPDATE → konfirmasi; daftar paket di app ikut diperbarui.

**Admin penyesuaian (Seq 4.30)**: `CreditAdjustmentController.store(user_id, delta, note)` → hitung saldo saat ini → validasi alasan & saldo akhir → INSERT ledger `reason='adjustment'` → saldo terbaru.

---

## 11. REST API

> Path di bawah diambil dari sequence diagram SDD. Prefix Laravel default adalah `/api` (mis. `/api/auth/login`). Semua JSON, HTTPS, dan **wajib token Sanctum** kecuali yang ditandai *publik*.

### 11.1 Endpoint yang tertulis di SDD

| Method | Path | Controller | Auth | Fungsi | Respons yang ditentukan |
|---|---|---|---|---|---|
| POST | `/auth/register` | AuthController | publik | Registrasi (UC-01) | **201 Created + token**; **422** email sudah dipakai |
| POST | `/auth/login` | AuthController | publik | Login + catat perangkat (UC-02) | **200 OK + token**; **401 Unauthorized** |
| POST | `/auth/forgot-password` | AuthController | publik | Buat token reset 60 menit + kirim email (UC-03) | **404** email tidak ditemukan; sukses → email terkirim |
| POST | `/auth/reset-password` | AuthController | publik | Validasi token, update hash sandi | **200 OK**; **422** token tidak valid/kedaluwarsa |
| POST | `/monitoring-days/activate` | MonitoringDayController | token | Aktivasi Hari Pemantauan AI (§8.2) | **200 OK + sisa kuota & saldo**; **402** kredit tidak cukup |
| GET | `/credits/status` | (CreditController) | token | Kuota gratis, saldo, status hari ini (UC-18, UC-11, setelah bayar) | status hari ini + saldo |
| POST | `/orders` | OrderController | token | Buat order pending + Snap token (UC-19) | `snap_token` + `order_code` |
| POST | *(notifikasi Midtrans)* | PaymentNotificationController | publik, **wajib verifikasi signature SHA-512** | Proses status pembayaran (§8.4) | **200 OK** ke Midtrans |
| POST | `/stats/daily` | StatsController | token | Upsert ringkasan harian | **200 OK** |
| GET | `/stats` | StatsController | token | Data tren rentang **7 / 30 hari** | data tren |
| DELETE | `/me` | AccountController | token | Hapus akun (UC-05), body berisi kata sandi | **200 OK**; **403** verifikasi gagal |

### 11.2 Endpoint yang dibutuhkan use case tetapi path-nya belum ditulis di SDD
*(Nama path di bawah adalah usulan; konfirmasikan dulu sebelum dianggap final.)*

| Usulan | Kebutuhan |
|---|---|
| `POST /auth/logout` | UC-04 cabut token perangkat |
| `GET /credit-packages` | UC-19 daftar paket aktif |
| `GET /orders` + mutasi ledger (mis. `GET /credits/history`) | UC-20 / KRD-04 riwayat transaksi & pemakaian |
| `POST /payments/midtrans/notification` | Endpoint notifikasi Midtrans |
| `GET /me` | Profil/role (opsional) |

Panel admin **tidak** memakai REST app — dibangun dengan **Filament** (`CreditPackageResource`, `CreditAdjustmentController`, resource Pengguna & Transaksi dengan filter status & tanggal).

---

## 12. Basis Data

### 12.1 Penyimpanan data (DFD) [SDD Tabel 2.2]

| Kode | Nama | Lokasi | Isi |
|---|---|---|---|
| D1 | Pengguna | Server | nama, email, hash sandi, zona waktu |
| D2 | Perangkat | Server | perangkat yang dipakai login |
| D3 | Kalibrasi | Lokal | baseline EAR, ambang kedip, focal length |
| D4 | Metrik Sesi | Lokal | BR, PERCLOS, jarak, skor per menit |
| D5 | Riwayat Pengingat | Lokal | jenis pengingat & respons |
| D6 | Hari Pemantauan | Server | tanggal aktif & sumber (gratis/kredit) |
| D7 | Ledger Kredit | Server | semua mutasi kredit |
| D8 | Order | Server | transaksi pembelian kredit |
| D9 | Paket Kredit | Server | daftar paket & harga |
| D10 | Pengaturan | Lokal | sensitivitas, jenis pengingat, interval |
| D11 | Statistik Harian | Server | ringkasan harian hasil sinkronisasi |

### 12.2 Server — MySQL 8 [SDD 3.3 a, Gambar 3.1, Tabel 3.2–3.8]

**users**
| Kolom | Tipe | Ket. |
|---|---|---|
| id | BIGINT PK | |
| name | VARCHAR(100) | |
| email | VARCHAR(150) **UNIQUE** | login |
| password_hash | VARCHAR(255) | bcrypt |
| role | ENUM('user','admin') | |
| timezone | VARCHAR(50) | menentukan tanggal hari pemantauan |
| created_at | DATETIME | |

**devices**
| Kolom | Tipe | Ket. |
|---|---|---|
| id | BIGINT PK | |
| user_id | BIGINT FK → users | |
| platform | VARCHAR(20) | `windows`, `macos`, `android`, `ios` |
| device_name | VARCHAR(100) | |
| last_seen_at | DATETIME | |

**credit_packages**
| Kolom | Tipe | Ket. |
|---|---|---|
| id | BIGINT PK | |
| name | VARCHAR(50) | |
| credits | INT | |
| price_idr | INT | |
| is_active | BOOLEAN | tampil di app |

**orders**
| Kolom | Tipe | Ket. |
|---|---|---|
| id | BIGINT PK | |
| user_id | BIGINT FK → users | pembeli (dilepas identitasnya saat hapus akun) |
| package_id | BIGINT FK → credit_packages | |
| order_code | VARCHAR(40) **UNIQUE** | dikirim ke Midtrans |
| amount_idr | INT | |
| status | VARCHAR(20) | `pending`, `settlement`, `expire`, `cancel`, `deny` |
| payment_type | VARCHAR(30) | |
| paid_at | DATETIME | |

**credit_ledger** (append-only)
| Kolom | Tipe | Ket. |
|---|---|---|
| id | BIGINT PK | |
| user_id | BIGINT FK → users | |
| delta | INT | + / − |
| reason | ENUM('purchase','usage','adjustment') | |
| order_id | BIGINT FK → orders, **UNIQUE** | untuk purchase (idempoten) |
| monitoring_day_id | BIGINT FK → monitoring_days | untuk usage |
| note | VARCHAR(255) | **wajib** untuk adjustment |
| created_at | DATETIME | |

**monitoring_days**
| Kolom | Tipe | Ket. |
|---|---|---|
| id | BIGINT PK | |
| user_id | BIGINT FK → users | |
| day | DATE | **UNIQUE(user_id, day)** |
| source | ENUM('free','credit') | |
| device_id | BIGINT FK → devices | perangkat yang pertama mengaktifkan |
| activated_at | DATETIME | |

**daily_stats**
| Kolom | Tipe | Ket. |
|---|---|---|
| id | BIGINT PK | |
| user_id | BIGINT FK → users | |
| device_id | BIGINT FK → devices | |
| day | DATE | **UNIQUE(user_id, device_id, day)** |
| screen_minutes | INT | |
| avg_blink_rate | FLOAT | |
| avg_distance_cm | FLOAT | |
| avg_fatigue_score | FLOAT | |
| alerts_count | INT | |
| breaks_taken | INT | |

**Relasi** (Gambar 3.1 & 4.2): User 1–* Device, Order, CreditLedger, MonitoringDay, DailyStat · CreditPackage 1–* Order · Order 1–0..1 CreditLedger (menambah) · MonitoringDay 1–0..1 CreditLedger (memotong) · Device 1–* DailyStat · Device 1–* MonitoringDay.

**Prinsip DB server** [SDD 3.3]: tanpa data gambar; saldo dari ledger; unik (user_id, day); `order_id` unik di ledger; bcrypt; **backup DB terjadwal setiap hari**.

### 12.3 Lokal — SQLite via drift [SDD 3.3 b, Gambar 3.2, Tabel 3.9]

| Tabel | Kolom | Keterangan |
|---|---|---|
| **calibrations** | `id INTEGER PK`, `camera_id TEXT`, `ear_baseline REAL`, `focal_px REAL`, `created_at TEXT` | Per kamera; **dibuat ulang saat kamera diganti** |
| **sessions** | `id INTEGER PK`, `mode TEXT ('ai','timer','check')`, `started_at TEXT`, `ended_at TEXT` | Satu baris tiap pemantauan dimulai |
| **metric_samples** | `id INTEGER PK`, `session_id INTEGER FK→sessions`, `ts TEXT`, `blink_rate REAL`, `perclos REAL`, `distance_cm REAL`, `fatigue_score INTEGER`, `valid_ratio_pct INTEGER` | Per menit; **dihapus otomatis setelah 30 hari** |
| **alerts** | `id INTEGER PK`, `session_id INTEGER FK→sessions`, `ts TEXT`, `type TEXT`, `action TEXT` | `action`: `followed`, `snoozed`, `dismissed` |
| **daily_summaries** | `day TEXT PK`, `screen_minutes INTEGER`, `avg_blink_rate REAL`, `avg_distance_cm REAL`, `avg_fatigue_score REAL`, `alerts_count INTEGER`, `breaks_taken INTEGER`, `synced INTEGER` | `synced` menandai sudah terkirim |
| **settings** | `key TEXT PK`, `value TEXT` | key-value |

Relasi: sessions 1–* metric_samples, sessions 1–* alerts.

---

## 13. Desain Kelas

### 13.1 Klien Flutter [SDD 4.1 a, Gambar 4.1, Tabel 4.1]

| Kelas | Atribut / method (dari diagram) | Tanggung jawab |
|---|---|---|
| `CameraSource` | `-cameraId: String`; `start()`, `stop()`, `frames(): Stream<Frame>` | Nyala/matikan kamera, aliran frame |
| `FaceAnalyzer` *(interface)* | `analyze(frame: Frame): FaceResult` | Deteksi wajah → 478 landmark + sudut kepala |
| `MediaPipeFaceAnalyzer` | `-interpreter: Interpreter`; implements FaceAnalyzer | Implementasi MediaPipe/TFLite |
| `FaceResult` | `landmarks: List<Point3D>`, `yaw: double`, `isValid: bool` | Hasil analisis frame |
| `CalibrationService` | `calibrateEyes(): double`, `calibrateDistance(refMm: int): double`, `save()` | Kalibrasi mata & jarak, simpan |
| `BlinkAnalyzer` | `-earBaseline`, `-threshold`; `update(r: FaceResult)`, `blinkRate(): double`, `perclos(): double` | EAR, BR, PERCLOS |
| `DistanceEstimator` | `-focalPx: double`; `update(r: FaceResult)`, `distanceCm(): double` | Iris → cm |
| `FatigueScorer` | `score(br, perclos, minutes): int` | Skor 0–100 |
| `MonitoringSession` | `-state: SessionState`; `start()`, `pause()`, `resume()`, `stop()` (+ `startCheck(120s)`) | Pusat logika: siklus mulai/jeda/lanjut/berhenti; komposisi Blink/Distance/FatigueScorer |
| `RuleEngine` | `-cooldowns: Map<String, DateTime>`; `evaluate(m: Metrics): List<Reminder>` | Kapan pengingat muncul |
| `TimerService` | `-screenMinutes: int`; `tick()`, `reset()` | Timer 20-20-20 |
| `ReminderService` | `show(r: Reminder)`, `snooze(minutes: int)` | Pop-up/notifikasi & tunda |
| `CreditService` | `status(): CreditStatus`, `activateToday(): ActivationResult` | Status kredit & aktivasi |
| `ApiClient` | `-token: String`; `get(path)`, `post(path, body)` | HTTP ke server |
| `MetricsRepository` | `saveSample(m: Metrics)`, `dailySummary(d: Date): DailySummary` | Metrik lokal |
| `SyncService` | `syncPending()` | Sinkron ringkasan ke server |

**Aturan desain**: `MonitoringSession` bergantung pada **antarmuka `FaceAnalyzer`**, bukan MediaPipe langsung → model bisa diganti & diuji dengan data tiruan.

### 13.2 Model server Laravel [SDD 4.1 b, Gambar 4.2]
- `User` (id, name, email, -passwordHash, role, timezone) + **`freeQuotaRemaining(): int`** (sisa kuota gratis bulan berjalan) + **`creditBalance(): int`** (SUM delta ledger).
- `Device` (id, platform, deviceName, lastSeenAt).
- `CreditPackage` (id, name, credits, priceIdr, isActive).
- `Order` (id, orderCode, amountIdr, status, paymentType, paidAt) + **`markSettled()`**.
- `CreditLedger` (id, delta, reason, note, createdAt).
- `MonitoringDay` (id, day, source, activatedAt).
- `DailyStat` (id, day, screenMinutes, avgBlinkRate, avgDistanceCm, avgFatigueScore, alertsCount, breaksTaken).
- Controller yang disebut: `AuthController`, `AccountController`, `MonitoringDayController`, `OrderController`, `PaymentNotificationController`, `StatsController`, `CreditAdjustmentController`; Filament `CreditPackageResource`.

---

## 14. DFD — Ringkasan Proses [SDD 2.4]

**Level 0**: entitas eksternal Pengguna, Kamera Perangkat, Admin, Midtrans, Layanan Email.
- Pengguna → sistem: data akun, login, kalibrasi, perintah pemantauan, respons pengingat, preferensi, pilihan paket. Sistem → Pengguna: token, metrik real-time, pengingat, statistik, saldo & riwayat transaksi.
- Kamera → sistem: frame video (diproses di perangkat).
- Admin → sistem: data paket kredit, penyesuaian kredit. Sistem → Admin: data pengguna & transaksi.
- Sistem ↔ Midtrans: permintaan transaksi / Snap token, status pembayaran.
- Sistem ↔ Layanan Email: permintaan email reset / status pengiriman.

**Level 1** (7 proses): 1.0 Kelola Akun & Autentikasi · 2.0 Kalibrasi · 3.0 Analisis Mata · 4.0 Kelola Pengingat · 5.0 Kelola Kredit & Pembayaran · 6.0 Kelola Statistik · 7.0 Administrasi.

**Level 2**
- **1.0**: 1.1 Registrasi · 1.2 Login → 1.6 Daftarkan Perangkat (D2) · 1.3 Reset Kata Sandi (→ Layanan Email) · 1.4 Logout (hapus token perangkat) · 1.5 Hapus Akun (hapus D1, D2).
- **2.0**: 2.1 Tampilkan Privasi & Minta Izin → 2.2 Rekam Mata Terbuka (frame 10 dtk) → 2.3 Hitung Baseline & Ambang; 2.4 Ukur Lebar Iris pada Jarak Acuan (frame 5 dtk) → 2.5 Hitung Focal Length → 2.6 Simpan Kalibrasi (D3).
- **3.0**: 3.1 Ambil & Perkecil Frame (640×480) → 3.2 Deteksi Wajah & Landmark (478, yaw) → 3.3 Validasi Wajah → 3.4 Analisis Kedipan / 3.5 Estimasi Jarak → 3.6 Skor → 3.7 Simpan Metrik (D4, per menit).
- **4.0**: 4.1 Evaluasi Aturan (D10 ambang & sensitivitas) → 4.2 Cek Cooldown & Tunda (D5 waktu pengingat terakhir) → 4.3 Tampilkan Pengingat; 4.4 Jalankan Timer 20-20-20 (D10 interval) → 4.3; 4.3 → 4.5 Verifikasi Istirahat → 4.6 Catat Respons (D5).
- **5.0**: 5.1 Tampilkan Saldo & Kuota (D6, D7) · 5.2 Aktivasi Hari (D6, D7) · 5.3 Buat Order (D9 harga, D8 pending, Midtrans) · 5.4 Proses Notifikasi Pembayaran (D8 status) → 5.5 Tambah Kredit (D7) · 5.6 Tampilkan Riwayat Transaksi (D8).
- **6.0**: 6.1 Agregasi Ringkasan Harian (D4 + D5) → 6.2 Sinkronisasi ke Server (upsert D11) / 6.3 Tampilkan Ringkasan Harian; 6.4 Tampilkan Grafik Tren (D11, rentang 7/30 hari).
- **7.0**: 7.1 Kelola Paket Kredit (D9) · 7.2 Lihat Data Pengguna (D1 + saldo D7) · 7.3 Lihat Transaksi (D8) · 7.4 Penyesuaian Kredit (entri adjustment D7).

**Level 3**: 3.4 Analisis Kedipan (§9.2) · 3.5 Estimasi Jarak (§9.3) · 5.2 Aktivasi Hari (§8.2).

---

## 15. Panduan Kepatuhan untuk AI Coding Assistant

1. **Jangan pernah** menulis frame/gambar kamera ke disk, log, cache, atau jaringan.
2. Logika CV hanya di modul CV (tanpa import Flutter UI); UI hanya membaca state (Riverpod).
3. `MonitoringSession` & `CalibrationService` memakai **interface `FaceAnalyzer`**.
4. Semua angka ambang ambil dari konstanta terpusat yang mengikuti §9 (jangan hard-code tersebar).
5. Saldo kredit **selalu** dihitung dari ledger di server; app tidak boleh menyimpan/menghitung saldo sebagai sumber kebenaran.
6. Ledger **append-only**; idempotensi lewat `UNIQUE(order_id)`; aktivasi lewat `UNIQUE(user_id, day)`.
7. Notifikasi Midtrans **wajib** verifikasi signature SHA-512; kredit hanya bertambah pada `settlement`.
8. Indikator "kamera aktif" wajib tampil kapan pun kamera menyala; penafian medis wajib di onboarding.
9. Pengingat: satu sekaligus sesuai prioritas, hormati cooldown, tunda, dan Mode Fokus; pop-up desktop tidak mengambil fokus keyboard; auto-hilang 15 detik.
10. Unit test: cakupan **≥ 70%** untuk modul CV dan aturan kredit (PML-01).

---

## 16. Inkonsistensi & Keputusan Terbuka (temuan saat ekstraksi)

| # | Temuan | Rekomendasi |
|---|---|---|
| 1 | Use Case Diagram Gambar 1 (SRS): garis **Layanan Email** tersambung ke *Login* dan **Admin** ke *Mereset Kata Sandi*, padahal teks UC-03 menyebut Layanan Email untuk reset dan teks gambar menyebut admin hanya memakai Login. | Ikuti **teks**: Email ↔ Reset Kata Sandi, Admin ↔ Login. |
| 2 | Use Case Diagram Gambar 4 (Administrasi): aktor berlabel **"Pengguna"**. | Seharusnya **Admin**. |
| 3 | Gambar 2: `Menghentikan Pemantauan` juga <<include>> `Mengaktifkan Hari Pemantauan AI`, tetapi teks hanya menyebut Mulai Pemantauan & Sesi Cek Mata. | Ikuti teks; menghentikan pemantauan tidak memicu aktivasi. |
| 4 | Pemicu 20-20-20: SDD Tabel 2.6 = "20 menit tanpa jeda", tetapi interval dapat diatur (PGT-01). | 20 menit = nilai bawaan; gunakan nilai dari `settings`. **Diterapkan:** interval 10–60 menit (bawaan 20) di halaman Pengaturan, kunci `interval_202020_min`. |
| 5 | Pemetaan **sensitivitas Rendah/Sedang/Tinggi** ke faktor τ tidak ditentukan (hanya "0,7 × baseline, dapat diatur"). | **Keputusan pengguna (30 Okt 2026): Rendah = 0,65, Sedang = 0,70 (bawaan), Tinggi = 0,75** × baseline EAR. Makin tinggi τ, makin mudah mata dianggap tertutup. Konstanta di `cv_constants.dart` (`tauFactorLow`, `tauFactor`, `tauFactorHigh`); disimpan di `settings` kunci `sensitivity`. |
| 6 | Penghalusan lebar iris: SDD DFD 3.5.3 = **median 1 detik**. | Implementasi wajib median 1 detik (bukan EMA). **Diterapkan** di `DistanceEstimator` (`CvConstants.irisMedianWindow`). |
| 7 | Skor dihitung **tiap 10 detik** (PMT-04, Seq 4.22) dan bertipe **int**. | Jangan hitung skor per frame untuk keputusan pengingat. **Diterapkan:** `FatigueScorer.score` mengembalikan `int`; PERCLOS & skor dievaluasi tiap 10 detik oleh `SessionEvaluator` (BR & jarak tetap real-time); batas level 40/60 di `cv_constants.dart`. PMT-05 (#10) juga diterapkan: wajah tak terdeteksi > 10 detik → evaluasi & waktu layar dijeda. |
| 8 | Path endpoint notifikasi Midtrans, logout, daftar paket, riwayat transaksi **tidak ditulis** di SDD (§11.2), padahal SRS 3.3 menyebut "seluruh endpoint dijelaskan di SDD". | Tetapkan path & format request/response, lalu perbarui SDD. |
| 9 | Format JSON request/response tiap endpoint tidak dirinci di SDD. | Definisikan skema (mis. di `API_CONTRACT.md`) sebelum membangun backend. |
| 10 | PMT-05 (jeda saat wajah hilang > 10 detik) & PMT-06 (latar belakang) belum digambarkan di diagram. | Implementasikan sesuai tabel kebutuhan. **PMT-05 diterapkan** (`SessionEvaluator`, status "Wajah tidak terdeteksi" di Dashboard); PMT-06 belum. |
| 11 | KDL-02: di mobile pemantauan **berhenti saat layar mati**. | Pastikan foreground service berhenti saat layar off. |
| 12 | KLB-04: `calibrations` per `camera_id`; kamera diganti → minta kalibrasi ulang. | Simpan `camera_id` dan bandingkan saat kamera dibuka. |
| 13 | Kode sempat memakai **Firebase** (Auth + Firestore) untuk login & log metrik, di luar SDD Tabel 3.1. | **Keputusan pengguna (29 Okt 2026): Firebase tidak dipakai.** Backend tetap **Laravel + Sanctum + MySQL** (§4.2, §11, §12). Kode & konfigurasi Firebase sudah dihapus. |
| 14 | Fitur **Saran AI (Gemini)** tidak ada di SRS/SDD v1.0. | Dipertahankan sebagai fitur tambahan, lihat **§17**. SRS/SDD perlu direvisi. |
| 15 | Tabel `alerts` tidak punya kolom hasil verifikasi istirahat 20-20-20 (§9.6 "catat terverifikasi / tidak"). | **Keputusan pengguna (31 Okt 2026):** terverifikasi (atau Mode Timer, verifikasi dilewati) → `action = followed` (dihitung `breaks_taken`); tidak terverifikasi → `dismissed`. Skema §12.3 tidak berubah. |
| 16 | Durasi **Mode Fokus** tidak ditentukan (§9.7 hanya "pilih durasi"). | **Keputusan pengguna (31 Okt 2026): 30 / 60 / 90 / 120 menit** (`CvConstants.focusOptionsMin`). Sementara dimulai dari **Dashboard** karena system tray belum ada. |
| 17 | Detail interaksi pengingat yang tidak dirinci SDD. | **Diterapkan:** cooldown dimulai saat pengingat benar-benar tampil (bukan saat ditahan Tunda/Fokus); jarak & BR harus di bawah ambang **terus-menerus** (dilacak per frame, diputuskan tiap 10 dtk); pada 20-20-20, tombol **Oke** memulai hitung mundur 20 dtk; 20-20-20 yang diabaikan juga mereset timer (agar tidak muncul berulang), yang ditunda muncul lagi setelah masa tunda; notifikasi sistem dikirim bila diaktifkan, bila tidak didukung/izin ditolak tetap pop-up; bila pop-up & notifikasi sama-sama dimatikan, pengingat tidak tampil. |

---

## 17. Fitur Tambahan di Luar SRS/SDD v1.0 — Saran AI (Gemini)

> **Status:** fitur tambahan atas keputusan pengguna (29 Okt 2026), **belum tercantum di SRS/SDD v1.0**. Bagian ini menjadi acuan sampai SRS/SDD direvisi. Endpoint di sini adalah **USULAN** dan perlu persetujuan.

### 17.1 Tujuan
- Memberi **2–3 saran singkat dan praktis** dalam Bahasa Indonesia untuk menjaga kesehatan mata, berdasarkan ringkasan metrik pemantauan.
- **Bukan diagnosis medis.** Penafian medis §1.2 tetap berlaku, dan prompt sistem melarang diagnosis.
- Bila AI dinonaktifkan, offline, atau gagal, app menampilkan **saran statis** menurut level skor (§9.4) dan ambang pengingat (§9.5).

### 17.2 Data yang dikirim (hanya angka)
| Field | Tipe | Sumber |
|---|---|---|
| `fatigue_score` | int 0–100 | §9.4 (dibulatkan, §16 #7) |
| `blink_rate` | float, kedipan/menit (opsional) | §9.2 |
| `perclos` | float 0..1 (opsional) | §9.2 |
| `distance_cm` | float (opsional; null bila kalibrasi jarak dilewati) | §9.3 |
| `screen_minutes` | int (opsional) | menit menatap layar tanpa istirahat |

- **DILARANG** mengirim frame, gambar, video, landmark, EAR mentah, nama, email, atau ID pengguna ke layanan AI (§4.3, §8.8, §15.1).
- Implementasi: `AdviceMetrics` di `lib/features/ai_assistant/data/ai_advice_repository.dart`.

### 17.3 Alur
1. Pengguna meminta saran, misalnya dari Dashboard atau setelah Sesi Cek Mata (lokasi UI belum ditentukan).
2. App menyusun `AdviceMetrics` dari state pemantauan terakhir.
3. `AiAdviceRepository.getAdvice(metrics)`:
   - **Pengembangan** (`ApiConstants.useRemoteApi == false`): `DirectGeminiAdviceRepository` memanggil Gemini langsung dengan key dari `.env`.
   - **Final** (`useRemoteApi == true`): `ApiAiAdviceRepository` memanggil `POST /ai/advice` dengan token Sanctum. Server Laravel yang memanggil Gemini.
4. Respons teks ditampilkan. Jika gagal, saran statis ditampilkan.

### 17.4 Endpoint usulan — `POST /ai/advice` (🟡 USULAN, perlu persetujuan)
- Auth: token Sanctum.
- Request:
  ```json
  { "fatigue_score": 45, "blink_rate": 9.5, "perclos": 0.08, "distance_cm": 42, "screen_minutes": 35 }
  ```
- Respons **200 OK**: `{ "advice": "• Kedipkan mata perlahan 10 kali..." }`
- Usulan kode error:
  - **401**: token tidak valid.
  - **422**: field tidak valid.
  - **429**: batas pemakaian tercapai (kuota/rate limit per pengguna, nilainya belum ditentukan).
  - **503**: layanan AI tidak tersedia.

  Klien memakai saran statis untuk semua error.
- Server menyimpan `GEMINI_API_KEY` di `.env` Laravel, tidak pernah di klien. Server tidak menyimpan prompt/respons kecuali diputuskan lain.

### 17.5 Risiko API key di klien
- Saat ini `.env` didaftarkan sebagai **asset Flutter** (`pubspec.yaml`). Akibatnya `GEMINI_API_KEY` **ikut ter-bundle** di setiap build (exe/apk/ipa/web) dan **dapat diekstrak** siapa pun yang memegang aplikasinya.
- Konsekuensinya: penyalahgunaan kuota/biaya atas nama proyek, dan key tidak bisa dicabut per pengguna.
- Mitigasi:
  1. Pemanggilan langsung **hanya untuk pengembangan lokal**; jangan distribusikan build yang memuat key.
  2. Batasi key di Google AI Studio/Cloud Console (kuota, pembatasan API).
  3. Rotasi key bila pernah ikut dalam build yang dibagikan.
  4. Versi rilis **wajib** memakai `POST /ai/advice`, lalu `.env` dihapus dari asset.

### 17.6 Revisi SRS/SDD yang diperlukan
- **SRS**:
  - Tambah kebutuhan fungsional baru (mis. kode `SAI-01..`: minta saran, fallback statis, batas pemakaian).
  - Tambah use case baru "Meminta Saran AI" beserta aktor **Layanan AI (Gemini)** sebagai sistem eksternal.
  - Perbarui SRS 3.3/3.4 (antarmuka perangkat lunak dan komunikasi).
  - Perbarui bagian privasi: data angka ringkasan dikirim ke pihak ketiga melalui server.
  - Tentukan apakah fitur ini gratis atau memakai kuota/kredit (§8.1).
- **SDD**:
  - Tabel 3.1: tambah Gemini API.
  - Gambar 2.1: tambah Laravel ↔ Gemini.
  - Tabel 2.2/DFD: proses baru, tanpa penyimpanan baru kecuali log pemakaian.
  - Sequence diagram baru "Saran AI".
  - Daftar endpoint: `POST /ai/advice` (AiAdviceController).
  - Diagram kelas klien (Gambar 4.1): `AiAdviceRepository`.
- **DOCS_SPEC.md**: setelah revisi disetujui, pindahkan isi §17 ke bagian terkait (§4.2, §5, §10, §11) dan hapus status "tambahan".
