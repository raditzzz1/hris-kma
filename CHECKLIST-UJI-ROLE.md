# Checklist Uji Per-Role — HRIS PT Kawan Menengah Atas

Dipakai sebelum onboarding karyawan. Centang tiap item yang berhasil.
Uji di **Chrome desktop** dan sekali lagi di **mode HP** (F12 → Ctrl+Shift+M).

---

## 0. Persiapan akun
- [ ] **WAJIB:** jalankan `supabase-fase7.sql` di Supabase SQL Editor (tabel `izin_absen_luar` & `lembur`). Tanpa ini, fitur Izin Absen Luar & Lembur akan error.
- [ ] Buat akun **HR Admin**: invite via Supabase → set password → di tabel `karyawan` set `role = 'hr_admin'` + lengkapi `nik, nama_lengkap, divisi_id, jabatan_id`.
- [ ] Buat akun **Karyawan**: invite via Supabase → set password → `role = 'karyawan'` + data lengkap.
- [ ] (Opsional) Akun **Manager**: `role = 'manager'` — lihat catatan di bagian D.
- [ ] Pastikan ada ≥1 lokasi kantor aktif (untuk uji absensi GPS).

---

## A. Autentikasi (semua role)
- [ ] Login email + password benar → masuk **dashboard**.
- [ ] Login password salah → muncul pesan "Email atau password salah".
- [ ] Klik **Lupa password?** → email reset masuk → buka link → halaman `reset-password.html` tampil → set password baru → berhasil login dengan password baru.
- [ ] Undang karyawan baru (Supabase → Auth → Invite) → buka link undangan → form **Buat Password** muncul di halaman login → set → masuk.
- [ ] Klik **Logout** → kembali ke halaman login.
- [ ] Buka `dashboard.html` langsung tanpa login → otomatis dialihkan ke login.

---

## B. Sebagai HR ADMIN
### Dashboard
- [ ] Kartu statistik admin tampil: Total Karyawan Aktif, Hadir Hari Ini, Izin/Cuti, Tidak Hadir.
- [ ] "Aktivitas Terbaru" menampilkan absensi karyawan hari ini.
- [ ] Sidebar: bagian **Administrasi** (Lokasi Kantor + Laporan) **terlihat**.

### Data Karyawan
- [ ] Lihat seluruh daftar karyawan; **cari** & **filter** divisi/status berfungsi.
- [ ] Tambah / **Edit** / Hapus data karyawan tersimpan.
- [ ] Tombol **Undang Karyawan** membuka panduan invite.

### Absensi
- [ ] Lihat **rekap kehadiran semua karyawan**.
- [ ] **Input Manual** absensi tersimpan.
- [ ] Kalender kehadiran tampil benar.

### Cuti & Izin
- [ ] Lihat **semua pengajuan** cuti.
- [ ] **Setujui** / **Tolak** mengubah status pengajuan.
- [ ] **Atur Saldo** cuti karyawan tersimpan.

### Payroll
- [ ] **Buat Periode** → generate slip untuk semua karyawan.
- [ ] **Komponen Gaji** bisa diatur per karyawan.
- [ ] **Finalisasi** periode mengubah status jadi Final.
- [ ] **Lihat Slip** & **Cetak Slip** tampil rapi (PPh21 & BPJS terhitung).

### Pelatihan
- [ ] Tambah/Edit/Hapus **Program**.
- [ ] **Daftarkan** karyawan & update status peserta.
- [ ] Tambah **Sertifikasi**; badge "Aktif/Segera expired/Expired" benar.

### Lokasi Kantor
- [ ] Tambah/Edit/Hapus lokasi; klik **peta** mengisi koordinat; radius tampil.
- [ ] "Pakai Koordinat Lokasi Saya" mengisi dari GPS.

### Laporan
- [ ] 3 tab (Absensi / Cuti / Payroll) tampil; **filter bulan/tahun** bekerja.
- [ ] **Export CSV** terunduh & rapi di Excel.
- [ ] **Cetak** menyembunyikan sidebar/filter (hanya tabel).

---

