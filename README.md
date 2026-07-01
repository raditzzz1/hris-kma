# HRIS — PT Kawan Menengah Atas

Sistem HRIS berbasis web (HTML statis + [Supabase](https://supabase.com) sebagai
backend/database/auth). Tidak butuh server sendiri — cukup hosting file statis +
Supabase gratis.

Modul: Login/Auth · Dashboard · Data Karyawan · Absensi (GPS + izin absen luar) ·
Cuti & Izin · Payroll (PPh21 & BPJS) · Pelatihan & Sertifikasi · Laporan · Lembur ·
Employee Self-Service (ESS) per akun.

---

## 1. Struktur file
| File | Fungsi |
|---|---|
| `index.html` | Login + set password (invite) |
| `reset-password.html` | Reset password dari email |
| `dashboard.html` | Beranda (role-aware) + absen cepat |
| `karyawan.html` | Data karyawan / profil |
| `absensi.html` | Absensi GPS, izin absen luar, lembur |
| `cuti.html` | Pengajuan & persetujuan cuti |
| `payroll.html` | Generate slip gaji |
| `pelatihan.html` | Program pelatihan & sertifikasi |
| `lokasi.html` | Lokasi kantor (geofencing) |
| `laporan.html` | Rekap & export (absensi/cuti/payroll/lembur/izin) |
| `theme.css`, `hris.css` | Design system + responsif |
| `responsive-tables.js` | Tabel → kartu di HP |
| `logo-KMA.png` | Logo perusahaan |
| `supabase-*.sql` | Skema database (lihat urutan di bawah) |

---

## 2. Setup Supabase (sekali saja)
1. Buat project di [supabase.com](https://supabase.com) (free tier cukup).
2. Buka **SQL Editor → New Query**, jalankan file `.sql` **berurutan**:
   1. `supabase-setup.sql`  (tabel inti, RLS, dll)
   2. `supabase-fase2.sql`  (trigger karyawan baru)
   3. `supabase-fase4.sql`  (cuti)
   4. `supabase-fase5.sql`  (payroll)
   5. `supabase-fase6.sql`  (pelatihan)
   6. `supabase-bugfix.sql` (penyesuaian divisi/jabatan/cuti)
   7. `supabase-fase7.sql`  (izin absen luar + lembur)
   8. `supabase-fase8.sql`  (foto profil — bucket Supabase Storage)
   9. `supabase-fase9.sql`  (jam kerja per-karyawan & gaji per-jam/freelance)
   10. `supabase-fase10.sql` (NIK otomatis format KMA-XXX, tidak pernah dipakai ulang)
   11. `supabase-fase11.sql` (hari libur nasional dipindah ke database + migrasi data 2026)
   12. `supabase-fase12.sql` (aktifkan Realtime untuk notifikasi cuti/izin)
3. Ambil **Project URL** & **anon key** dari **Project Settings → API**.
4. Tempel ke setiap file `.html` di bagian:
   ```js
   const SUPABASE_URL      = '...'
   const SUPABASE_ANON_KEY = '...'
   ```
   (sudah terisi untuk project saat ini — ganti bila pindah project Supabase).

> **Aman?** Ya. `anon key` memang publik dan boleh ada di kode front-end —
> keamanan data dijaga oleh **Row Level Security (RLS)** di Supabase.

---

## 3. Buat HR Admin pertama
1. Supabase → **Authentication → Users → Invite user**, masukkan email Anda.
2. Buka link di email → set password (lewat `index.html`).
3. Supabase → **Table Editor → `karyawan`** → lengkapi baris Anda
   (`nik`, `nama_lengkap`, `divisi_id`, `jabatan_id`) dan set **`role` = `hr_admin`**.
4. Login → Anda kini HR Admin.

## 4. Undang karyawan
- Supabase → **Authentication → Invite user** per karyawan.
- Karyawan buka link → set password → otomatis muncul di tabel `karyawan`
  (trigger Fase 2). HR lengkapi datanya di **Data Karyawan**.

---

## 5. Menjalankan lokal
Karena murni statis, cukup buka `index.html` di browser. Untuk fitur GPS &
beberapa API butuh konteks aman; bila ada kendala jalankan server lokal kecil:
```bash
# dari folder project
python -m http.server 8080
# lalu buka http://localhost:8080
```

## 6. Deploy (agar bisa diakses karyawan)
Pilih salah satu (semua mendukung situs statis, gratis):
- **Netlify**: drag-and-drop folder ke app.netlify.com → dapat URL.
- **Vercel**: import folder/repo → deploy.
- **GitHub Pages**: push repo → Settings → Pages → pilih branch.
- **Cloudflare Pages**: connect repo → deploy.

Setelah online, beri URL ke karyawan. Pastikan domain hosting **HTTPS**
(syarat agar GPS absensi berfungsi).

> Penting: di Supabase → **Authentication → URL Configuration**, set **Site URL**
> & **Redirect URLs** ke domain hosting Anda (agar link invite & reset password
> mengarah ke domain yang benar, bukan localhost).

---

## 7. Uji sebelum onboarding
Lihat **[CHECKLIST-UJI-ROLE.md](CHECKLIST-UJI-ROLE.md)** — uji per role
(HR Admin / Karyawan) termasuk absensi, izin absen luar, lembur, dan responsif HP.

---

## 8. Jam kerja (acuan)
- Senin–Jumat: 09:00–17:00 (kantor, dalam radius)
- Sabtu: 09:00–16:00 (WFH — lewat **Izin Absen Luar** yang disetujui HR)
- Absen di luar radius hanya bisa bila ada **izin absen luar yang disetujui**.
- **Jam kerja per-karyawan** (opsional, di Data Karyawan → Data Pekerjaan): atur
  *Jam masuk standar* (ambang terlambat), *Jam kerja fleksibel* (rolling — tidak
  dihitung terlambat), *Tipe gaji* (Bulanan / Per-jam) + *Tarif per jam*. Untuk
  tipe **Per-jam** (freelance), gaji = total jam kerja sebulan × tarif, dibayar
  bersih tanpa potongan BPJS/PPh.
- **Lembur** dicatat karyawan untuk pendataan; upah lembur diinput **manual** oleh
  HR (tidak otomatis masuk slip gaji).
- **Hari libur nasional**: dikelola HR di halaman Absensi → panel "Kelola Hari
  Libur" (tambah/hapus tanggal libur tahun berapa pun, tanpa edit kode).
- **Karyawan resign**: begitu HR ubah status jadi "tidak aktif", akun otomatis
  tidak bisa login lagi (dan sesi yang sedang berjalan langsung ter-logout).

---

## 9. Install sebagai App (PWA)
HRIS ini bisa di-"Install" seperti aplikasi native, langsung dari browser:
- **HP (Android/Chrome):** buka situs → menu (⋮) → **"Add to Home screen" / "Install app"**.
- **iPhone (Safari):** buka situs → tombol Share → **"Add to Home Screen"**.
- **Desktop (Chrome/Edge):** ikon install (⊕) muncul di address bar → klik → Install.

Setelah ter-install, app punya ikon sendiri di layar utama/desktop dan terbuka
tanpa address bar browser, seperti aplikasi biasa.

## 10. Notifikasi browser (cuti/izin disetujui-ditolak)
Karyawan bisa mengaktifkan notifikasi lewat tombol lonceng **"Aktifkan
Notifikasi"** di header Dashboard. Setelah diizinkan, notifikasi browser akan
muncul otomatis saat pengajuan **cuti** atau **izin absen luar** mereka
disetujui/ditolak HR — di halaman mana pun mereka sedang buka.

> **Catatan penting:** ini notifikasi sisi-browser (Supabase Realtime +
> Notification API), **bukan** push notification server. Hanya berfungsi
> **selama tab/app masih terbuka** (boleh di-minimize/background). Tidak akan
> muncul kalau browser/app benar-benar ditutup atau HP dalam kondisi mati
> layar lama. Untuk notifikasi yang benar-benar "sampai walau app tertutup",
> dibutuhkan push notification server (Supabase Edge Function + Web Push) —
> ini di luar cakupan implementasi saat ini.
