# Panduan Operasional Makasna Remote Broadcast Controller (Android)

<p align="center">
  <img src="assets/images/logo.png" alt="MAKASNA Remote" width="96" height="96" />
</p>

Dokumen ini berisi panduan penggunaan aplikasi mobile **Makasna Remote** untuk memantau dan mengendalikan server gateway penyiaran langsung dari smartphone Android.

---

## 1. Instalasi Aplikasi

1. Unduh file APK `makasna-remote.apk` langsung dari Web Dashboard (`/download/apk`) atau via GitHub Releases.
2. Pasang file APK di smartphone Android (aktifkan izin *Install Unknown Apps* jika diminta).
3. Buka aplikasi **MAKASNA REMOTE**.

---

## 2. Pengaturan Server & Auto-Connect

1. **Tab 1 (SERVER SETUP):**
   * **SERVER IP / HOSTNAME:** Masukkan IP publik server gateway Anda.
   * **PORT API / HTTP:** Default `8080`.
   * **PORT SRT STREAM:** Default `8890`.
   * **USERNAME & PASSWORD:** Masukkan kredensial login admin.
   * **Gunakan HTTPS:** Aktifkan jika server menggunakan domain ber-SSL.
   * **Remember Login Session (Auto-Connect):** Centang opsi ini agar aplikasi otomatis tersambung saat dibuka berikutnya tanpa perlu mengetik ulang kredensial.
2. Tekan tombol **TEST CONNECTION (PING)** untuk memastikan server dapat dijangkau.
3. Tekan **CONNECT & OPEN REMOTE CONTROLLER** untuk masuk ke antarmuka kontrol siaran.

---

## 3. Fitur Utama & Cara Penggunaan

### A. Tab Signal (Pemantauan Sinyal Lapangan)
* **Metric Cards:** Menampilkan total bitrate masuk (*Ingest In*), bitrate keluar (*Egress Out*), serta status kesehatan gateway.
* **Publishers:** Menampilkan feed kamera aktif di lapangan.
  * Tekan tombol **Copy URL** untuk menyalin tautan SRT reader.
  * Tekan **+ Create Route** untuk langsung mengadopsi stream yang sedang masuk menjadi rute siaran baru.
* **Listeners:** Menampilkan daftar perangkat penerima di studio siaran yang sedang menarik video dari server.

### B. Tab Recorder (Perekaman Master ISO)
* **Confidence Monitor:** Layar preview video siaran langsung dengan akselerasi perangkat keras.
* **Master Tally Lamp:** Lampu indikator hardware berkedip merah terang saat merekam aktif `[● REC ACTIVE]`.
* **Pengaturan Rekaman:**
  * **FEED SOURCE:** Pilih kamera / feed yang ingin direkam.
  * **CONTAINER FORMAT:** Pilih format **MP4 Universal** atau **QuickTime MOV** (editing NLE DaVinci Resolve / Premiere Pro).
  * **TARGET BITRATE:** Pilih Passthrough (asli) atau tentukan bitrate (2.5 Mbps s/d 16 Mbps / Custom kbps).
  * **DURASI SEGMEN:** Pilih pembagian segmen file 15m, 30m, atau 1 jam.
* **Tombol RECORD & STOP:** Tekan tombol merah **RECORD** untuk memulai dan tombol **STOP** untuk menghentikan rekaman secara bersih tanpa merusak header atom MP4/MOV.

### C. True Peak VU Meter & Deteksi Audio Pecah
* Memantau level audio multi-kanal secara real-time.
* Dapat memilih skala **dBFS** (-60 hingga 0 dBFS) atau **dBVU** (-20 hingga +3 VU).
* Jika indikator merah **`DIGITAL CLIP!`** menyala, sinyal audio lapangan mengalami distorsi digital (overload 0 dBFS). Minta operator audio lapangan segera menurunkan gain mixer.

### D. Tab Camera (Pocket Broadcaster & Panduan Larix)
* **Kamera Siaran HP Mandiri:** Mengubah smartphone menjadi kamera siaran langsung (*pocket broadcast camera*) yang mem-push video H.264 live ke gateway server tanpa perlu aplikasi pihak ketiga.
* **Kontrol Encoder:** Pilihan resolusi (1080p, 720p, 480p), bitrate target (2.0–8.0 Mbps), switch kamera depan/belakang, dan mute mikrofon.
* **Panduan Pengaturan Larix Broadcaster:** Menyediakan instruksi parameter dan tombol 1-klik salin URL untuk operator yang ingin menggunakan aplikasi eksternal Larix Broadcaster via SRT Caller port 8890.

### E. Tab Routes (Manajemen Jalur Siaran)
* Mengaktifkan atau menonaktifkan rute transmisi siaran secara langsung.
* Menambah rute baru dengan tombol **CREATE ROUTE**.
* Mengonfigurasi failover sumber primer dan sekunder agar siaran tidak terputus saat koneksi internet utama bermasalah.

---

## 4. Reset Sesi atau Ganti Server

Jika Anda ingin mengganti alamat IP server yang dipantau:
1. Buka tab **Profile** / Settings di pojok kanan bawah.
2. Tekan tombol **SWITCH SERVER / RESET SAVED SESSION**.
3. Aplikasi akan menghapus cache sesi dan kembali ke layar awal input server.

---

*Hak Cipta © Makasna Broadcast Infrastructure. Seluruh hak cipta dilindungi undang-undang.*