## C. Sebagai KARYAWAN (ESS)
### Dashboard
- [ ] Kartu statistik pribadi (Divisi, Jabatan, Hari Kerja, Sisa Cuti).
- [ ] **Absen Masuk** & **Absen Keluar** (GPS) berfungsi; di luar radius → ditolak (kecuali mode WFH/WFA).
- [ ] Rekap kehadiran bulan ini tampil.
- [ ] Sidebar: bagian **Administrasi TIDAK terlihat**.

### Modul
- [ ] Absensi: hanya **riwayat sendiri**; mode WFH/WFA bisa dipilih.
- [ ] Cuti: bisa **ajukan**, lihat **status sendiri** + **saldo**.
- [ ] Payroll: hanya **slip gaji final milik sendiri** (tidak ada tombol generate/finalisasi).
- [ ] Pelatihan: hanya **pelatihan & sertifikat milik sendiri**.
- [ ] Profil (Data Karyawan): bisa edit **data pribadi sendiri**; kolom **NIK terkunci**.
- [ ] **Foto profil**: di Edit Data Pribadi → **Pilih Foto** (JPG/PNG ≤2MB) → Simpan → foto muncul di profil & sidebar. Tombol **Hapus** mengembalikan ke inisial. (Perlu `supabase-fase8.sql` sudah dijalankan.)

### Pembatasan akses (penting)
- [ ] Ketik manual `lokasi.html` → **dialihkan ke dashboard**.
- [ ] Ketik manual `laporan.html` → muncul layar **"Akses Terbatas"**.
- [ ] Tidak bisa melihat slip/cuti/absensi karyawan lain.

---

## D. Sebagai MANAGER (opsional)
> Catatan: UI saat ini mengecek `role === 'hr_admin'` untuk tampilan admin, jadi
> **manager saat ini diperlakukan seperti karyawan** di antarmuka (walau RLS
> mengizinkan manager menyetujui cuti). 
- [ ] Putuskan: apakah peran manager dipakai? Jika ya, perlu pengembangan UI
      tambahan agar manager bisa approve cuti / lihat tim. (Catat sebagai backlog.)

---

## E. Responsif / Mobile (F12 → Ctrl+Shift+M)
- [ ] Lebar ≤768px: sidebar jadi **hamburger** + **bottom-nav** muncul.
- [ ] **Tabel berubah jadi kartu** per-baris (label kiri, nilai kanan).
- [ ] Modal/popup jadi **bottom-sheet**.
- [ ] Sidebar (saat dibuka): semua menu muat, scrollbar tipis.
- [ ] Tidak ada teks/elemen yang terpotong atau meluber ke samping.

---

## F. Visual / QA umum
- [ ] **Tidak ada emoji** di mana pun — semua ikon berupa garis (SVG) konsisten.
- [ ] Logo KMA tampil di sidebar & halaman login.
- [ ] Warna & font konsisten (biru Genio + Poppins) di semua halaman.
- [ ] Tidak ada link rusak / tombol yang tidak merespons.

---

## G. Izin Absen Luar Lokasi & Lembur (fitur baru)
### Karyawan
- [ ] Di Absensi: klik **Izin Absen Luar** → isi tanggal + tipe (WFH/WFA/dinas) + alasan → kirim → muncul di "Izin Absen Luar Lokasi Saya" dengan status **Menunggu**.
- [ ] Saat **di luar radius** dan **belum ada izin disetujui** → tombol Absen **terkunci**, ada pesan minta ajukan izin.
- [ ] Klik **Catat Lembur** → isi tanggal + jam mulai/selesai + alasan → tersimpan di "Lembur Saya" dengan durasi terhitung; bisa **Hapus**.

### HR Admin
- [ ] Di Absensi (panel bawah): lihat **Izin Absen Luar — Persetujuan**; klik **Setujui**/**Tolak** → status berubah.
- [ ] Lihat **Lembur Karyawan** (semua); bisa **Hapus**.

### Setelah izin disetujui (karyawan)
- [ ] Login karyawan, di luar radius, pada tanggal izin → muncul chip "Izin ... disetujui"; tombol Absen **aktif**; absen tercatat dengan label mode (WFH/WFA) di riwayat.
- [ ] Pastikan lembur **tidak** muncul/menambah otomatis di slip gaji (payroll tetap manual).

---

Jika ada item GAGAL, catat: halaman, langkah, dan pesan error (kalau ada),
lalu kirim ke pengembang untuk diperbaiki.
