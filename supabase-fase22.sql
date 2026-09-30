-- ============================================================
-- FASE 22 — is_hr_admin() ikut memeriksa STATUS, bukan cuma role
-- Jalankan di Supabase: SQL Editor > New Query
-- ============================================================
-- MASALAH: is_hr_admin() hanya memeriksa `role = 'hr_admin'`. Statusnya tak
-- pernah dilihat. Akibatnya HR Admin yang SUDAH DINONAKTIFKAN tetap dianggap
-- HR Admin oleh database — masih bisa membaca & mengubah data gaji semua
-- orang, dokumen pribadi, dan log aktivitas, lewat API langsung.
--
-- Penjagaan yang ada sekarang (auth-guard.js) cuma di sisi tampilan: ia
-- melempar orangnya ke halaman login. Tapi akun Supabase Auth-nya TIDAK
-- dimatikan, jadi tokennya tetap sah. Tampilan bukan pagar keamanan.
--
-- 55 policy di seluruh tabel memanggil fungsi ini, jadi satu perbaikan di
-- sini langsung menutup semuanya sekaligus — baca maupun tulis.
--
-- Aman dijalankan berulang. Tidak menghapus data apa pun.
-- ============================================================


-- ============================================================
-- LANGKAH 0 — PERIKSA DULU. JANGAN LEWATI.
-- ============================================================
-- Blok di bawah mengubah SATU fungsi yang menjadi penentu hak akses seluruh
-- sistem. Kalau ada HR Admin yang masih bekerja tapi statusnya bukan persis
-- 'aktif' (salah ketik, kosong, beda huruf), ia akan LANGSUNG kehilangan
-- seluruh akses HR begitu perintah ini dijalankan.
--
-- Jalankan query ini SENDIRI dulu, lalu baca hasilnya:
SELECT nama_lengkap, nik, role, status,
       CASE WHEN status = 'aktif' THEN 'aman'
            ELSE 'AKAN KEHILANGAN AKSES HR' END AS akibat
  FROM karyawan
 WHERE role = 'hr_admin'
 ORDER BY nama_lengkap;

-- Lanjutkan HANYA bila semua yang masih bekerja tertulis 'aman'.
-- Kalau ada yang tidak, betulkan dulu statusnya lewat halaman Data Karyawan.


-- ============================================================
-- LANGKAH 1 — PERBAIKANNYA
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_hr_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.karyawan
     WHERE id = auth.uid()
       AND role = 'hr_admin'
       AND status = 'aktif'      -- <— inilah tambahannya
  );
$$ LANGUAGE SQL SECURITY DEFINER SET search_path = public, pg_temp;

-- Catatan tentang `SET search_path`: fungsi SECURITY DEFINER berjalan dengan
-- hak pembuatnya. Tanpa search_path yang dipatok, nama tabel di dalamnya bisa
-- diarahkan ke tabel lain oleh pemanggilnya. Ini persis jenis celah yang
-- pernah menjatuhkan handle_new_user() dulu — sekalian ditutup di sini.

COMMENT ON FUNCTION public.is_hr_admin() IS
  'TRUE hanya bila pengguna saat ini HR Admin YANG MASIH AKTIF. Dipakai oleh puluhan policy RLS; mengubahnya berdampak ke seluruh sistem.';


-- ============================================================
-- LANGKAH 2 — PERIKSA HASILNYA
-- ============================================================
-- JANGAN memeriksa dengan `SELECT public.is_hr_admin();` di SQL Editor.
-- Di sini `auth.uid()` selalu kosong — Anda masuk sebagai pemilik database,
-- bukan sebagai pengguna aplikasi — jadi hasilnya SELALU `false`, bahkan
-- ketika semuanya baik-baik saja. Itu bukan tanda ada yang rusak.
--
-- Periksa dengan ini saja; tidak bergantung pada siapa yang sedang login:
SELECT nama_lengkap, nik, status,
       (role = 'hr_admin' AND status = 'aktif') AS masih_punya_akses_hr
  FROM karyawan
 WHERE role = 'hr_admin'
 ORDER BY nama_lengkap;

-- Yang paling meyakinkan tetap: BUKA APLIKASINYA. Kalau menu Payroll,
-- Laporan & Log Aktivitas masih muncul dan datanya terbaca, akses HR utuh.

-- Perlihatkan definisi barunya, untuk memastikan yang terpasang benar.
SELECT prosrc AS isi_fungsi
  FROM pg_proc
 WHERE proname = 'is_hr_admin'
   AND pronamespace = 'public'::regnamespace;


-- ============================================================
-- YANG INI **TIDAK** TUTUP — harap disadari
-- ============================================================
-- 1. Karyawan biasa yang dinonaktifkan MASIH bisa membaca barisnya sendiri
--    lewat API (policy-nya berbunyi `karyawan_id = auth.uid()`, tanpa
--    memeriksa status). Taruhannya jauh lebih kecil — yang terbaca cuma
--    slip gaji & absensinya sendiri, yang memang haknya. Menutup ini berarti
--    menyunting puluhan policy satu per satu, dan mantan karyawan jadi tak
--    bisa mengambil slip gaji terakhirnya.
--
-- 2. Akun Supabase Auth-nya TETAP HIDUP. Siapa pun yang dinonaktifkan masih
--    bisa login dan memperoleh token yang sah; yang menolaknya cuma tampilan.
--    Pagar yang sebenarnya adalah mematikan akunnya:
--    Supabase Dashboard > Authentication > pilih penggunanya > Ban user.
--    Itu tak bisa dilakukan dari halaman statis karena butuh service role key.
--
-- 3. HR Admin berstatus 'cuti_panjang' ikut kehilangan akses HR. Itu memang
--    konsisten dengan auth-guard.js yang juga mengunci status non-aktif —
--    tapi kalau suatu saat HR yang cuti panjang perlu tetap bisa bekerja,
--    ubah syaratnya jadi `status IN ('aktif','cuti_panjang')`.


-- ============================================================
-- CARA MEMBATALKAN (kalau sampai terkunci)
-- ============================================================
-- SQL Editor berjalan sebagai superuser dan TIDAK tunduk pada RLS, jadi
-- Anda selalu bisa masuk lewat sini walau aplikasinya menolak. Jalankan:
--
--   CREATE OR REPLACE FUNCTION public.is_hr_admin()
--   RETURNS BOOLEAN AS $$
--     SELECT EXISTS (
--       SELECT 1 FROM public.karyawan
--        WHERE id = auth.uid() AND role = 'hr_admin'
--     );
--   $$ LANGUAGE SQL SECURITY DEFINER SET search_path = public, pg_temp;
--
-- Atau betulkan saja statusnya:
--   UPDATE karyawan SET status = 'aktif' WHERE nik = 'KMA-001';
